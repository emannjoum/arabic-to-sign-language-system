import torch
import torch.nn as nn
import numpy as np
from sentence_transformers import SentenceTransformer
from huggingface_hub import hf_hub_download

class TransformerPointerNet(nn.Module):
    def __init__(self, input_dim, hidden_dim, max_len=20, nhead=4, num_layers=3, dropout_rate=0.2):
        super().__init__()
        self.hidden_dim = hidden_dim
        self.max_len = max_len
        self.input_projection = nn.Linear(input_dim, hidden_dim)
        self.pos_embedding = nn.Embedding(max_len, hidden_dim)
        
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=hidden_dim, nhead=nhead, dim_feedforward=hidden_dim*2, 
            dropout=dropout_rate, batch_first=True
        )
        self.encoder = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        
        decoder_layer = nn.TransformerDecoderLayer(
            d_model=hidden_dim, nhead=nhead, dim_feedforward=hidden_dim*2, 
            dropout=dropout_rate, batch_first=True
        )
        self.decoder = nn.TransformerDecoder(decoder_layer, num_layers=num_layers)
        
        self.W1 = nn.Linear(hidden_dim, hidden_dim)
        self.W2 = nn.Linear(hidden_dim, hidden_dim)
        self.vt = nn.Linear(hidden_dim, 1)
        self.dropout = nn.Dropout(dropout_rate)
        self.start_token = nn.Parameter(torch.zeros(1, 1, hidden_dim))

    def forward(self, x):
        batch_size, seq_len, _ = x.shape
        x_proj = self.input_projection(x)
        positions = torch.arange(0, seq_len, device=x.device).unsqueeze(0).repeat(batch_size, 1)
        enc_input = x_proj + self.pos_embedding(positions)
        enc_input = self.dropout(enc_input)
        memory = self.encoder(enc_input)
        
        all_logits = []
        dec_input = self.start_token.expand(batch_size, -1, -1)
        
        for step in range(seq_len):
            dec_out = self.decoder(dec_input, memory)
            query = dec_out[:, -1, :] 
            out = torch.tanh(self.W1(memory) + self.W2(query).unsqueeze(1))
            logits = self.vt(out).squeeze(2)
            all_logits.append(logits)
            
            if step < seq_len - 1:
                next_token = query.unsqueeze(1)
                dec_input = torch.cat([dec_input, next_token], dim=1)
                
        return torch.stack(all_logits, dim=1)


DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
EMBED_MODEL = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2').to(DEVICE)

REPO_ID = "SignlyOrg/pointer-net-transformer-msa"  
FILENAME = "transformer_ptr_msa.pth" 
MAX_LEN = 20

Q_MARKS = ['?', '؟']
Q_WORDS = ['كيف', 'متى', 'اين', 'لماذا', 'من', 'ماذا', 'هل', 'كم', 'شلون', 'وين', 'ليش', 'مين', 'شو', 'ايمتى', 'قديش'] 

try:
    model_path = hf_hub_download(repo_id=REPO_ID, filename=FILENAME)
    reorder_model = TransformerPointerNet(input_dim=386, hidden_dim=512).to(DEVICE) # 386 = 384 for MiniLM + 2 for Q-features
    
    checkpoint = torch.load(model_path, map_location=DEVICE, weights_only=True)
    if isinstance(checkpoint, dict) and 'model_state' in checkpoint:
        reorder_model.load_state_dict(checkpoint['model_state'])
    else:
        reorder_model.load_state_dict(checkpoint)
        
    reorder_model.eval()
    print("Transformer PointerNet Loaded and Ready.")
except Exception as e:
    print(f"Error loading Transformer PointerNet: {e}")


def local_pointer_reorder(sentence: str) -> list[str]:
    words = sentence.split()
    
    words = words[:MAX_LEN]
    n = len(words)
    
    if n == 0: 
        return []

    with torch.no_grad():
        embeddings = EMBED_MODEL.encode(words)
        features = np.zeros((n, 2))
        
        for j, w in enumerate(words):
            if w in Q_MARKS: features[j, 0] = 1.0
            if w in Q_WORDS: features[j, 1] = 1.0
            
        combined_emb = np.concatenate([embeddings, features], axis=1)
        
        padded_x = torch.zeros(1, MAX_LEN, 386).to(DEVICE)
        padded_x[0, :n] = torch.FloatTensor(combined_emb)
        
        logits = reorder_model(padded_x)[0]
        
        # Ptr extraction with masking (only looking at the valid 'n' length)
        indices, mask = [], torch.zeros(n).to(DEVICE)
        for step in range(n):
            step_logits = logits[step, :n] + mask
            idx = torch.argmax(step_logits).item()
            indices.append(idx)
            mask[idx] = -1e9
            
        reordered = [words[idx] for idx in indices]

    return reordered