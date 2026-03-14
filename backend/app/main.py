from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.schemas import UserMessage, ResponsePayload
from app.core.agents import run_router_model
from app.services import translation, teaching
from app.schemas import UserCreate, UserLogin, Token
from app.services import auth

app = FastAPI(title="Sign Language Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev, allow everyone. In production, specify ["http://localhost:3000"]
    allow_credentials=True,
    allow_methods=["*"],  # Allow POST, GET, etc.
    allow_headers=["*"],  # Allow all headers
)

@app.post("/process", response_model=ResponsePayload)
def process_request(payload: UserMessage, db: Session = Depends(get_db)):
    """
     1. Receives text.
     2. Uses LLM to decide: Translation or Teaching?
     3. Runs the specific pipeline for that mode.
     4. Returns a list of Skeletons (URLs) to the mobile app.
    """
    print(f"\n{'='*40}")
    print(f" Received Request from App: {payload.text}")
    
    router_res = run_router_model(payload.text)
    print(f" AI Intent Detected: {router_res.route}")

    final_data = []

    if router_res.route == "translation": final_data = translation.process_translation(payload.text, db)
        
    elif router_res.route == "teaching": final_data = teaching.process_teaching(payload.text, db)
        
    else: # Fallback for "other" (small talk, etc.)
         # For now, return empty
        final_data = []
        print(" No Database Action (General Conversation)")

    return ResponsePayload(
         mode=router_res.route,
         data=final_data
    )

@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    return auth.register_user(user, db)

@app.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
     return auth.login_user(user, db)
