from datetime import datetime
from typing import List, Optional, Any
from pydantic import BaseModel, EmailStr
from app.models.all_models import UserRole, QuestionType, AttemptStatus

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: int
    role: str
    username: str

class UserBase(BaseModel):
    email: EmailStr
    username: str
    full_name: str

class UserCreate(UserBase):
    password: str
    role: Optional[UserRole] = UserRole.STUDENT

class UserOut(UserBase):
    id: int
    role: UserRole
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class LoginRequest(BaseModel):
    username: str
    password: str

class GroupBase(BaseModel):
    name: str
    description: Optional[str] = None

class GroupCreate(GroupBase):
    pass

class GroupOut(GroupBase):
    id: int
    created_at: datetime
    class Config:
        from_attributes = True

class QuestionOption(BaseModel):
    identifier: str
    text: str

class QuestionBase(BaseModel):
    topic_id: int
    question_statement: str
    question_type: QuestionType
    exam_year: Optional[int] = None
    marks: float = 1.0
    negative_marks: float = 0.33
    options: Optional[List[QuestionOption]] = None
    correct_answer: str
    explanation: Optional[str] = None
    youtube_url: Optional[str] = None
    difficulty: Optional[str] = "Medium"

class QuestionCreate(QuestionBase):
    pass

class QuestionOut(QuestionBase):
    id: int
    class Config:
        from_attributes = True

class ExamQuestionView(BaseModel):
    id: int
    topic_id: int
    question_statement: str
    question_type: QuestionType
    exam_year: Optional[int] = None
    marks: float
    negative_marks: float
    options: Optional[List[Any]] = None
    class Config:
        from_attributes = True

class ResponseSave(BaseModel):
    question_id: int
    selected_answer: Optional[str] = None
    is_tukka: bool = False
    is_marked_for_review: bool = False
    is_answered: bool = False
    time_spent_seconds: int = 0

class ExaminationEventCreate(BaseModel):
    event_type: str
    details: Optional[str] = None

class SolutionViewOut(BaseModel):
    question_id: int
    correct_answer: str
    explanation: Optional[str]
    youtube_url: Optional[str]
    locked_until: datetime
