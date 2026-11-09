
from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field

CowType = Literal["laitiere", "viande"]
Level = Literal["normal", "alerte", "danger"]


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=60)
    email: EmailStr
    password: str = Field(min_length=8, max_length=100)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class FarmerIn(RegisterIn):
    address: str = Field(default="", max_length=250)


class FarmerUpdate(BaseModel):
    address: str = Field(default="", max_length=250)


class PasswordChangeIn(BaseModel):
    old_password: str
    new_password: str = Field(min_length=8, max_length=100)


class PasswordResetIn(BaseModel):
    new_password: str = Field(min_length=8, max_length=100)


class VetSettingsIn(BaseModel):
    vet_phone: str = Field(max_length=30)


class CowIn(BaseModel):
    tag: str = Field(min_length=4, max_length=16, pattern=r"^[A-Za-z0-9]+$")
    name: str = Field(default="", max_length=40)
    type: CowType
    age_months: Optional[float] = Field(default=None, ge=0, le=400)


class CowUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=40)
    type: Optional[CowType] = None
    age_months: Optional[float] = Field(default=None, ge=0, le=400)
    archived: Optional[bool] = None


class StatusIn(BaseModel):
    status: Optional[Level] = None
    alert: Optional[bool] = None
    p_flagged: Optional[float] = None
    category: Optional[str] = None


class ReportIn(BaseModel):
    reasons: list[str] = Field(min_length=1, max_length=12)
    note: str = Field(default="", max_length=500)


class ReplyIn(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class VetIn(BaseModel):
    called: bool
