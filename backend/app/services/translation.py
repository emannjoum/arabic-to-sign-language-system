import os
import torch
import torch.nn as nn
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from app.core.nlp_utils import transform_to_arsl, extract_names
from app.core.agents import run_intent_agent
from app.db.models import Sign
from app.schemas import SkeletonFrame
from sqlalchemy import or_, cast, Text
from sqlalchemy.dialects.postgresql import ARRAY
from app.core.semantic import semantic_engine
from transformers import SentenceTransformer
from huggingface_hub import hf_hub_download

load_dotenv()

class PointerAttention(nn.Module):
    def __init__(self, hidden_dim):
        super().__init__()
        self.W1 = nn.Linear(hidden_dim, hidden_dim)
        self.W2 = nn.Linear(hidden_dim, hidden_dim)
        self.vt = nn.Linear(hidden_dim, 1)

    def forward(self, decoder_hidden, encoder_outputs):
        out = torch.tanh(self.W1(encoder_outputs) + self.W2(decoder_hidden).unsqueeze(1))
        scores = self.vt(out).squeeze(2) 
        return scores

class PointerNet(nn.Module):
    def __init__(self, input_dim, hidden_dim):
        super().__init__()
        self.encoder = nn.LSTM(input_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.decoder = nn.LSTM(hidden_dim, hidden_dim, batch_first=True)
        self.attention = PointerAttention(hidden_dim)
        self.reduce_h = nn.Linear(hidden_dim * 2, hidden_dim)
        self.reduce_c = nn.Linear(hidden_dim * 2, hidden_dim)

    def forward(self, x):
        batch_size, seq_len, _ = x.shape
        enc_out, (h_n, c_n) = self.encoder(x)
        h_d = self.reduce_h(torch.cat((h_n[0], h_n[1]), dim=1)).unsqueeze(0)
        c_d = self.reduce_c(torch.cat((c_n[0], c_n[1]), dim=1)).unsqueeze(0)
        enc_out_reduced = enc_out[:, :, :512] + enc_out[:, :, 512:] 
        all_logits = []
        decoder_input = torch.zeros(batch_size, 1, 512).to(x.device)
        for _ in range(seq_len):
            _, (h_d, c_d) = self.decoder(decoder_input, (h_d, c_d))
            logits = self.attention(h_d.squeeze(0), enc_out_reduced)
            all_logits.append(logits)
        return torch.stack(all_logits, dim=1)


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
EMBED_MODEL = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2').to(DEVICE)

REPO_ID = "SignlyOrg/bi-lstm-pointer-network" 
FILENAME = "pointer_net_arsl.pth"

try:
    model_path = hf_hub_download(repo_id=REPO_ID, filename=FILENAME)
    reorder_model = PointerNet(384, 512).to(DEVICE)
    reorder_model.load_state_dict(torch.load(model_path, map_location=DEVICE))
    reorder_model.eval()
    print("PointerNet Loaded and Ready.")
except Exception as e:
    print(f"Error loading PointerNet: {e}")

def local_pointer_reorder(sentence: str) -> list[str]:
    particles = ["قبل" ,"اثنان" ,"كثير" ,"في", "و", "على", "من", "إلى", "عن", "ثم"]
    words = sentence.split()
    glued, i = [], 0
    while i < len(words):
        if words[i] in particles and i + 1 < len(words):
            glued.append(f"{words[i]}_{words[i+1]}"); i += 2
        else:
            glued.append(words[i]); i += 1

    clean_glued = [w.replace("؟", "") for w in glued]
    n = len(clean_glued)
    
    if n == 0: return []
    
    with torch.no_grad():
        emb = torch.FloatTensor(EMBED_MODEL.encode(clean_glued)).unsqueeze(0).to(DEVICE)
        padded_x = torch.zeros(1, 20, 384).to(DEVICE) 
        padded_x[0, :n] = emb
        logits = reorder_model(padded_x)[0]
        indices, mask = [], torch.zeros(n).to(DEVICE)
        for step in range(n):
            step_logits = logits[step, :n] + mask
            idx = torch.argmax(step_logits).item()
            indices.append(idx)
            mask[idx] = -1e9 
        reordered = [clean_glued[idx] for idx in indices]
        
    # Remove the underscore glue to return standard lemmas
    return [w.replace("_", " ") for w in reordered]

def process_translation(user_input: str, db: Session):
    intent_res = run_intent_agent(user_input, route="translation")
    clean_text = intent_res.extracted_text
    print(f"Cleaned Input: '{clean_text}'")
    detected_names = extract_names(clean_text)
    print(f"Detected Names: {detected_names}")
    nlp_lemmas = transform_to_arsl(clean_text)
    
    try:
        final_lemmas = local_pointer_reorder(" ".join(nlp_lemmas))
        print(f"Reordered: {nlp_lemmas} -> {final_lemmas}")
    except Exception as e:
        print(f"PointerNet Failed: {e}. Using NLP order.")
        final_lemmas = nlp_lemmas

    response_data = []

    for lemma in final_lemmas:

        if lemma in detected_names:
            print(f"'{lemma}' is a name. Force Fingerspelling.")
            fingerspelling_skeletons = get_fingerspelling_sequence(lemma, db)
            response_data.extend(fingerspelling_skeletons)
            continue
        
        sign_entry = find_sign_in_db(lemma, db)
        
        if sign_entry:
            add_sign_to_response(response_data, sign_entry, lemma)
            continue

        print(f"Direct match failed for '{lemma}'. Trying Semantic Search...")
        semantic_result = semantic_engine.search(lemma)
        
        if semantic_result:
            if semantic_result["type"] == "match":
                alt_word = semantic_result["word"]
                print(f"AI Suggestion: Replace '{lemma}' with '{alt_word}' ({semantic_result['score']:.2f})")
                alt_sign = find_sign_in_db(alt_word, db)
                if alt_sign:
                    add_sign_to_response(response_data, alt_sign, lemma) # Use original label, but new video
                    continue

            elif semantic_result["type"] == "explain":
                explanation_words = semantic_result["words"]
                print(f"AI Explanation: '{lemma}' -> {explanation_words}") 
                found_explanation = False
                for w in explanation_words:
                    s = find_sign_in_db(w, db)
                    if s:
                        add_sign_to_response(response_data, s, w)
                        found_explanation = True
                
                if found_explanation: continue

        print(f"All lookups failed for '{lemma}'. Fingerspelling.")
        fingerspelling_skeletons = get_fingerspelling_sequence(lemma, db)
        response_data.extend(fingerspelling_skeletons)

    return response_data

def find_sign_in_db(word: str, db: Session):
    return db.query(Sign).filter(
        or_(
            Sign.word == word,
            Sign.keywords.contains(cast([word], ARRAY(Text)))
        )
    ).first()

def add_sign_to_response(response_list, sign_obj, label_text):
    response_list.append(SkeletonFrame(
        skeleton_url=sign_obj.skeleton_url,
        label=label_text,
        delay_ms=0
    ))

def get_fingerspelling_sequence(word: str, db: Session):
    skeletons = []
    for letter in word:
        letter_sign = db.query(Sign).filter(Sign.word == letter).first()
        
        if letter_sign:
            skeletons.append(SkeletonFrame(
                skeleton_url=letter_sign.skeleton_url,
                label=letter,
                delay_ms=500  # Small delay between letters so it's readable
            ))
            
    return skeletons