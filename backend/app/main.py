from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas import UserMessage, ResponsePayload
from app.core.agents import run_router_model
from app.services import translation, teaching
from app.schemas import UserCreate, UserLogin, Token
from app.services import auth
from pydantic import BaseModel
from typing import Optional, List
from app.db.models import Sign

app = FastAPI(title="Sign Language Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev, allow everyone. In production, specify ["http://localhost:3000"]
    allow_credentials=True,
    allow_methods=["*"],  # Allow POST, GET, etc.
    allow_headers=["*"],  # Allow all headers
)

class ProcessRequest(BaseModel):
    text: str
    force_mode: Optional[str] = None  # This is the magic key!

TOPIC_DICTIONARY = {
    "Family": "العائلة",
    "Home": "المنزل",
    "Time": "الوقت",
    "Countries": "الدول",
    "Colors": "الألوان",
    "Numbers": "الأرقام",
    "Greetings": "التحيات"
}

@app.get("/topics")
def get_unique_topics(db: Session = Depends(get_db)):
    # Query the English topics from the DB
    unique_topics = db.query(Sign.topic).filter(Sign.topic != None).distinct().all()
    english_topics = [t[0].strip() for t in unique_topics if t[0].strip()]
    
    # Translate them to Arabic before sending to Flutter!
    # (If a topic isn't in the dictionary, it just returns the original English word)
    arabic_topics = [TOPIC_DICTIONARY.get(t, t) for t in english_topics]
    
    return {"topics": arabic_topics}

@app.post("/process")
def process_endpoint(request: ProcessRequest, db: Session = Depends(get_db)):
    print("=" * 40)
    print(f" Received Request from App: {request.text}")
    
    # 2. Check if the frontend gave us a direct order
    mode = request.force_mode
    
    # 3. If no order was given (Home Screen), ask the AI Classifier
    if not mode:
        router_res = run_router_model(request.text)
        mode = router_res.route
        print(f" AI Intent Detected: {mode}")
    else:
        print(f" Forced Mode Triggered: {mode}")

    # 4. Route to the exact pipeline
    try:
        if mode == "translation":
            response_data = translation.process_translation(request.text, db)
        elif mode == "teaching":
            response_data = teaching.process_teaching(request.text, db)
        else:
            response_data = []
            
        return {"mode": mode, "data": response_data}
        
    except Exception as e:
        print(f"Pipeline Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    return auth.register_user(user, db)

@app.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
     return auth.login_user(user, db)
