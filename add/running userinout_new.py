from camel_tools.disambig.mle import MLEDisambiguator
from camel_tools.tokenizers.word import simple_word_tokenize
from camel_tools.utils.dediac import dediac_ar

mle = MLEDisambiguator.pretrained() #mle stands for maximum likelihood estimation
QUESTION_WORDS = {"من", "ماذا", "أين", "اين", "متى", "كيف", "لماذا", "كم", "أي"}
NEG_WORDS = {"لا", "لم", "لن", "ليس", "ما", "أبدًا", "ابدا"}
STOP_WORDS = {"و", "ف", "ثم"}

def transform_to_arsl(sentence):
    repeat_verb = False
    if "مرارا وتكرارا" in sentence:
        repeat_verb = True
        sentence = sentence.replace("مرارا وتكرارا", "")
    
    tokens = simple_word_tokenize(sentence)
    disambig_results = mle.disambiguate(tokens)    
    arsl_sentence = []
    question_word = None
    negation_word = None
    has_q_mark = "؟" in sentence or "?" in sentence
    
    for i, result in enumerate(disambig_results):
        analysis = result.analyses[0].analysis # get the top-ranked analysis
        feat = result.analyses[0].analysis #this dictionary has tags to give the words
        token = tokens[i]
        
        if token in STOP_WORDS: continue
        
        if feat['pos'] in ['pron_rel', 'prep', 'conj']: continue #HANDLE DELETIONS (Particles/Relative Nouns)
        
        if token in QUESTION_WORDS:
            question_word = "سبب" if token == "لماذا" else token
            continue

        if token in NEG_WORDS:
            negation_word = token # Or you can map all to "لا" or "لا يوجد"
            continue

        if feat['gen'] == 'f' and feat['rat'] == 'y': arsl_sentence.append("بنت") # gender (Human Female)
        # if feat['vox'] == p : passivaiton (idk what to do yet)

          
        # Number (Dual/Plural)
        if feat['num'] == 'd': arsl_sentence.append("اثنان")
        elif feat['num'] == 'p': arsl_sentence.append("كثير")
            
        # Tense (Past/Command)
        if feat['asp'] == 'p': arsl_sentence.append("قبل")
        elif feat['asp'] == 'c': arsl_sentence.append("لازم")
        elif feat.get('asp') == 'i': arsl_sentence.append("الآن") # Present Continuous (Imperfective)
        
        if feat.get('prc0') == 'fut_s' or token == "سوف":
            arsl_sentence.append("قريبا")
            if token == "سوف": continue
        
        lemma = dediac_ar(feat.get('lex', token))
            
        arsl_sentence.append(lemma)
        if repeat_verb and feat['pos'] == 'verb':
            arsl_sentence.extend([lemma, lemma, lemma])
        else:
            arsl_sentence.append(lemma)
    
    if negation_word: arsl_sentence.append("لا")
    if question_word: arsl_sentence.append(question_word)
    if has_q_mark or question_word: arsl_sentence.insert(0, "؟")

    return " ".join(arsl_sentence)

input = "هل البنتان قرأتا الكتاب مرارا وتكرارا؟"
output = transform_to_arsl(input)
print(output)