from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.db.models import User
from app.schemas import UserCreate, UserLogin
from app.core.security import get_password_hash, verify_password, create_access_token

def register_user(user: UserCreate, db: Session):
    # 1. Check if username already exists
    existing_user = db.query(User).filter(User.username == user.username).first()
    if existing_user:
        raise HTTPException(
            status_code=400, 
            detail="Username already taken"
        )
    
    # 2. Hash the password
    hashed_pwd = get_password_hash(user.password)
    
    # 3. Create and Save the User
    new_user = User(username=user.username, hashed_password=hashed_pwd)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {"message": "User created successfully", "username": new_user.username}

def login_user(user: UserLogin, db: Session):
    # 1. Find user by username
    db_user = db.query(User).filter(User.username == user.username).first()
    
    # 2. Verify user exists AND password matches
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
        
    # 3. Create Token
    access_token = create_access_token(data={"sub": db_user.username})
    return {"access_token": access_token, "token_type": "bearer"}