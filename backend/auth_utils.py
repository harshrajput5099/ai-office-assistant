# Security helpers: bcrypt hashing + JWT tokens

from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from fastapi import HTTPException, Header
from typing import Optional
import secrets

# ── Config ────────────────────────────────────────────────────
SECRET_KEY = 'CHANGE_THIS_TO_A_LONG_RANDOM_STRING_IN_PRODUCTION'
ALGORITHM  = 'HS256'
TOKEN_EXPIRE_DAYS = 30   # user stays logged in for 30 days

pwd_ctx = CryptContext(schemes=['bcrypt'], deprecated='auto')

# ── Password helpers ──────────────────────────────────────────
def hash_password(plain: str) -> str:
    return pwd_ctx.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_ctx.verify(plain, hashed)

# ── Recovery key helpers ──────────────────────────────────────
def generate_recovery_key() -> str:
    """Generates a secure random recovery key shown once to user."""
    return secrets.token_urlsafe(16)   # e.g. 'xK9_mT2pR...' (22 chars)

# ── JWT helpers ───────────────────────────────────────────────
def create_token(user_id: int, username: str) -> str:
    expire = datetime.utcnow() + timedelta(days=TOKEN_EXPIRE_DAYS)
    payload = {'sub': str(user_id), 'username': username, 'exp': expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> dict:
    """Raises HTTPException 401 if token is invalid or expired."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail='Invalid or expired token')

# ── FastAPI dependency: get current user from header ──────────
def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    """
    Use as a FastAPI dependency: get_current_user = Depends(get_current_user)
    Extracts user from Authorization: Bearer <token> header.
    """
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Missing token')
    token = authorization.split(' ', 1)[1]
    return decode_token(token)   # returns {'sub': user_id, 'username': ...}
