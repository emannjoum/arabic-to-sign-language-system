import os
import json
from openai import OpenAI
from dotenv import load_dotenv
from fastapi import HTTPException
from app.schemas import RouterResult, IntentResult, TopicResult, VocabResult
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
        "الوقت", "دول العالم", "متفرقات", "الحروف"
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
    You are an expert AI system with TWO simultaneous tasks: Content Extraction and Arabic Named Entity Recognition (PERSON NAMES ONLY).

    --- TASK 1: CONTENT EXTRACTION ---
    Your role is to EXTRACT the specific content the user wants processed or translated.
    Remove polite phrases ("please", "can you", "لو سمحت"), command words and phrases ("translate", "how do you say", "what is the sign for", "ترجم", "ترجم جملة", "كيف احكي"), and punctuation.
    If the text contains the word 'من' and it is being used as a Question Word or Relative Pronoun meaning 'Who', you must replace it with the colloquial word 'مين'.
    If it means 'From', leave it exactly as 'من'.

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

    User: "انا سعيد اليوم"
    Output: {"extracted_text": "انا سعيد اليوم", "names": []}

    User: "قال محمد وعلي"
    Output: {"extracted_text": "محمد وعلي", "names": ["محمد", "علي"]}

    User: "انا ربى من الاردن"
    Output: {"extracted_text": "انا ربى من الاردن", "names": ["ربى"]}

    User: "انا ايهم من عمان"
    Output: {"extracted_text": "انا ايهم من عمان", "names": ["ايهم"]}
    
    User: "ترجم جملة السلام عليكم يا احمد"
    Output: {"extracted_text": "السلام عليكم يا احمد", "names": ["احمد"]}
    """
    try:
        data = call_llm_for_json(system_prompt, f"User message: {text}")
        return TranslationAnalysisResult(**data)
    except Exception:
        return TranslationAnalysisResult(extracted_text=text, names=[])