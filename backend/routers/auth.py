# Endpoints: /register, /login, /forgot-password, /reset-password

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_db
from auth_utils import (
    hash_password, verify_password,
    generate_recovery_key, create_token
)

router = APIRouter()

# ── Pydantic schemas ──────────────────────────────────────────
class RegisterRequest(BaseModel):
    username: str
    password: str

class LoginRequest(BaseModel):
    username: str
    password: str

class ForgotPasswordRequest(BaseModel):
    username: str
    recovery_key: str
    new_password: str

# ── POST /api/register ────────────────────────────────────────
@router.post('/register')
def register(req: RegisterRequest):
    if len(req.username.strip()) < 3:
        raise HTTPException(400, 'Username must be at least 3 characters')
    if len(req.password) < 6:
        raise HTTPException(400, 'Password must be at least 6 characters')

    recovery_key   = generate_recovery_key()   # shown once to user
    password_hash  = hash_password(req.password)
    recovery_hash  = hash_password(recovery_key)

    conn = get_db()
    try:
        conn.execute(
            'INSERT INTO users (username, password_hash, recovery_hash) VALUES (?,?,?)',
            (req.username.strip(), password_hash, recovery_hash)
        )
        conn.commit()
        user = conn.execute(
            'SELECT id, username FROM users WHERE username=?',
            (req.username.strip(),)
        ).fetchone()
        token = create_token(user['id'], user['username'])
        return {
            'token': token,
            'username': user['username'],
            'recovery_key': recovery_key   # show once — user must save this!
        }
    except Exception as e:
        if 'UNIQUE' in str(e):
            raise HTTPException(400, 'Username already taken')
        raise HTTPException(500, str(e))
    finally:
        conn.close()

# ── POST /api/login ───────────────────────────────────────────
@router.post('/login')
def login(req: LoginRequest):
    conn = get_db()
    try:
        user = conn.execute(
            'SELECT * FROM users WHERE username=?',
            (req.username.strip(),)
        ).fetchone()

        if not user or not verify_password(req.password, user['password_hash']):
            raise HTTPException(401, 'Invalid username or password')

        token = create_token(user['id'], user['username'])
        return {
            'token': token,
            'username': user['username'],
            'theme': user['theme']
        }
    finally:
        conn.close()

# ── POST /api/forgot-password ─────────────────────────────────
# Verifies recovery key + sets new password in one step
@router.post('/forgot-password')
def forgot_password(req: ForgotPasswordRequest):
    if len(req.new_password) < 6:
        raise HTTPException(400, 'New password must be at least 6 characters')

    conn = get_db()
    try:
        user = conn.execute(
            'SELECT * FROM users WHERE username=?',
            (req.username.strip(),)
        ).fetchone()

        if not user:
            raise HTTPException(404, 'Username not found')
        if not verify_password(req.recovery_key, user['recovery_hash']):
            raise HTTPException(401, 'Invalid recovery key')

        new_hash = hash_password(req.new_password)
        conn.execute(
            'UPDATE users SET password_hash=? WHERE id=?',
            (new_hash, user['id'])
        )
        conn.commit()
        token = create_token(user['id'], user['username'])
        return {'token': token, 'username': user['username'], 'message': 'Password reset successful'}
    finally:
        conn.close()
