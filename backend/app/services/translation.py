from dotenv import load_dotenv
from sqlalchemy.orm import Session
from app.core.nlp_utils import transform_to_arsl, normalize_text, get_signs_set
from app.core.agents import run_translation_analyzer
from app.db.models import Sign
from app.schemas import SkeletonFrame
from sqlalchemy import or_, cast, Text
from sqlalchemy.dialects.postgresql import ARRAY
from app.core.semantic import semantic_engine
#from app.core.nlp_utils import SIGNS_SET
from app.services.reordering_model import local_pointer_reorder
import re
from app.core.numbers_utils import get_protected_number_sequence

load_dotenv()

ARABIC_PREPOSITIONS = {"الى", "إلى", "عن", "على", "في", "حتى", "مذ", "منذ","من"}

def process_translation(user_input: str, db: Session):
    current_signs_set = get_signs_set(db)
    
    COMPOUND_SIGNS = sorted(
        [s for s in current_signs_set if " " in s and len(s.split()) >= 2],
        key=lambda x: -len(x)
    )

    intent_res = run_translation_analyzer(user_input)
    clean_text = normalize_text(intent_res.extracted_text)
    names = [normalize_text(n) for n in intent_res.names]
    
    print(f"Cleaned Input: '{clean_text}'")
    print(f"Extracted names: '{names}'")

    if len(clean_text) == 1 and re.match(r'[\u0600-\u06FF]', clean_text):
        sign_entry = find_sign_in_db(clean_text, db)
        return [SkeletonFrame(skeleton_url=sign_entry.skeleton_url, label=clean_text, delay_ms=0)]

    #if the to-be-translated sentence has a number we use the numbers function
    number_map = {}
    def mask_number_sequence(match):
        full_match = match.group()
        placeholder = f"[رقم_{len(number_map)}]" # Creates [رقم_0], [رقم_1], etc...

        # Split the match by spaces (in case the LLM spaced out a phone number)
        sub_tokens = full_match.split()

        sequence_parts = []
        for token in sub_tokens:
            sequence_parts.extend(get_protected_number_sequence(token))
            
        number_map[placeholder] = sequence_parts
        return placeholder
    
    # This regex catches integers AND decimals using dot, arabic comma, or english comma
    number_sequence_pattern = r'\b\d+(?:[.\٫،]\d+)?(?:\s+\d+(?:[.\٫،]\d+)?)*\b'
    clean_text = re.sub(number_sequence_pattern, mask_number_sequence, clean_text)
    print(f"Text after masking: {clean_text}")

    # Protect names by adding _ to them
    for name in names:
        if name in clean_text:
            protected_name = name.replace(" ", "_") + "_"
            clean_text = clean_text.replace(name, protected_name)

    # Protect DB Compound Signs
    for compound in COMPOUND_SIGNS:
        if compound in clean_text:
            protected_compound = compound.replace(" ", "_")
            clean_text = clean_text.replace(compound, protected_compound)

    # Protect Exact Single-Word DB Matches
    text_words = clean_text.split()
    filtered_words = []
    for w in text_words:
        if w in ARABIC_PREPOSITIONS: continue  
        if w in current_signs_set and "_" not in w: w = w + "_" 
        filtered_words.append(w)
    
    clean_text = " ".join(filtered_words)

    # Lemmatization (CAMeL Tools)
    lemmas_list = transform_to_arsl(clean_text)
    print(f"Lemmas after CAMeL: {lemmas_list}")

    # Syntax Reordering (Pointer Network)
    has_question_mark = False
    clean_lemmas = []
    for w in lemmas_list:
        if w in ["؟", "؟_"]: has_question_mark = True
        else: clean_lemmas.append(w.rstrip("_"))

    if len(clean_lemmas) > 2:
        lemmas_string = " ".join(clean_lemmas) 
        reordered_words = local_pointer_reorder(lemmas_string)
        print(f"Reordered: {lemmas_string} -> {reordered_words}")
    else:
        print(f"Short sentence — skipping reorder.")
        reordered_words = clean_lemmas
    
    reordered_words = [w for w in reordered_words if w.strip()]
    if has_question_mark: reordered_words.insert(0, "؟")

    # Unmasking: Inject the numbers back into the reordered sentence
    final_sequence = []
    for word in reordered_words:
        # If the word is one of our placeholders, expand it
        if word in number_map: final_sequence.extend(number_map[word])
        else: final_sequence.append(word)

    response_data = []

    for word in final_sequence:
        clean_word = word.replace("_", " ").strip()

        if clean_word in names:
            print(f"'{clean_word}' is a name. Fingerspelling immediately.")
            response_data.extend(get_fingerspelling_sequence(clean_word, db, is_name=True))
            continue

        sign_entry = find_sign_in_db(clean_word, db)
        if sign_entry:
            add_sign_to_response(response_data, sign_entry, clean_word)
            continue

        print(f"Direct match failed for '{clean_word}'. Trying Semantic Search...")
        semantic_result = semantic_engine.search(clean_word)

        if semantic_result:
            if semantic_result["type"] == "match":
                alt_word = semantic_result["word"]
                alt_sign = find_sign_in_db(alt_word, db)
                if alt_sign:
                    add_sign_to_response(response_data, alt_sign, clean_word)
                    continue

            elif semantic_result["type"] == "explain":
                found_explanation = False
                for w in semantic_result["words"]:
                    s = find_sign_in_db(w, db)
                    if s:
                        add_sign_to_response(response_data, s, w)
                        found_explanation = True
                if found_explanation:
                    continue

        print(f"All lookups failed for '{clean_word}'. Fingerspelling.")
        response_data.extend(get_fingerspelling_sequence(clean_word, db, is_name=False))

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

def get_fingerspelling_sequence(word: str, db: Session, is_name: bool = False):
    skeletons = []
    delay = 700 if is_name else 500
    for letter in word:
        clean_letter = letter.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ة', 'ه')
        
        letter_sign = db.query(Sign).filter(Sign.word == clean_letter).first()
        if letter_sign:
            skeletons.append(SkeletonFrame(
                skeleton_url=letter_sign.skeleton_url,
                label=clean_letter,
                delay_ms=delay
            ))
    return skeletons