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
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from app.core.security import SECRET_KEY, ALGORITHM
from app.services import bookmarks as bookmark_service
import re

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return username
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

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


@app.post("/process")
def process_endpoint(request: ProcessRequest, db: Session = Depends(get_db)):
    print("=" * 40)
    print(f" Received Request from App: {request.text}")
    
    clean_input = re.sub(r'[a-zA-Z]', '', request.text).strip()
    if not clean_input: raise HTTPException(status_code=400, detail="Arabic text required")

    mode = request.force_mode
    
    # 3. If no order was given (Home Screen), ask the AI Classifier
    if not mode:
        router_res = run_router_model(request.text)
        mode = router_res.route
        print(f"Intent Detected by the model: {mode}")
    else:
        print(f" Forced Mode Triggered: {mode}")

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
 
@app.post("/bookmarks")
def add_bookmark(word: str, db: Session = Depends(get_db), username: str = Depends(get_current_user)):
    return bookmark_service.add_bookmark(username, word, db)

@app.delete("/bookmarks")
def remove_bookmark(word: str, db: Session = Depends(get_db), username: str = Depends(get_current_user)):
    return bookmark_service.remove_bookmark(username, word, db)

@app.get("/bookmarks")
def get_bookmarks(db: Session = Depends(get_db), username: str = Depends(get_current_user)):
    return bookmark_service.get_bookmarks(username, db)

@app.get("/topics")
def get_topics(db: Session = Depends(get_db)):
    topics = db.query(Sign.topic).filter(Sign.topic.isnot(None)).distinct().all()
    topic_list = [t[0] for t in topics if t[0]]
    return {"topics": topic_list}
