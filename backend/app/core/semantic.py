import os
import json
import sys
import requests
import re
import time
import random

"""BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if BACKEND_DIR not in sys.path:
    sys.path.append(BACKEND_DIR)
""" # please dont delete this i use it for quick testing
import numpy as np
import torch
import faiss
from transformers import AutoTokenizer, AutoModel
from typing import List
from backend.app.db.database import SessionLocal, Base
from sqlalchemy import Column, Integer, String
from sqlalchemy.dialects.postgresql import ARRAY 
from backend.app.db.models import Sign

EMBED_MODEL = "silma-ai/silma-embedding-sts-v0.1"
BOT_USER_AGENT = "SignlySemanticEng/1.0 (https://github.com/signly/signly; signly4@gmail.com)"

# paths/directories might cause a fuss during integration as i was testing this file as a standalone
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) # you mighttt want to delete this after integration
DEF_CACHE_PATH = os.path.join(BASE_DIR, "data", "def_cache.json") # i used this in _load_def_cache line 103 

def is_atomic(text: str) -> bool:
    return len((text).split()) == 1

def is_pure_arabic(text: str) -> bool:
    return bool(re.match(r'^[\u0621-\u064A]+$', text))

def strip_tashkeel(text: str) -> str:
    return re.sub(re.compile(r'[\u0617-\u061A\u064B-\u0652\u0640]'), '', text)

def get_arabic_variations(text: str) -> list:
    variations = set([text])
    no_hamza = re.sub(r'[أإآ]', 'ا', text)
    variations.add(no_hamza)
    
    for w in list(variations):
        variations.add(w.replace('ى', 'ي'))
        variations.add(w.replace('ي', 'ى'))
        
    for w in list(variations):
        variations.add(w.replace('ة', 'ه'))
        variations.add(w.replace('ه', 'ة'))
        
    return list(variations)

class SemanticEngine:
    def __init__(self):
        print("Loading Semantic Engine components...")

        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        print(f"Loading embedding model ({EMBED_MODEL}) on {self.device}...")
        self.tokenizer = AutoTokenizer.from_pretrained(EMBED_MODEL, use_fast=True)
        
        self.model = AutoModel.from_pretrained(
            EMBED_MODEL,
            torch_dtype=torch.float16 if self.device == "cuda" else torch.float32
        ).to(self.device).eval()

        self.http_session = requests.Session()
        self.http_session.headers.update({"User-Agent": BOT_USER_AGENT})

        self._load_data()
        self._load_def_cache()
        self._build_index()

        print(f"Semantic Engine ready. Index size: {self.index.ntotal}")

    def _load_data(self):
        db = SessionLocal()
        try:
            records = db.query(Sign.word, Sign.keywords).filter(Sign.word.isnot(None)).all()
            self.ar_texts = []           
            self.exact_match_dict = {}   
            self.faiss_texts = []        
            self.faiss_targets = []      

            for word, keywords in records:
                word_str = str(word)
                self.ar_texts.append(word_str)
                if word_str not in self.exact_match_dict:
                    self.exact_match_dict[word_str] = word_str
                self.faiss_texts.append(word_str)
                self.faiss_targets.append(word_str)

                if keywords:
                    for kw in keywords:
                        kw_str = str(kw)
                        if kw_str not in self.exact_match_dict:
                            self.exact_match_dict[kw_str] = word_str
                        self.faiss_texts.append(kw_str)
                        self.faiss_targets.append(word_str)
        finally:
            db.close()

    def _load_def_cache(self):
        if os.path.exists(DEF_CACHE_PATH):
            with open(DEF_CACHE_PATH, "r", encoding="utf-8") as f:
                self.def_cache = json.load(f)
        else:
            self.def_cache = {}

    def _save_def_cache(self):
        os.makedirs(os.path.dirname(DEF_CACHE_PATH), exist_ok=True)
        with open(DEF_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(self.def_cache, f, ensure_ascii=False, indent=2)

    def _fetch_wiki_vocab(self, word: str) -> list:
        STOP_WORDS = {
            "من", "في", "على", "عن", "إلى", "الى", "غير", "ذات", "نفس", "نفسه", 
            "جمع", "صفة", "أو", "او", "هي", "هو", "الذي", "التي", "هذا", "هذه", 
            "مع", "كل", "بعض", "أي", "اي", "بين", "كما", "اسم", "أصل", "اصل",
            "جذر", "مفرد", "مذكر", "مؤنث", "معنى", "لغة", "كلمة", "لغات",
            "يونانية", "لاتينية", "فارسية", "تركية", "عربية", "عربي", "إنجليزية", "فرنسية",
            "مثال", "أمثلة", "نحو", "مثل", "وقيل", "مصدر", "فعل", "حرف", "باب", "نصر", "ضرب", "صيغة"
        }

        def _is_safe(w: str) -> bool:
            if len(w) <= 1: return False
            base = w[2:] if w.startswith("ال") else w
            base_norm = get_arabic_variations(base)
            return w not in STOP_WORDS and base not in STOP_WORDS and base_norm not in STOP_WORDS

        words_to_try = [word]
        if not word.startswith("ال"):
            words_to_try.append("ال" + word)

        for current_word in words_to_try:
            url = "https://ar.wiktionary.org/w/api.php"
            TARGET_SUBSTRINGS = ["مرادف", "علاق", "جذر", "أصل", "معان", "عربي"]
            extracted_words = set()
            
            search_params = {
                "action": "query", "format": "json",
                "list": "search", "srsearch": current_word, "srlimit": 3 
            }
            
            try:
                response = self.http_session.get(url, params=search_params, timeout=5)
                search_results = response.json().get("query", {}).get("search", [])
                
                if not search_results: 
                    continue

                for result in search_results:
                    actual_title = result["title"]
                    is_exact_match = (strip_tashkeel(actual_title) == strip_tashkeel(current_word))
                    time.sleep(random.uniform(0.2, 0.5)) 
                    
                    section_params = {
                        "action": "parse", "format": "json",
                        "page": actual_title, "prop": "sections"
                    }
                    
                    res_sections = self.http_session.get(url, params=section_params, timeout=5)
                    sections = res_sections.json().get("parse", {}).get("sections", [])
                    
                    target_indices = []
                    
                    for sec in sections:
                        sec_name = strip_tashkeel(sec['line']).strip()
                        if any(target in sec_name for target in TARGET_SUBSTRINGS):
                            target_indices.append(sec['index'])
                    
                    if not target_indices:
                        if is_exact_match:
                            target_indices = [None] 
                        else:
                            continue 

                    is_disambiguation_page = False

                    for idx in target_indices:
                        time.sleep(random.uniform(0.2, 0.5))
                        text_params = {
                            "action": "parse", "format": "json",
                            "page": actual_title, "prop": "wikitext"
                        }
                        if idx is not None:
                            text_params["section"] = idx
                            
                        res_text = self.http_session.get(url, params=text_params, timeout=5)
                        wikitext = res_text.json().get("parse", {}).get("wikitext", {}).get("*", "")
                        
                        # abort from:
                        if "{{توضيح}}" in wikitext or "هل تقصد" in wikitext:
                            is_disambiguation_page = True
                            break 
                        
                        # 1. Standard Bracket/Root Extraction
                        links = re.findall(r'\[\[(?!ملف:|تصنيف:)([^\]\|]+)(?:\|[^\]]+)?\]\]', wikitext)
                        roots = re.findall(r'\{\{(?:جذر\d*|مشتقة من/الجذر)\|([^{}]+)\}\}', wikitext)
                        raw_extracted = links + [re.sub(r'[\|\s]', '', r) for r in roots]
                        
                        for w in raw_extracted:
                            clean = strip_tashkeel(w.strip())
                            if is_atomic(clean) and is_pure_arabic(clean) and _is_safe(clean):
                                extracted_words.add(clean)

                        # 2. Plain-Text DB Sniffer (to 40 words)
                        clean_text = re.sub(r'\[\[.*?\]\]|\{\{.*?\}\}|={2,}|[^\w\s]', ' ', wikitext)
                        sniffed_words = set()

                        for raw_word in clean_text.split()[:40]:
                            clean_w = strip_tashkeel(raw_word.strip())
                            
                            if is_pure_arabic(clean_w) and _is_safe(clean_w):
                                candidates = get_arabic_variations(clean_w)
                                if clean_w.startswith("ال"):
                                    stripped = clean_w[2:]
                                    if len(stripped) > 1 and _is_safe(stripped):
                                        candidates.extend(get_arabic_variations(stripped))
                                
                                for candidate in candidates:
                                    if candidate in self.exact_match_dict:
                                        sniffed_words.add(candidate)
                                        break 

                        if len(sniffed_words) <= 4:
                            extracted_words.update(sniffed_words)
                        else:
                            print(f"[Log - Wiki API] Sniffer found {len(sniffed_words)} words. Discarding story noise.")

                    # If the tripwire was triggered, clear any garbage and move to the next search result
                    if is_disambiguation_page:
                        extracted_words.clear()
                        continue

                    if extracted_words:
                        return list(extracted_words)

            except Exception as e:
                print(f"[Log - Wiki API] Fetch failed for '{current_word}': {e}")
                continue 
                
        return []
        
    def _wiki_fallback(self, query: str, query_embedding: np.ndarray):
        if query in self.def_cache:
            wiki_words = self.def_cache[query]
            print(f"[Log - Wiki Cache] Found locally for '{query}': {wiki_words}")
        else:
            wiki_words = self._fetch_wiki_vocab(query)
            if not wiki_words:
                print(f"[Log - Wiki API] No valid vocabulary extracted for '{query}'.")
                return None
            self.def_cache[query] = wiki_words
            self._save_def_cache()
            print(f"[Log - Wiki API] Retrieved and cached for '{query}': {wiki_words}")

        print(f"[Log - Wiki Fallback] Mapping Wiki words to DB using Vector Search...")
        wiki_vecs = self.embed_texts(wiki_words)
        
        D, I = self.index.search(wiki_vecs, 1)
        
        candidate_db_words = []
        for score_list, idx_list in zip(D, I):
            score = float(score_list[0])
            if score >= 0.70: 
                db_word = self.faiss_targets[idx_list[0]]
                if db_word not in candidate_db_words:
                    candidate_db_words.append(db_word)

        # forcefully include any Wiki word that is exactly in our db
        for w in wiki_words:
            if w in self.exact_match_dict:
                db_word = self.exact_match_dict[w]
                if db_word not in candidate_db_words:
                    candidate_db_words.append(db_word)

        if not candidate_db_words:
            print(f"[Log - Wiki Fallback] None of the wiki words {wiki_words} map to DB with >= 70% confidence.")
            return None

        print(f"[Log - Vector Ranking] Found DB candidates: {candidate_db_words}. Ranking for relevance...")
        candidate_embeddings = self.embed_texts(candidate_db_words)
        similarities = np.dot(candidate_embeddings, query_embedding.T).flatten()
        
        ranked_indices = np.argsort(similarities)[::-1]
        
        # Compound Synthesizer
        valid_sequence = []
        for idx in ranked_indices:
            score = float(similarities[idx])
            if score > 0.25:
                valid_sequence.append(candidate_db_words[idx])

        if not valid_sequence:
            return None

        # If there's only one valid match, return standard match
        if len(valid_sequence) == 1:
            return {
                "type": "match", 
                "word": valid_sequence[0], 
                "score": float(similarities[ranked_indices[0]]), 
                "source": "wiki_fallback"
            }
        # If there are multiple valid concepts, return them as a synthesized compound sequence
        else:
            return {
                "type": "explain", 
                "words": valid_sequence[:2], 
                "score": float(similarities[ranked_indices[0]]), 
                "source": "wiki_compound"
            }
    
    def mean_pool(self, last_hidden_state, attention_mask):
        mask = attention_mask.unsqueeze(-1).float()
        return (last_hidden_state * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)

    @torch.inference_mode()
    def embed_texts(self, texts: List[str]):
        enc = self.tokenizer(texts, padding=True, truncation=True, max_length=96, return_tensors="pt")
        enc = {k: v.to(self.device) for k, v in enc.items()}
        out = self.model(**enc)
        v = self.mean_pool(out.last_hidden_state, enc["attention_mask"])
        return torch.nn.functional.normalize(v, p=2, dim=1).cpu().numpy().astype(np.float32)

    def _build_index(self):
        emb = self.embed_texts(self.faiss_texts)
        self.index = faiss.IndexFlatIP(emb.shape[1])
        self.index.add(emb)

    def search(self, query_word: str, top_k=5, sim_threshold=0.70):
        q = query_word.strip()

        print(f"\nProcessing Query: '{q}'")

        # 1. Structural check for exact matches
        if q in self.exact_match_dict:
            main_word = self.exact_match_dict[q]
            print(f"[Log - Exact Match] '{q}' matched exactly. Resolving to main word: '{main_word}'")
            return {"type": "match", "word": main_word, "score": 1.0}

        # 2. Mathematical semantic vector distance search
        q_vec = self.embed_texts([q])
        D, I = self.index.search(q_vec, top_k)
        
        top_score = float(D[0][0])
        best_idx = I[0][0]
        
        best_matched_text = self.faiss_texts[best_idx]
        best_main_word = self.faiss_targets[best_idx]

        print(f"[Log - Vector Semantic] Closest entry: '{best_matched_text}' (Score: {top_score:.4f})")
        
        if top_score >= sim_threshold:
            if best_matched_text == best_main_word:
                 print(f"[Log - Vector Semantic] Confidence >= {sim_threshold*100}%. Matched main word: '{best_main_word}'")
            else:
                 print(f"[Log - Vector Semantic] Confidence >= {sim_threshold*100}%. Matched keyword '{best_matched_text}'. Resolving to parent sign: '{best_main_word}'")
            
            return {"type": "match", "word": best_main_word, "score": top_score}

        # 3. Pivot to the deterministic dictionary fallback (Uses Wiki Data + Vector Ranking)
        print(f"[Log - Vector Semantic] Confidence < {sim_threshold*100}%. Activating Dictionary lookup module...")
        wiki_proxy = self._wiki_fallback(q, q_vec)
        if wiki_proxy:
            return wiki_proxy

        # 4. Fingerspelling
        print(f"[Log - Terminal Fallback] All semantic and dictionary logic exhausted. Defaulting to fingerspelling for '{q}'.")
        return {"type": "spell", "word": q}