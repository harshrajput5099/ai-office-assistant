# GET /api/history, POST /api/history, DELETE /api/history/{id}
# All routes require JWT token

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from database import get_db
from auth_utils import get_current_user

router = APIRouter()

class HistoryCreate(BaseModel):
    type: str      # 'summary' | 'meeting' | 'email'
    title: str
    content: str

# ── GET /api/history ──────────────────────────────────────────
# Returns all history items for the logged-in user, newest first
@router.get('/history')
def get_history(current_user: dict = Depends(get_current_user)):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        rows = conn.execute(
            'SELECT * FROM history WHERE user_id=? ORDER BY timestamp DESC',
            (user_id,)
        ).fetchall()
        return [dict(row) for row in rows]
    finally:
        conn.close()

# ── POST /api/history ─────────────────────────────────────────
# Called automatically after every summarization/email/meeting
@router.post('/history')
def add_history(
    item: HistoryCreate,
    current_user: dict = Depends(get_current_user)
):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        cursor = conn.execute(
            'INSERT INTO history (user_id, type, title, content) VALUES (?,?,?,?)',
            (user_id, item.type, item.title, item.content)
        )
        conn.commit()
        row = conn.execute(
            'SELECT * FROM history WHERE id=?', (cursor.lastrowid,)
        ).fetchone()
        return dict(row)
    finally:
        conn.close()

# ── DELETE /api/history/{id} ───────────────────────────────────
# Only deletes if the item belongs to the current user
@router.delete('/history/{item_id}')
def delete_history(
    item_id: int,
    current_user: dict = Depends(get_current_user)
):
    user_id = int(current_user['sub'])
    conn = get_db()
    try:
        result = conn.execute(
            'DELETE FROM history WHERE id=? AND user_id=?',
            (item_id, user_id)
        )
        conn.commit()
        if result.rowcount == 0:
            raise HTTPException(404, 'History item not found')
        return {'deleted': True}
    finally:
        conn.close()
