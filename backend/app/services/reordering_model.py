import torch
import torch.nn as nn
from sentence_transformers import SentenceTransformer
from huggingface_hub import hf_hub_download
import re

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
    def __init__(self, input_dim, hidden_dim, dropout_rate=0.3):
        super().__init__()
        self.encoder = nn.LSTM(input_dim, hidden_dim, batch_first=True, bidirectional=True)
        self.decoder = nn.LSTM(hidden_dim, hidden_dim, batch_first=True)
        self.attention = PointerAttention(hidden_dim)
        self.reduce_h = nn.Linear(hidden_dim * 2, hidden_dim)
        self.reduce_c = nn.Linear(hidden_dim * 2, hidden_dim)
        self.dropout = nn.Dropout(dropout_rate)
        self.hidden_dim = hidden_dim

    def forward(self, x):
        batch_size, seq_len, _ = x.shape
        x = self.dropout(x)
        enc_out, (h_n, c_n) = self.encoder(x)
        enc_out = self.dropout(enc_out)

        h_d = self.reduce_h(torch.cat((h_n[0], h_n[1]), dim=1)).unsqueeze(0)
        c_d = self.reduce_c(torch.cat((c_n[0], c_n[1]), dim=1)).unsqueeze(0)
        
        enc_out_reduced = enc_out[:, :, :self.hidden_dim] + enc_out[:, :, self.hidden_dim:] 
        all_logits = []
        decoder_input = torch.zeros(batch_size, 1, self.hidden_dim).to(x.device)
        
        for _ in range(seq_len):
            _, (h_d, c_d) = self.decoder(decoder_input, (h_d, c_d))
            h_d_dropped = self.dropout(h_d)
            logits = self.attention(h_d_dropped.squeeze(0), enc_out_reduced)
            all_logits.append(logits)
            
        return torch.stack(all_logits, dim=1)


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
EMBED_MODEL = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2').to(DEVICE)

REPO_ID = "SignlyOrg/pointer-net-msa"  # SignlyOrg/pointer-net-jo
FILENAME = "pointer_net_msa.pth"
MAX_LEN = 20

try:
    model_path = hf_hub_download(repo_id=REPO_ID, filename=FILENAME)
    reorder_model = PointerNet(384, 512).to(DEVICE)
    
    checkpoint = torch.load(model_path, map_location=DEVICE)
    if isinstance(checkpoint, dict) and 'model_state' in checkpoint:
        reorder_model.load_state_dict(checkpoint['model_state'])
    else:
        reorder_model.load_state_dict(checkpoint)
        
    reorder_model.eval()
    print("PointerNet Loaded and Ready.")
except Exception as e:
    print(f"Error loading PointerNet: {e}")


def local_pointer_reorder(sentence: str) -> list[str]:
    particles = ["قبل","اثنان","كثير","في","و","على","من","إلى","عن","ثم"]
    words = sentence.split()
    glued, i = [], 0
    while i < len(words):
        if words[i] in particles and i + 1 < len(words):
            glued.append(f"{words[i]}~{words[i+1]}")
            i += 2
        else:
            glued.append(words[i])
            i += 1

    clean_glued = [w.replace("؟", "") for w in glued]
    n = len(clean_glued)
    if n == 0: return []

    with torch.no_grad():
        emb = torch.FloatTensor(EMBED_MODEL.encode(clean_glued)).unsqueeze(0).to(DEVICE)
        padded_x = torch.zeros(1, MAX_LEN, 384).to(DEVICE)
        padded_x[0, :n] = emb
        logits = reorder_model(padded_x)[0]
        indices, mask = [], torch.zeros(n).to(DEVICE)
        for step in range(n):
            step_logits = logits[step, :n] + mask
            idx = torch.argmax(step_logits).item()
            indices.append(idx)
            mask[idx] = -1e9
        reordered = [clean_glued[idx] for idx in indices]

    result = []
    for w in reordered:
        if "~" in w:
            result.extend(w.split("~"))
        else:
            result.append(w)

    return result