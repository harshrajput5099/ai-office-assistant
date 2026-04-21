# GET /api/settings, POST /api/settings
# Also handles: change password, delete account

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from database import get_db
from auth_utils import get_current_user, hash_password, verify_password

router = APIRouter()

class SettingsUpdate(BaseModel):
    theme: Optional[str] = None           # 'light' or 'dark'

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

# ── GET /api/settings ─────────────────────────────────────────
@router.get('/settings')
def get_settings(current_user: dict = Depends(get_current_user)):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        user = conn.execute(
            'SELECT username, theme FROM users WHERE id=?', (user_id,)
        ).fetchone()
        if not user:
            raise HTTPException(404, 'User not found')
        return dict(user)
    finally:
        conn.close()

# ── POST /api/settings ────────────────────────────────────────
# Updates theme (or other settings in future)
@router.post('/settings')
def update_settings(
    req: SettingsUpdate,
    current_user: dict = Depends(get_current_user)
):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        if req.theme:
            conn.execute(
                'UPDATE users SET theme=? WHERE id=?',
                (req.theme, user_id)
            )
            conn.commit()
        return {'updated': True}
    finally:
        conn.close()

# ── POST /api/settings/change-password ────────────────────────
@router.post('/settings/change-password')
def change_password(
    req: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):
    if len(req.new_password) < 6:
        raise HTTPException(400, 'New password must be at least 6 characters')
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        user = conn.execute(
            'SELECT password_hash FROM users WHERE id=?', (user_id,)
        ).fetchone()
        if not verify_password(req.current_password, user['password_hash']):
            raise HTTPException(401, 'Current password is wrong')
        conn.execute(
            'UPDATE users SET password_hash=? WHERE id=?',
            (hash_password(req.new_password), user_id)
        )
        conn.commit()
        return {'changed': True}
    finally:
        conn.close()

# ── DELETE /api/settings/account ──────────────────────────────
@router.delete('/settings/account')
def delete_account(
    current_user: dict = Depends(get_current_user)
):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        conn.execute('DELETE FROM users WHERE id=?', (user_id,))
        conn.commit()
        # history rows auto-deleted by CASCADE
        return {'deleted': True}
    finally:
        conn.close()
