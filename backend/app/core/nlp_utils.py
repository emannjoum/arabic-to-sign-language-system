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

QUESTION_WORDS = {"من", "ماذا", "أين", "اين", "متى", "كيف", "لماذا", "كم", "أي", "هل"}
NEG_WORDS = {"لا", "لم", "لن", "ليس", "ما", "أبدًا", "ابدا"}
STOP_WORDS = {"و", "ف", "ثم", "ان", "أن"}

def normalize_text(s: str) -> str:
    s = normalize_unicode(s)
    s = normalize_alef_ar(s)
    s = normalize_alef_maksura_ar(s)
    s = dediac_ar(s)
    return s

def transform_to_arsl(sentence: str) -> list[str]:
    clean_text = normalize_text(sentence)
    repeat_verb = False
    if "مرارا وتكرارا" in clean_text:
        repeat_verb = True
        clean_text = clean_text.replace("مرارا وتكرارا", "")
    tokens = simple_word_tokenize(clean_text)
    disambig_results = mle_disambig.disambiguate(tokens)
    arsl_sequence = []
    question_word = None
    negation_word = None
    has_q_mark = "؟" in sentence or "?" in sentence

    for i, result in enumerate(disambig_results):
        if not result.analyses:
            # Fallback if CAMeL fails to analyze a word (e.g., proper noun)
            arsl_sequence.append(tokens[i])
            continue
            
        # Get the best analysis
        analysis = result.analyses[0].analysis
        
        # 'analysis' is already a dictionary in modern Camel Tools
        # We access keys directly from it
        pos = analysis.get('pos', 'noun')
        token = tokens[i]

        if token in STOP_WORDS: continue
        if pos in ['pron_rel', 'prep', 'conj', 'abbrev']: continue 

        if token in QUESTION_WORDS:
            question_word = "سبب" if token == "لماذا" else token
            continue

        if token in NEG_WORDS:
            negation_word = "لا" 
            continue
 
        if analysis.get('gen') == 'f' and analysis.get('rat') == 'y': arsl_sequence.append("بنت")
        #if feat['vox'] == p : passivaiton (idk what to do yet)
        if analysis.get('num') == 'd':
            arsl_sequence.append("اثنان")
        elif analysis.get('num') == 'p':
            arsl_sequence.append("كثير")

        if analysis.get('asp') == 'p':     # Past
            arsl_sequence.append("قبل")
        elif analysis.get('asp') == 'c':   # Command
            arsl_sequence.append("لازم")
        elif analysis.get('prc0') == 'fut_s' or token == "سوف": # Future
            arsl_sequence.append("قريبا")
            if token == "سوف": continue

        raw_lemma = analysis.get('lex', token)
        clean_lemma = dediac_ar(raw_lemma)
        clean_lemma = clean_lemma.split('_')[0]

        if repeat_verb and pos == 'verb':
            arsl_sequence.extend([clean_lemma, clean_lemma, clean_lemma])
        else:
            arsl_sequence.append(clean_lemma)

    if negation_word: arsl_sequence.append("لا")
    if question_word:arsl_sequence.append(question_word)
    if has_q_mark or question_word: arsl_sequence.insert(0, "؟")
        
    return arsl_sequence

def extract_names(text: str) -> set:
    """Returns a set of words that are names (PERS)."""
    ner_results = ner_pipeline(text)
    names = set()
    for entity in ner_results:
        if "PERS" in entity['entity_group']:
            # Normalize the name (remove diacritics) to match your pipeline
            clean_name = normalize_text(entity['word'])
            names.add(clean_name)
    return names