from sqlalchemy.orm import Session
from fastapi import HTTPException
from sqlalchemy import or_, cast, Text
from sqlalchemy.dialects.postgresql import ARRAY
from app.db.models import Bookmark, Sign, User
from app.core.semantic import semantic_engine 


def _resolve_sign(word: str, db: Session):
    """Helper function to find a sign directly, via keywords, or via semantic mapping."""
    
    sign = db.query(Sign).filter(
        or_(
            Sign.word == word,
            Sign.keywords.contains(cast([word], ARRAY(Text)))
        )
    ).first()

    if not sign:
        print(f"[Bookmarks] '{word}' not found directly. Checking semantic mapping...")
        sem_res = semantic_engine.search(word)

        if sem_res and sem_res["type"] == "match":
            mapped_word = sem_res["word"]
            print(f"[Bookmarks] Successfully mapped '{word}' to DB sign '{mapped_word}'")
            sign = db.query(Sign).filter(Sign.word == mapped_word).first()
            
    return sign


def add_bookmark(username: str, word: str, db: Session):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    sign = _resolve_sign(word, db)
    
    if not sign:
        raise HTTPException(status_code=404, detail=f"Sign '{word}' not found in database")

    existing = db.query(Bookmark).filter(
        Bookmark.user_id == user.id,
        Bookmark.sign_id == sign.id
    ).first()
    if existing:
        return {"message": "Already bookmarked"}

    bookmark = Bookmark(user_id=user.id, sign_id=sign.id)
    db.add(bookmark)
    db.commit()
    return {"message": "Bookmarked successfully"}


def remove_bookmark(username: str, word: str, db: Session):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    sign = _resolve_sign(word, db)
    
    if not sign:
        raise HTTPException(status_code=404, detail=f"Sign '{word}' not found")

    bookmark = db.query(Bookmark).filter(
        Bookmark.user_id == user.id,
        Bookmark.sign_id == sign.id
    ).first()
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")

    db.delete(bookmark)
    db.commit()
    return {"message": "Bookmark removed"}


def get_bookmarks(username: str, db: Session):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    bookmarks = db.query(Bookmark).filter(Bookmark.user_id == user.id).all()

    result = []
    for b in bookmarks:
        sign = db.query(Sign).filter(Sign.id == b.sign_id).first()
        if sign:
            result.append({
                "word": sign.word,
                "skeleton_url": sign.skeleton_url,
            })

    return result