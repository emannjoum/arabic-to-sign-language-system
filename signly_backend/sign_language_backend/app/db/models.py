from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import relationship
from app.db.database import Base

#The dictionary table (words -> skeleton)
class Sign(Base):
    __tablename__ = 'dictionary'

    id = Column(Integer, primary_key = True, index = True)
    word = Column(String, unique = True, index = True) #The normalized Arabic word
    skeleton_url = Column(String) #The Supabase Storage URL
    topic = Column(String, index = True)
    bookmarked_by = relationship('Bookmark', back_populates = 'sign') #Relationship: A sign can be bookmarked by many users
    keywords = Column(ARRAY(String), default=[]) #to store keywords/synonyms to help matching

#The user table (login info)
class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key = True, index = True)
    username = Column(String, unique = True, index = True)
    hashed_password = Column(String)
    bookmarks = relationship('Bookmark', back_populates = 'user') #Relationship: A user has many bookmarks

#The bookmark table
class Bookmark(Base):
    __tablename__ = 'bookmarks'

    id= Column(Integer, primary_key = True, index = True)
    user_id = Column(Integer, ForeignKey('users.id'))
    sign_id = Column(Integer, ForeignKey('dictionary.id'))
    user = relationship('User', back_populates = 'bookmarks')
    sign = relationship('Sign', back_populates = 'bookmarked_by')