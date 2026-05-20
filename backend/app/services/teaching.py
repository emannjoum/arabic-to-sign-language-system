from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.agents import run_topic_agent
from app.db.models import Sign
from app.schemas import SkeletonFrame

def process_teaching(user_text: str, db: Session):
    topic_result = run_topic_agent(user_text)
    topic_string = topic_result.topic
    if not topic_string: topic_string = "متفرقات"
    print(f"Extracted Topic: {topic_string}")
    signs = db.query(Sign).filter(Sign.topic.ilike(f"%{topic_string}%")).all()

    response_data = []
    for sign in signs:
        response_data.append(SkeletonFrame(
            skeleton_url=sign.skeleton_url,
            label=sign.word,  
            delay_ms=2000 
        ))
        
    return response_data