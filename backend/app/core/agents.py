import os
import json
from openai import OpenAI
from dotenv import load_dotenv
from fastapi import HTTPException
from app.schemas import RouterResult, IntentResult, TopicResult, VocabResult
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

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

def run_intent_agent(text: str, route: str) -> IntentResult:
    system_prompt = """
    You are an intent detector and content extractor.
    
    1. Determine the specific intent based on the route.
    2. EXTRACT the specific content the user wants processed. Remove polite phrases ("please", "can you"), command words ("translate", "how do you say", "what is the sign for"), and punctuation.
    
    Example 1:
    User: "How do I sign 'I go to school'?"
    Output JSON: {"mode": "translation", "intent": "sentence_to_sign", "extracted_text": "I go to school", "reason": "..."}

    Example 2:
    User: "Translate hello"
    Output JSON: {"mode": "translation", "intent": "word_to_sign", "extracted_text": "hello", "reason": "..."}

    Return JSON matching the IntentResult schema.
    """
    data = call_llm_for_json(system_prompt, f"Route: {route}\nUser message: {text}")
    return IntentResult(**data)

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

def run_vocab_agent(text: str, topic: str) -> VocabResult:
    system_prompt = """
    Extract explicit words related to the topic
    Return JSON: {"topic": "...", "words": [...]}
    """
    data = call_llm_for_json(system_prompt, f"Topic: {topic}\nUser message: {text}")
    data.setdefault("topic", topic)
    return VocabResult(**data)



def extract_names_with_llm(text: str) -> list:
    # system_prompt = """
    # You are an Arabic named entity recognition system.
    # Extract ONLY person names from the given Arabic text, don`t extract any other names like places or contires just person names.
    # Return ONLY a JSON object with a "names" key containing a list of names.
    # If no person names are found, return {"names": []}.
    # Do not include common words, adjectives, or verbs — only proper person names.
    
    # Examples:
    # "مرحبا انا يزيد" -> {"names": ["يزيد"]}
    # "قال محمد وعلي" -> {"names": ["محمد", "علي"]}
    # "انا سعيد اليوم" -> {"names": []}  (سعيد here means happy, not a name)
    # "انا ربى" -> {"names": ["ربى"]}
    # "كيف حالك" -> {"names": []}
    # """
    
    system_prompt = """
    You are an Arabic named entity recognition system specialized in detecting PERSON NAMES ONLY.

    Rules:
    - Extract ONLY human person names (first names, last names, or full names)
    - NEVER extract place names, countries, or cities (الاردن, عمان, فلسطين, etc.)
    - NEVER extract words that could be verbs or adjectives (سعيد, يزيد, رامي could be verb/adj — only include if clearly used as a name)
    - Use context to decide: "انا يزيد" → يزيد is a name. "الماء يزيد" → يزيد is a verb.
    - Return each name in its original form as it appears in the text

    Return ONLY a JSON object: {"names": [...]}
    If no person names found, return {"names": []}

    Examples:
    "مرحبا انا يزيد" -> {"names": ["يزيد"]}  (يزيد follows انا = name)
    "الانتاج يزيد كل يوم" -> {"names": []}  (يزيد is a verb here)
    "انا سعيد اليوم" -> {"names": []}  (سعيد = happy, adjective)
    "قال محمد وعلي" -> {"names": ["محمد", "علي"]}
    "انا ربى من الاردن" -> {"names": ["ربى"]}  (الاردن is a country, not a person)
    "انا ايهم من عمان" -> {"names": ["ايهم"]}  (عمان is a city, not a person)
    "كيف حالك" -> {"names": []}
    "لعب سامي" -> {"names": ["سامي"]}    
    "اسمي راما" -> {"names": ["راما"]}
    """
    try:
        data = call_llm_for_json(system_prompt, f"Text: {text}")
        return data.get("names", [])
    except Exception:
        return []