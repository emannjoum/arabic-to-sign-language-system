import requests
import re
import time
import random
import arabic_reshaper
from bidi.algorithm import get_display

BOT_USER_AGENT = "SignlySemanticEng/1.0 (https://github.com/signly/signly; signly@gmail.com)"
session = requests.Session()
session.headers.update({"User-Agent": BOT_USER_AGENT})

def is_atomic(text: str) -> bool:
    return len(text.split()) == 1

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

def normalize_alef(text: str) -> str:
    return re.sub(r'[أإآ]', 'ا', text)

def format_arabic(text: str) -> str:
    if not text: return ""
    return get_display(arabic_reshaper.reshape(text))

def debug_wiki_page(word: str):
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
        base_norm = normalize_alef(base)
        return w not in STOP_WORDS and base not in STOP_WORDS and base_norm not in STOP_WORDS

    words_to_try = [word]
    if not word.startswith("ال"):
        words_to_try.append("ال" + word)

    for current_word in words_to_try:
        url = "https://ar.wiktionary.org/w/api.php"
        TARGET_SUBSTRINGS = ["مرادف", "علاق", "جذر", "أصل", "معان", "عربي"]
        
        search_params = {
            "action": "query", "format": "json",
            "list": "search", "srsearch": current_word, "srlimit": 3 
        }
        
        try:
            response = session.get(url, params=search_params, timeout=5)
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
                
                res_sections = session.get(url, params=section_params, timeout=5)
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
                    text_params = {
                        "action": "parse", "format": "json",
                        "page": actual_title, "prop": "wikitext"
                    }
                    if idx is not None:
                        text_params["section"] = idx
                        
                    res_text = session.get(url, params=text_params, timeout=5)
                    wikitext = res_text.json().get("parse", {}).get("wikitext", {}).get("*", "")
                    
                    if "{{توضيح}}" in wikitext or "هل تقصد" in wikitext:
                        is_disambiguation_page = True
                        break 
                    
                    print(f"\n[{format_arabic('نجاح')}] Found dictionary entry at page: {format_arabic(actual_title)}")
                    
                    # 1. Standard Extraction
                    links = re.findall(r'\[\[(?!ملف:|تصنيف:)([^\]\|]+)(?:\|[^\]]+)?\]\]', wikitext)
                    roots = re.findall(r'\{\{(?:جذر\d*|مشتقة من/الجذر)\|([^{}]+)\}\}', wikitext)
                    raw_extracted = links + [re.sub(r'[\|\s]', '', r) for r in roots]
                    
                    clean_extracted = set()
                    for w in raw_extracted:
                        clean = strip_tashkeel(w.strip())
                        if is_atomic(clean) and is_pure_arabic(clean) and _is_safe(clean):
                            clean_extracted.add(clean)

                    print(f"-> Bracket/Root Words Extracted: {[format_arabic(w) for w in clean_extracted]}")

                    # 2. Text Sniffer Preview 
                    clean_text = re.sub(r'\[\[.*?\]\]|\{\{.*?\}\}|={2,}|[^\w\s]', ' ', wikitext)
                    first_35_words = clean_text.split()[:35]
                    first_35_clean = [strip_tashkeel(w) for w in first_35_words]
                    
                    print(f"-> Raw Text (First 35 words the sniffer reads):")
                    print(format_arabic(" ".join(first_35_clean)))
                    print("-" * 40)
                    return 

                if is_disambiguation_page:
                    continue

        except Exception as e:
            print(f"Fetch failed for '{current_word}': {e}")
            continue 
            
    print(f"\nNo valid Wiki data found for: {format_arabic(word)}")

if __name__ == "__main__":
    while True:
        try:
            w = input("\nEnter word to debug: ").strip()
            if w:
                debug_wiki_page(w)
        except KeyboardInterrupt:
            break