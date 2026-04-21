# Creates app.db and all tables. Imported by main.py at startup.

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), 'app.db')

def get_db():
    """Returns a SQLite connection. Use as context manager."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row   # rows behave like dicts
    return conn

def init_db():
    """Called once at server startup — creates tables if they don't exist."""
    conn = get_db()
    cursor = conn.cursor()

    # ── Users table ───────────────────────────────────────────
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            username        TEXT    UNIQUE NOT NULL,
            password_hash   TEXT    NOT NULL,
            recovery_hash   TEXT    NOT NULL,
            theme           TEXT    NOT NULL DEFAULT 'light',
            created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
        )
    ''')

    # ── History table ──────────────────────────────────────────
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS history (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL,
            type        TEXT    NOT NULL,
            title       TEXT    NOT NULL,
            content     TEXT    NOT NULL,
            timestamp   TEXT    NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')

    conn.commit()
    conn.close()
    print('✅ Database initialized — app.db ready')
