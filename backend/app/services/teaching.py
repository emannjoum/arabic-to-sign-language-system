from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.agents import run_topic_agent
from app.db.models import Sign
from app.schemas import SkeletonFrame

# 1. The Reverse Map! (Arabic to English)
REVERSE_TOPIC_MAP = {
    "العائلة": "Family",
    "المنزل": "Home",
    "الوقت": "Time",
    "الدول": "Countries",
    "الألوان": "Colors",
    "الأرقام": "Numbers",
    "التحيات": "Greetings"
}

def process_teaching(user_text: str, db: Session):
    clean_text = user_text.strip()
    
    # 2. Map the Arabic UI click back to the English DB column
    db_topic = REVERSE_TOPIC_MAP.get(clean_text, clean_text)
    
    print(f"Searching DB for Topic: '{db_topic}'")
    
    # 3. Check for exact category match
    signs = db.query(Sign).filter(Sign.topic.ilike(f"%{db_topic}%")).all()
    
    # 4. If no exact match, ask AI to extract the topic from the sentence
    if not signs:
        print(f"No direct topic match. Asking AI to extract topic...")
        topic_res = run_topic_agent(user_text)
        
        # The AI will likely output an Arabic word, so map it to English!
        target_topic = REVERSE_TOPIC_MAP.get(topic_res.topic, topic_res.topic)
        print(f"AI Extracted Topic (Mapped to DB): {target_topic}")
        
        signs = db.query(Sign).filter(Sign.topic.ilike(f"%{target_topic}%")).all()

    response_data = []
    for sign in signs:
        response_data.append(SkeletonFrame(
            skeleton_url=sign.skeleton_url,
            label=sign.word,  
            delay_ms=2000 
        ))
        
    return response_data