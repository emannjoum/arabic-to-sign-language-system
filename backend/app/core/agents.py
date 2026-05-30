import os
import json
from openai import OpenAI
from dotenv import load_dotenv
from fastapi import HTTPException
from app.schemas import RouterResult, TopicResult
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from pydantic import BaseModel
from typing import List

load_dotenv()

CLASSIFIER_MODEL_NAME = os.getenv("CLASSIFIER_MODEL_NAME")
HF_TOKEN = os.getenv("HF_TOKEN")
try:
    cls_tokenizer = AutoTokenizer.from_pretrained(CLASSIFIER_MODEL_NAME, token=HF_TOKEN)
    cls_model = AutoModelForSequenceClassification.from_pretrained(CLASSIFIER_MODEL_NAME, token=HF_TOKEN)
    print(f"Intent Classifier '{CLASSIFIER_MODEL_NAME}' Loaded.")
except Exception as e:
    print(f"Error loading classifier: {e}")
    raise e

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
class TranslationAnalysisResult(BaseModel):
    extracted_text: str
    names: List[str]

def call_llm_for_json(system_prompt: str, user_prompt: str, temperature: float = 0.2) -> dict:
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt + "\n\nIMPORTANT: You must return valid JSON."},
                {"role": "user", "content": user_prompt}
            ],
            temperature=temperature,
            response_format={ "type": "json_object" } 
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:
        print(f"AI Service Error: {e}")
        raise HTTPException(status_code=500, detail="AI processing failed")

def run_router_model(text: str) -> RouterResult:
    inputs = cls_tokenizer(text, return_tensors="pt", truncation=True, max_length=128)
    
    with torch.no_grad():
        outputs = cls_model(**inputs)
    
    # Calculate probabilities
    probs = F.softmax(outputs.logits, dim=-1)
    confidence, predicted_class = torch.max(probs, dim=-1)
    
    # Map Model Output ID to Label
    labels = ["translation", "teaching"]
    predicted_label = labels[predicted_class.item()]
    
    return RouterResult(
        route=predicted_label,
        confidence=confidence.item(),
        reason="Fine-tuned model prediction"
    )

def run_topic_agent(text: str) -> TopicResult:
    system_prompt = """
    Analyze the user's message and determine the MAIN topic.
    
    CRITICAL: You MUST extract the main "topic" by choosing strictly from the following exact list of categories. Do not translate to English, do not use synonyms, and do not alter the spelling.
    
    Allowed Topics:
    [
        "إقتصاد", "الأرقام", "الأفعال", "الألوان", "الحيوانات", 
        "العائلة", "البيت", "التربية", "الحكومة والسياسة", "الدين", 
        "الصفات", "الطرق والمواصلات", "الطعام", "العلاقات الاجتماعية", 
        "الوقت", "دول العالم", "متفرقات", "الحروف", "علامات الترقيم
    ]
    
    If the text does not clearly match one of the specific topics, use "متفرقات" as the fallback.
    
    Return JSON format exactly like this: 
    {
        "topic": "<EXACT MATCH FROM ALLOWED TOPICS>", 
        "other_possible_topics": ["<related term 1>", "<related term 2>"], 
        "reason": "<brief explanation for your choice>"
    }
    """
    data = call_llm_for_json(system_prompt, f"User message: {text}")
    data.setdefault("other_possible_topics", [])
    return TopicResult(**data)

def run_translation_analyzer(text: str) -> TranslationAnalysisResult:
    system_prompt = """
    You are an expert AI system with TWO simultaneous tasks: Content Extraction & Number Formatting, and Arabic Named Entity Recognition (PERSON NAMES ONLY).

    --- TASK 1: CONTENT EXTRACTION & Number Formatting ---
    EXTRACT the specific content the user wants processed or translated, adhering to these rules:
    1. Remove polite phrases ("please", "لو سمحت"), command words ("translate", "ترجم", "كيف احكي").
    2. If the text contains 'من' acting as a Question Word/Relative Pronoun meaning 'Who', replace it with 'مين'. If it means 'From', leave it as 'من'.
    3. NUMBERS CONVERSION: Convert all Eastern Arabic numerals (٠١٢٣٤٥٦٧٨٩) to Western/English numerals (0123456789).
    4. NUMBERS SPACING (CRITICAL): 
       - QUANTITIES (years, prices, counts, amounts): Keep them as one block (e.g., "سعرها 25000", "عام 1970").
       - IDENTIFIERS (phone numbers, national IDs, passwords): Insert a single space between EVERY digit so they are spelled out one by one (e.g., "رقم هاتفي 9627912" becomes "رقم هاتفي 9 6 2 7 9 1 2").
    5. DETACH OCNJUNCTION: If the conjunction 'و' (and) is attached to a word, separate it with a space.
        Example: "أحمد ومحمد" -> "أحمد و محمد".
        Do not split words where 'و' is part of the root word (e.g., keep "ورقة" as "ورقة").
    6. QUESTION HANDLING: If the extracted text is interrogative (e.g., contains words like هل, كيف, متى, أين, لماذا, مين, كم, شو, ايش), ensure it ends with an Arabic question mark preceded by a single space (" ؟").
        If the user didn't include one, append it with a space. If they included one without a space, separate it.
    --- TASK 2: NAME EXTRACTION ---
    Your role is to detect PERSON NAMES ONLY from the original text.
    - Extract ONLY human person names (first names, last names, or full names).
    - NEVER extract place names, countries, or cities (الاردن, عمان, فلسطين, etc.).
    - NEVER extract words that could be verbs or adjectives (سعيد, يزيد, رامي could be verb/adj — only include if clearly used as a name).
    - Use context to decide: "انا يزيد" → يزيد is a name. "الماء يزيد" → يزيد is a verb.
    - Return each name in its original form as it appears in the text. Ensure "names" is ALWAYS a JSON array (list).

    --- JSON OUTPUT FORMAT ---
    Return ONLY a JSON object matching this exact schema:
    {
        "extracted_text": "<string of the cleaned text>",
        "names": ["<string_name_1>", "<string_name_2>"]
    }
    If no names are found, return an empty list for "names": []

    --- EXAMPLES ---
    User: "How do I sign 'I go to school'?"
    Output: {"extracted_text": "I go to school", "names": []}

    User: "Translate hello"
    Output: {"extracted_text": "hello", "names": []}

    User: "مرحبا انا يزيد"
    Output: {"extracted_text": "انا يزيد", "names": ["يزيد"]}

    User: "الانتاج يزيد كل يوم"
    Output: {"extracted_text": "الانتاج يزيد كل يوم", "names": []}

    User: "ترجم رقم هاتفي هو ٠٧٩١٢٣٤٥"
    Output: {"extracted_text": "رقم هاتفي هو 0 7 9 1 2 3 4 5", "names": []}

    User: "رقمي الوطني 9981023456"
    Output: {"extracted_text": "رقمي الوطني 9 9 8 1 0 2 3 4 5 6", "names": []}

    User: "ولدت عام ١٩٩٨ واسمي رامي"
    Output: {"extracted_text": "ولدت عام 1998 واسمي رامي", "names": ["رامي"]}

    User: "معي ٢٥٠٠٠ دينار"
    Output: {"extracted_text": "معي 25000 دينار", "names": []}

    User: "انا سعيد اليوم"
    Output: {"extracted_text": "انا سعيد اليوم", "names": []}

    User: "قال محمد وعلي"
    Output: {"extracted_text": "محمد وعلي", "names": ["محمد", "علي"]}

    User: "انا ربى من الاردن"
    Output: {"extracted_text": "انا ربى من الاردن", "names": ["ربى"]}
    
    User: "ترجم جملة السلام عليكم يا احمد"
    Output: {"extracted_text": "السلام عليكم يا احمد", "names": ["احمد"]}

    User: "كيف اروح على الجامعة"
    Output: {"extracted_text": "كيف اروح على الجامعة ؟", "names": []}
    """
    try:
        data = call_llm_for_json(system_prompt, f"User message: {text}")
        return TranslationAnalysisResult(**data)
    except Exception:
        return TranslationAnalysisResult(extracted_text=text, names=[])
    

def run_compound_verifier_agent(target_word: str, word1: str, word2: str) -> dict:
    system_prompt = """
    You are an EXTREMELY STRICT Arabic Sign Language (ArSL) linguistics expert. 
    TASK 1: Determine if combining the two provided words is ABSOLUTELY NECESSARY and ACCURATELY conveys the visual meaning of the Target Word ("is_valid").
    
    CRITICAL RULES FOR REJECTION ("is_valid": false):
    1. ArSL is concise! If one word alone (like "العالم") captures the core meaning of the target (like "عالمي" or "عالمية"), the second word is redundant garbage. Reject the compound.
    2. Do NOT approve metaphorical, philosophical, or loosely related concepts. "World Culture" (العالم ثقافة) is NOT a valid direct translation for "Global" (عالمي). Reject it.
    
    TASK 2: Choose the most core/central noun ("best_fallback") from the two words to represent the Target. You MUST choose one.
    HOWEVER if neither are suitable/perfect match return best_fallback as None.

    Examples:
    - Target: لبؤة | Words: بنت, اسد -> {"is_valid": true, "best_fallback": "اسد"}
    - Target: شبل | Words: ولد, اسد -> {"is_valid": true, "best_fallback": "اسد"}
    - Target: عالمي | Words: العالم, ثقافة -> {"is_valid": false, "best_fallback": "العالم"}
    - Target: سيكولوجية | Words: بحث, شخص -> {"is_valid": false, "best_fallback": None}
    - Target: عالمية | Words: العالم, ثقافة -> {"is_valid": false, "best_fallback": "العالم"}
    - Target: مباشرة | Words: صغير, شارع -> {"is_valid": false, "best_fallback": None}
    
    Return ONLY a JSON object:
    {
        "is_valid": true/false,
        "best_fallback": "<one of the two words>"/None
    }
    """
    
    user_message = f"Target: {target_word} | Words: {word1}, {word2}"
    
    try:
        # Pass temperature=0.0 to completely kill the model's "creativity"
        return call_llm_for_json(system_prompt, user_message, temperature=0.0)
    except Exception as e:
        print(f"[Log - Compound Verifier AI Error] {e}")
        return {"is_valid": False, "best_fallback": word1}