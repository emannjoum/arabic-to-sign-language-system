from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.db.models import Bookmark, Sign, User


def add_bookmark(username: str, word: str, db: Session):
    # Find the user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Find the sign by word
    sign = db.query(Sign).filter(Sign.word == word).first()
    if not sign:
        raise HTTPException(status_code=404, detail=f"Sign '{word}' not found in database")

    # Check if already bookmarked
    existing = db.query(Bookmark).filter(
        Bookmark.user_id == user.id,
        Bookmark.sign_id == sign.id
    ).first()
    if existing:
        return {"message": "Already bookmarked"}

    # Save bookmark
    bookmark = Bookmark(user_id=user.id, sign_id=sign.id)
    db.add(bookmark)
    db.commit()
    return {"message": "Bookmarked successfully"}


def remove_bookmark(username: str, word: str, db: Session):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    sign = db.query(Sign).filter(Sign.word == word).first()
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