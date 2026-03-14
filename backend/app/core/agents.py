import os
import json
from openai import OpenAI
from dotenv import load_dotenv
from fastapi import HTTPException
from app.schemas import RouterResult, IntentResult, TopicResult, VocabResult
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForSequenceClassification

CLASSIFIER_MODEL_NAME = "your-username/your-intent-classifier"
try:
    cls_tokenizer = AutoTokenizer.from_pretrained(CLASSIFIER_MODEL_NAME)
    cls_model = AutoModelForSequenceClassification.from_pretrained(CLASSIFIER_MODEL_NAME)
    print("Intent Classifier Loaded.")
except Exception as e:
    print(f"Error loading classifier: {e}")
    raise e

load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
MODEL_NAME = "gpt-4o-mini"

def call_llm_for_json(system_prompt: str, user_prompt: str, temperature: float = 0.2) -> dict:
    try:
        response = client.chat.completions.create(
            model=MODEL_NAME,
            temperature=temperature,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        )
        
        content = response.choices[0].message.content.strip()
        
        if content.startswith("```"):
            content = content.strip("`")
            if content.lower().startswith("json"):
                content = content[4:].strip()
                
        return json.loads(content)
        
    except Exception as e:
        print(f"LLM Error: {e}") # Log the error
        # In a real app, you might want to return a default/fallback object instead of crashing
        raise HTTPException(status_code=500, detail="Error processing AI request")

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
    Extract the MAIN topic (e.g., hospital, family) in 1-2 words lowercase.
    Return JSON: {"topic": "...", "other_possible_topics": [...], "reason": "..."}
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