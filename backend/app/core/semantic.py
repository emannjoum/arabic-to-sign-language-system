import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "True"

import re
import json
import numpy as np
import pandas as pd
import torch
import faiss
import requests
from transformers import AutoTokenizer, AutoModel
from typing import List

EMBED_MODEL = "silma-ai/silma-embedding-sts-v0.1"
WIKTIONARY_API = "https://ar.wiktionary.org/w/api.php"

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_PATH = os.path.join(BASE_DIR, "data", "jsl_gloss.xlsx")
DEF_CACHE_PATH = os.path.join(BASE_DIR, "data", "def_cache.json")

KINSHIP_HINTS = {
    "اب", "ام", "اخ", "اخت", "عم", "خال", "جد", "جده", "عمه", "خاله"
}


def norm_ar(s: str) -> str:
    s = str(s)
    s = re.sub(r"[ًٌٍَُِّْـ]", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def is_atomic(text: str) -> bool:
    return len(norm_ar(text).split()) == 1


class SemanticEngine:
    def __init__(self):
        print("Loading Semantic Engine...")

        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        self.tokenizer = AutoTokenizer.from_pretrained(EMBED_MODEL, use_fast=True)
        self.model = AutoModel.from_pretrained(EMBED_MODEL).to(self.device).eval()

        self._load_data()
        self._load_def_cache()
        self._build_index()

        print(f"Semantic Engine ready. Index size: {self.index.ntotal}")


    def _load_data(self):
        df = pd.read_excel(DATA_PATH)

        self.ar_texts = df["translation_to_arabic"].fillna("").astype(str).tolist()
        self.norm_ar_texts = [norm_ar(a) for a in self.ar_texts]

        self.closed_vocab = {
            tok for a in self.norm_ar_texts for tok in a.split()
        }


    def _load_def_cache(self):
        if os.path.exists(DEF_CACHE_PATH):
            with open(DEF_CACHE_PATH, "r", encoding="utf-8") as f:
                self.def_cache = json.load(f)
        else:
            self.def_cache = {}

    def _save_def_cache(self):
        with open(DEF_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(self.def_cache, f, ensure_ascii=False, indent=2)


    def fetch_definition_wiktionary(self, word: str):
        params = {
            "action": "query",
            "format": "json",
            "titles": word,
            "prop": "extracts",
            "explaintext": True,
            "redirects": 1
        }

        try:
            r = requests.get(WIKTIONARY_API, params=params, timeout=5)
            data = r.json()
            page = next(iter(data["query"]["pages"].values()))
            extract = page.get("extract", "")
            return norm_ar(extract.split("\n")[0]) if extract else None
        except Exception:
            return None

    def _definition_proxy(self, query: str):
        q = norm_ar(query)

        if q in self.def_cache:
            definition = self.def_cache[q]
        else:
            definition = self.fetch_definition_wiktionary(query)
            if not definition:
                return None
            self.def_cache[q] = definition
            self._save_def_cache()

        tokens = definition.split()
        matched = [t for t in tokens if t in self.closed_vocab]

        if len(matched) >= 2:
            return {"type": "explain", "words": matched}

        return None

    def mean_pool(self, last_hidden_state, attention_mask):
        mask = attention_mask.unsqueeze(-1).float()
        return (last_hidden_state * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)

    @torch.inference_mode()
    def embed_texts(self, texts: List[str]):
        texts = [f"passage: {t}" for t in texts]
        enc = self.tokenizer(texts, padding=True, truncation=True, max_length=96, return_tensors="pt")
        enc = {k: v.to(self.device) for k, v in enc.items()}
        out = self.model(**enc)
        v = self.mean_pool(out.last_hidden_state, enc["attention_mask"])
        return torch.nn.functional.normalize(v, p=2, dim=1).cpu().numpy().astype(np.float32)

    def _build_index(self):
        emb = self.embed_texts(self.norm_ar_texts)
        self.index = faiss.IndexFlatIP(emb.shape[1])
        self.index.add(emb)


    def search(self, query_word: str, top_k=5):
        q = norm_ar(query_word)

        # kinship: always decompose
        if q in KINSHIP_HINTS:
            proxy = self._definition_proxy(query_word)
            if proxy:
                return proxy

        # exact atomic match (non-kinship)
        if q in self.norm_ar_texts and q not in KINSHIP_HINTS:
            idx = self.norm_ar_texts.index(q)
            return {"type": "match", "word": self.ar_texts[idx], "score": 1.0}

        # definition proxy
        proxy = self._definition_proxy(query_word)
        if proxy:
            return proxy

        # embeddings → explain only
        q_vec = self.embed_texts([q])
        D, I = self.index.search(q_vec, top_k)

        words = [
            self.ar_texts[i]
            for i in I[0]
            if is_atomic(self.ar_texts[i])
        ]

        if words:
            return {"type": "explain", "words": words[:1], "score": float(D[0][0])}

        return None

semantic_engine = SemanticEngine()
