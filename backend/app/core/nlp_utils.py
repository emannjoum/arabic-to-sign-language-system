import re
from camel_tools.utils.normalize import (
    normalize_unicode,
    normalize_alef_ar,
    normalize_alef_maksura_ar,
)
from camel_tools.utils.dediac import dediac_ar
from camel_tools.tokenizers.word import simple_word_tokenize
from camel_tools.morphology.database import MorphologyDB
from camel_tools.morphology.analyzer import Analyzer
from camel_tools.disambig.mle import MLEDisambiguator
from transformers import pipeline
from app.db.database import SessionLocal
from app.db.models import Sign

LEMMA_CORRECTIONS = {
    "نما": "نام",
    "مشي": "مشى",
    "أراد": "الأردن",
    # add more as you find them
}

try:
    db = MorphologyDB.builtin_db()
    analyzer = Analyzer(db)
    mle_disambig = MLEDisambiguator.pretrained()
    print("CAMeL Tools loaded successfully.")
except Exception as e:
    print(f"Error loading CAMeL Tools data: {e}")
    print("Did you run 'camel_data -i morphology-db-msa-r13'?")
    raise e

ner_pipeline = pipeline("ner", model="CAMeL-Lab/bert-base-arabic-camelbert-mix-ner", aggregation_strategy="simple")

QUESTION_WORDS = {"مين", "ماذا", "وين", "اين", "متى", "كيف", "لماذا", "كم", "أي", "هل","ليش","لويش","ليه","ايش","شو","لويه"}
NEG_WORDS = {"لا", "لم", "لن", "ليس", "ما", "أبدًا", "ابدا"}
STOP_WORDS = {"يا","و", "ف", "ثم", "ان", "أن"}
CONDITIONAL_WORDS = {"اذا", "لو", "لولا", "كلما", "إن", "ان", "كيفما", "اينما"}

def normalize_text(s: str) -> str:
    s = normalize_unicode(s)
    s = normalize_alef_ar(s)
    s = dediac_ar(s)
    return s


def load_signs_set():
    db = SessionLocal()
    try:
        signs = db.query(Sign.word, Sign.keywords).all()
        result = set()
        for row in signs:
            if row[0]:
                result.add(normalize_text(row[0]))
            if row[1]:
                for keyword in row[1]:
                    if keyword:
                        result.add(normalize_text(keyword))
        return result
    finally:
        db.close()


SIGNS_SET = load_signs_set()
print(f"Loaded {len(SIGNS_SET)} signs into N-gram set.")

def transform_to_arsl(sentence: str) -> list[str]:
    print(f"transform_to_arsl received: '{sentence}'")
    
    clean_text = normalize_text(sentence)

    repeat_verb = False
    if "مرارا وتكرارا" in clean_text:
        repeat_verb = True
        clean_text = clean_text.replace("مرارا وتكرارا", "")

    #tokens = simple_word_tokenize(clean_text)
    tokens = clean_text.split()
    disambig_results = mle_disambig.disambiguate(tokens)
    arsl_sequence = []
    question_word = None
    negation_word = None

    for i, result in enumerate(disambig_results):
        token = tokens[i]

        if "_" in token:
            arsl_sequence.append(token)
            continue

        if not result.analyses:
            arsl_sequence.append(tokens[i])
            continue
            
        analysis = result.analyses[0].analysis
        
        # 'analysis' is already a dictionary in modern Camel Tools
        # We access keys directly from it
        pos = analysis.get('pos', 'noun')

        if token in STOP_WORDS: continue
        if token in CONDITIONAL_WORDS: continue
        if pos in ['prep', 'conj', 'abbrev']: continue

        if token in QUESTION_WORDS:
            question_word = "سبب" if token == "لماذا" or token == "ليش" or token == "لويش" else token
            continue
        
        if pos == 'pron_rel': continue
        
        if token in NEG_WORDS:
            negation_word = "لا" 
            continue
 
        if analysis.get('gen') == 'f' and analysis.get('rat') == 'y':
            arsl_sequence.append("بنت")

        if analysis.get('num') == 'd' and "اثنان" not in arsl_sequence:
            arsl_sequence.append("اثنان")
        elif analysis.get('num') == 'p' and "كثير" not in arsl_sequence:
            arsl_sequence.append("كثير")

        if analysis.get('asp') == 'p':     # Past
            arsl_sequence.append("قبل")
        elif analysis.get('asp') == 'c':   # Command
            arsl_sequence.append("لازم")
        elif analysis.get('prc0') == 'fut_s' or token == "سوف": # Future
            arsl_sequence.append("قريبا")
            if token == "سوف": continue
        elif analysis.get('asp') == 'i':   # Imperfective (Present)
            arsl_sequence.append("الان")
        
        
        raw_lemma = analysis.get('lex', token)
        clean_lemma = dediac_ar(raw_lemma)
        clean_lemma = clean_lemma.split('_')[0]
        clean_lemma = LEMMA_CORRECTIONS.get(clean_lemma, clean_lemma)

        if repeat_verb and pos == 'verb':
            arsl_sequence.extend([clean_lemma, clean_lemma, clean_lemma])
        else:
            arsl_sequence.append(clean_lemma)

    if negation_word: arsl_sequence.append("لا")
    if question_word:arsl_sequence.append(question_word)
 
    return arsl_sequence