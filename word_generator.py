import os
import random
import sys

current_dir = os.path.abspath(os.getcwd())
root_dir = current_dir
while root_dir and not os.path.exists(os.path.join(root_dir, 'backend')):
    parent = os.path.dirname(root_dir)
    if parent == root_dir: break
    root_dir = parent

backend_dir = os.path.join(root_dir, 'backend')
if os.path.exists(backend_dir) and backend_dir not in sys.path:
    sys.path.append(backend_dir)

from backend.app.core.nlp_utils import transform_to_arsl

APPEND_MODE = True  # True to append, False to overwrite
TARGET_COUNT = 3000 # num of new sentences to generate

DATA_DIR = os.path.join(root_dir, 'data', 'new_5k_data')
os.makedirs(DATA_DIR, exist_ok=True)

CONFIGS = {
    'JO': {
        'src': os.path.join(DATA_DIR, 'jo_og_nlp_processed.txt'),
        'tgt': os.path.join(DATA_DIR, 'jo_targets.txt')
    },
    'MSA': {
        'src': os.path.join(DATA_DIR, 'msa_og_nlp_processed.txt'),
        'tgt': os.path.join(DATA_DIR, 'msa_targets.txt')
    }
}

# MSA, JO
VERBS = [
    ('يذهب', 'رايح'), ('يريد', 'بده'), ('رأى', 'شاف'), ('قال', 'حكى'), 
    ('وضع', 'حط'), ('فعل', 'سوا'), ('اشترى', 'اشترى'), ('نام', 'نام'), 
    ('شرب', 'شرب'), ('أكل', 'أكل'), ('درس', 'درس'), ('سافر', 'سافر')
]

SUBJECTS = [
    ('الولد', 'الولد'), ('الرجل', 'الزلمة'), ('المعلم', 'الاستاذ'), 
    ('المرأة', 'المرة'), ('صديقي', 'صاحبي'), ('أخي', 'اخوي'), 
    ('الطالب', 'الطالب'), ('الطفل', 'الطفل'), ('المدير', 'المدير')
]

OBJECTS = [
    ('إلى المدرسة', 'للمدرسة'), ('المال', 'المصاري'), ('العمل', 'الشغل'), 
    ('دراجة', 'بسكليت'), ('السيارة', 'السيارة'), ('البيت', 'البيت'), 
    ('الطعام', 'الأكل'), ('الملابس', 'الأواعي'), ('الماء', 'المي'),
    ('الهاتف', 'التلفون'), ('الكتاب', 'الكتاب'),
    ('الحقيبة', 'الشنطة'), ('الكمبيوتر', 'الكمبيوتر'),
    ('الباب', 'الباب'), ('النافذة', 'الشباك'),
    ('القهوة', 'القهوة'), ('الشاي', 'الشاي'),
]

ADJECTIVES = [
    ('جيدة', 'كويسة'), ('جميل', 'حلو'), ('سيء', 'عاطل'), 
    ('كبير', 'كبير'), ('صغير', 'صغير'), ('سريعة', 'سريعة'), 
    ('بطيء', 'بطيء'), ('نظيف', 'نظيف'),
    ('متسخ', 'وسخ'), ('غالي', 'غالي'),
    ('رخيص', 'رخيص'), ('قوي', 'قوي'),
    ('ضعيف', 'ضعيف'), ('ذكي', 'شاطر')
]

TIME_PHRASES = [
    ('الآن', 'هسا'), ('غدا', 'بكرة'), ('أمس', 'امبارح'), ('اليوم', 'اليوم'),
    ('صباحا', 'الصبح'), ('مساء', 'المسا'),
    ('الليلة', 'الليلة'), ('بعد قليل', 'بعد شوي'),
    ('قبل قليل', 'قبل شوي'), ('الأسبوع القادم', 'الأسبوع الجاي'),
    ('الأسبوع الماضي', 'الأسبوع الماضي'),
    ('الشهر القادم', 'الشهر الجاي'),
    ('دائما', 'دايما'), ('أحيانا', 'أحيانا'),
    ('نادرا', 'نادرا')
]

CONJUNCTIONS = [
    ('لأن الجو جميل', 'عشان الجو حلو'), 
    ('لأن الوقت متأخر', 'عشان الوقت متأخر'),
    ('ثم غادر', 'بعدين روح')
]

Q_WORDS_PAIRED = [
    ('كيف', 'كيف'), ('متى', 'ايمتى'), ('أين', 'وين'), ('لماذا', 'ليش'), 
    ('من', 'مين'), ('ماذا', 'شو'), ('كم', 'قديش')
]

Q_MARKS = ['؟', '?']
Q_WORDS_DETECT = ['كيف', 'متى', 'أين', 'اين', 'لماذا', 'من', 'ماذا', 'هل', 'كم', 'شلون', 'وين', 'ين', 'ليش', 'مين', 'شو', 'ايمتى', 'قديش']

def generate_parallel_sentence():
    template_type = random.randint(1, 8) 
    
    v = random.choice(VERBS)
    s = random.choice(SUBJECTS)
    o = random.choice(OBJECTS)
    a = random.choice(ADJECTIVES)
    t = random.choice(TIME_PHRASES)
    c = random.choice(CONJUNCTIONS)
    
    if template_type == 1:
        # يذهب الولد إلى المدرسة / رايح الولد للمدرسة
        msa = f"{v[0]} {s[0]} {o[0]}"
        jo = f"{v[1]} {s[1]} {o[1]}"
    elif template_type == 2:
        msa = f"{v[0]} {s[0]} {o[0]} {a[0]}"
        jo = f"{v[1]} {s[1]} {o[1]} {a[1]}"
    elif template_type == 3:
        msa = f"{s[0]} {v[0]} {o[0]} {c[0]}"
        jo = f"{s[1]} {v[1]} {o[1]} {c[1]}"
    elif template_type == 4:
        msa = f"{t[0]} {v[0]} {s[0]}"
        jo = f"{t[1]} {v[1]} {s[1]}"
    elif template_type == 5:
        msa = f"{o[0]} {v[0]} {s[0]}"
        jo = f"{o[1]} {v[1]} {s[1]}"
    # Short Sentence Templates
    elif template_type == 6:
        # 1 Word (Verb)
        msa = f"{v[0]}"
        jo = f"{v[1]}"
    elif template_type == 7:
        # 2 Words (Subject + Verb)
        msa = f"{s[0]} {v[0]}"
        jo = f"{s[1]} {v[1]}"
    else:
        # 2 Words (Subject + Adjective)
        msa = f"{s[0]} {a[0]}"
        jo = f"{s[1]} {a[1]}"

    # 80% chance to make it a question
    is_question = random.random() < 0.8
    if is_question:
        qw = random.choice(Q_WORDS_PAIRED)
        msa = f"{qw[0]} {msa} ؟"
        jo = f"{qw[1]} {jo} ؟"

    return msa, jo

def build_target_sequence(tokens): # '؟' at index 0, question word at the very end
    res = tokens.copy()
    
    found_qm = None
    for qm in Q_MARKS:
        if qm in res:
            res.remove(qm)
            found_qm = qm
            break
            
    found_qw = None
    for qw in Q_WORDS_DETECT:
        if qw in res:
            res.remove(qw)
            found_qw = qw
            break
            
    output = []
    if found_qm: output.append(found_qm)
    output.extend(res)
    if found_qw: output.append(found_qw)
    
    return output

def write_data(filepath, lines_to_write, append):
    if not lines_to_write: return
    mode = 'a' if append else 'w'
    with open(filepath, mode, encoding='utf-8') as f:
        # If appending to a non-empty file, add a newline first to avoid merging lines
        if append and os.path.exists(filepath) and os.path.getsize(filepath) > 0:
            f.write("\n")
        f.write("\n".join(lines_to_write))

def augment_parallel_datasets(target_count=5000, append_mode=True):
    print(f"\nGenerating {target_count} parallel synthetic sentences...")
    print(f"Mode: {'APPEND' if append_mode else 'OVERWRITE'}")
    
    generated_msa = set()
    
    # If appending, read existing MSA sources into the set to prevent duplicates
    if append_mode and os.path.exists(CONFIGS['MSA']['src']):
        with open(CONFIGS['MSA']['src'], 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    generated_msa.add(line.strip())
        print(f"Loaded {len(generated_msa)} existing sentences to avoid duplication.")
    
    new_msa_src, new_msa_tgt = [], []
    new_jo_src, new_jo_tgt = [], []
    
    attempts = 0
    while len(new_msa_src) < target_count and attempts < (target_count * 10):
        attempts += 1
        raw_msa, raw_jo = generate_parallel_sentence()
        
        nlp_msa = transform_to_arsl(raw_msa)
        nlp_jo = transform_to_arsl(raw_jo)
        
        if not nlp_msa or not nlp_jo: continue
        
        src_str_msa = " ".join(nlp_msa)
        src_str_jo = " ".join(nlp_jo)
        
        if src_str_msa in generated_msa:
            continue
            
        tgt_str_msa = " ".join(build_target_sequence(nlp_msa))
        tgt_str_jo = " ".join(build_target_sequence(nlp_jo))
        
        generated_msa.add(src_str_msa)
        
        new_msa_src.append(src_str_msa)
        new_msa_tgt.append(tgt_str_msa)
        
        new_jo_src.append(src_str_jo)
        new_jo_tgt.append(tgt_str_jo)

    write_data(CONFIGS['MSA']['src'], new_msa_src, append_mode)
    write_data(CONFIGS['MSA']['tgt'], new_msa_tgt, append_mode)
    
    write_data(CONFIGS['JO']['src'], new_jo_src, append_mode)
    write_data(CONFIGS['JO']['tgt'], new_jo_tgt, append_mode)
    
    print(f"Successfully generated {len(new_msa_src)} parallel sentences.")

if __name__ == "__main__":
    augment_parallel_datasets(target_count=TARGET_COUNT, append_mode=APPEND_MODE)
    if APPEND_MODE:
        print("\nData generation complete. New parallel data APPENDED to master files.")
    else:
        print("\nData generation complete. Master files OVERWRITTEN with new parallel data.")