from sqlalchemy.orm import Session
from app.core.nlp_utils import transform_to_arsl, extract_names
from app.core.agents import run_intent_agent
from app.db.models import Sign
from app.schemas import SkeletonFrame
from sqlalchemy import or_, cast, Text
from sqlalchemy.dialects.postgresql import ARRAY
from app.core.semantic import semantic_engine
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

REORDER_MODEL_NAME = "your-username/your-arsl-reordering-model"

try:
    reorder_tokenizer = AutoTokenizer.from_pretrained(REORDER_MODEL_NAME)
    reorder_model = AutoModelForSeq2SeqLM.from_pretrained(REORDER_MODEL_NAME)
    print("Reordering Model Loaded.")
except Exception as e:
    print(f"Error loading reordering model: {e}")


def reorder_sequence_model(lemmas: list[str]) -> list[str]:
    if not lemmas: return []
    input_text = " ".join(lemmas)
    inputs = reorder_tokenizer(input_text, return_tensors="pt", max_length=128, truncation=True)

    outputs = reorder_model.generate(**inputs, max_length=128)
    output_text = reorder_tokenizer.decode(outputs[0], skip_special_tokens=True)

    return output_text.split()

def process_translation(user_input: str, db: Session):
    intent_res = run_intent_agent(user_input, route="translation")
    clean_text = intent_res.extracted_text
    print(f"Cleaned Input: '{clean_text}'")
    detected_names = extract_names(clean_text)
    print(f"Detected Names: {detected_names}")
    nlp_lemmas = transform_to_arsl(clean_text)
    
    try:
        final_lemmas = reorder_sequence_model(nlp_lemmas)
        print(f"Reordered: {nlp_lemmas} -> {final_lemmas}")
    except Exception as e:
        print(f"Reordering Model Failed: {e}. Using NLP order.")
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