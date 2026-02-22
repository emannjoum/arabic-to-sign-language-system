from pydantic import BaseModel
from typing import List, Literal, Optional
from pydantic import BaseModel, Field

class UserMessage(BaseModel):
    text: str

class RouterResult(BaseModel):
    route: Literal["translation", "teaching"]
    confidence: float
    reason: str

class IntentResult(BaseModel):
    mode: Literal["translation", "teaching", "other"]
    intent: str
    extracted_text: str
    reason: str

class TopicResult(BaseModel):
    topic: str
    other_possible_topics: List[str]
    reason: str

class VocabResult(BaseModel):
    topic: str
    words: List[str]

#Composite Models (for API responses)
class AnalysisResult(BaseModel):
    router: RouterResult
    intent: IntentResult
    topic: TopicResult
    vocabulary: VocabResult

class UserCreate(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class SkeletonFrame(BaseModel):
    skeleton_url: str
    label: str
    delay_ms: int = 0

class ResponsePayload(BaseModel):
    mode: str
    data: List[SkeletonFrame]

class UserMessage(BaseModel):
    # Must be at least 1 char, max 500 chars (to save API costs)
    text: str = Field(..., min_length=1, max_length=500)