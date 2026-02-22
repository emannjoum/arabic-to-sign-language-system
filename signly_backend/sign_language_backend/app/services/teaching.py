from sqlalchemy.orm import Session
from app.core.agents import run_topic_agent, run_vocab_agent
from app.db.models import Sign
from app.schemas import SkeletonFrame

def process_teaching(user_text: str, db: Session):
    topic_res = run_topic_agent(user_text)
    vocab_res = run_vocab_agent(user_text, topic_res.topic)
    all_target_words = vocab_res.words
    
    response_data = []
    signs = db.query(Sign).filter(Sign.word.in_(all_target_words)).all()
    for sign in signs:
        response_data.append(SkeletonFrame(
            skeleton_url=sign.skeleton_url,
            label=sign.word,
            delay_ms=2000 # Teaching mode needs a delay between signs
        ))
        
    return response_data