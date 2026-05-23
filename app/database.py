import sqlite3
import hashlib
import bcrypt
from datetime import datetime, timezone
import os
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

DB_NAME = os.getenv("DB_NAME", os.path.join(BASE_DIR, "psychbot.db"))
DATABASE_URL = os.getenv("DATABASE_URL", "")

IS_POSTGRES = DATABASE_URL.startswith("postgres://") or DATABASE_URL.startswith("postgresql://")

def get_connection():
    if IS_POSTGRES:
        import psycopg2
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    else:
        conn = sqlite3.connect(DB_NAME)
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA busy_timeout = 5000")
        return conn

def _execute_query(cursor, query, params=()):
    if IS_POSTGRES:
        query = query.replace("?", "%s")
    cursor.execute(query, params)

def _insert_query(cursor, query, params=()):
    if IS_POSTGRES:
        query = query.replace("?", "%s")
        if "RETURNING" not in query.upper():
            query += " RETURNING id"
        cursor.execute(query, params)
        return cursor.fetchone()[0]
    else:
        cursor.execute(query, params)
        return cursor.lastrowid

# --- 1. VERİTABANI KURULUMU ---
def init_db():
    conn = get_connection()
    c = conn.cursor()
    
    if IS_POSTGRES:
        # Kullanıcılar Tablosu (PostgreSQL Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS users
                     (id SERIAL PRIMARY KEY, 
                      username TEXT UNIQUE, 
                      password_hash TEXT,
                      display_name TEXT,
                      age INTEGER,
                      gender TEXT,
                      profession TEXT,
                      city TEXT, 
                      marital_status TEXT,
                      child_count INTEGER DEFAULT 0,
                      chronic_illness TEXT,
                      trauma_summary TEXT,
                      avatar TEXT,
                      created_at TIMESTAMP)''')
        
        # Sohbet Oturumları (PostgreSQL Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS sessions
                     (id SERIAL PRIMARY KEY, 
                      user_id INTEGER, 
                      title TEXT, 
                      is_voice_session BOOLEAN DEFAULT FALSE,
                      created_at TIMESTAMP,
                      FOREIGN KEY(user_id) REFERENCES users(id))''')
        
        # Mesajlar ve Chats Tablosu (PostgreSQL Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS messages
                     (id SERIAL PRIMARY KEY, 
                      session_id INTEGER, 
                      role TEXT, 
                      content TEXT, 
                      audio_url TEXT NULL, 
                      created_at TIMESTAMP,
                      FOREIGN KEY(session_id) REFERENCES sessions(id))''')

        # Yenileme Tokenleri (PostgreSQL Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS refresh_tokens
                     (id SERIAL PRIMARY KEY,
                      user_id INTEGER NOT NULL,
                      token_hash TEXT NOT NULL UNIQUE,
                      expires_at TEXT NOT NULL,
                      revoked_at TEXT NULL,
                      created_at TEXT NOT NULL,
                      FOREIGN KEY(user_id) REFERENCES users(id))''')
    else:
        # Kullanıcılar Tablosu (SQLite Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS users
                     (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                      username TEXT UNIQUE, 
                      password_hash TEXT,
                      display_name TEXT,
                      age INTEGER,
                      gender TEXT,
                      profession TEXT,
                      city TEXT, 
                      marital_status TEXT,
                      child_count INTEGER DEFAULT 0,
                      chronic_illness TEXT,
                      trauma_summary TEXT,
                      avatar TEXT,
                      created_at TIMESTAMP)''')
        
        # Sohbet Oturumları (SQLite Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS sessions
                     (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                      user_id INTEGER, 
                      title TEXT, 
                      is_voice_session BOOLEAN DEFAULT 0,
                      created_at TIMESTAMP,
                      FOREIGN KEY(user_id) REFERENCES users(id))''')
        
        # Mesajlar ve Chats Tablosu (SQLite Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS messages
                     (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                      session_id INTEGER, 
                      role TEXT, 
                      content TEXT, 
                      audio_url TEXT NULL, 
                      created_at TIMESTAMP,
                      FOREIGN KEY(session_id) REFERENCES sessions(id))''')

        # Yenileme Tokenleri (SQLite Uyumlu)
        c.execute('''CREATE TABLE IF NOT EXISTS refresh_tokens
                     (id INTEGER PRIMARY KEY AUTOINCREMENT,
                      user_id INTEGER NOT NULL,
                      token_hash TEXT NOT NULL UNIQUE,
                      expires_at TEXT NOT NULL,
                      revoked_at TEXT NULL,
                      created_at TEXT NOT NULL,
                      FOREIGN KEY(user_id) REFERENCES users(id))''')

    c.execute("CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_messages_session_created_at ON messages(session_id, created_at)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id)")
    
    conn.commit()
    conn.close()

# --- 2. KULLANICI İŞLEMLERİ ---
def hash_password(password):
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def _legacy_sha256(password):
    return hashlib.sha256(password.encode()).hexdigest()

def _is_legacy_hash(stored_hash):
    if not stored_hash:
        return False
    return len(stored_hash) == 64 and all(c in "0123456789abcdef" for c in stored_hash.lower())

def verify_password(password, stored_hash):
    if not stored_hash:
        return False

    if _is_legacy_hash(stored_hash):
        return _legacy_sha256(password) == stored_hash

    try:
        return bcrypt.checkpw(password.encode("utf-8"), stored_hash.encode("utf-8"))
    except ValueError:
        return False

def register_user(username, password, display_name, age, gender, profession="", city="", marital_status="Belirtilmedi", child_count=0, chronic_illness="", trauma_summary=""):
    conn = get_connection()
    c = conn.cursor()
    try:
        user_id = _insert_query(c, """INSERT INTO users 
                     (username, password_hash, display_name, age, gender, profession, city, marital_status, child_count, chronic_illness, trauma_summary, avatar, created_at) 
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", 
                 (username, hash_password(password), display_name, age, gender, profession, city, marital_status, child_count, chronic_illness, trauma_summary, 'default', datetime.now()))
        conn.commit()
        return get_user_by_id(user_id)
    except Exception:
        return None
    finally:
        conn.close()

def create_google_user(username, display_name):
    conn = get_connection()
    c = conn.cursor()
    try:
        user_id = _insert_query(c,
            """INSERT INTO users
               (username, password_hash, display_name, age, gender, profession, city, marital_status, child_count, chronic_illness, trauma_summary, avatar, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                username,
                "",
                display_name,
                0,
                "Belirtilmedi",
                "",
                "",
                "Belirtilmedi",
                0,
                "",
                "",
                "default",
                datetime.now(timezone.utc).isoformat(),
            ),
        )
        conn.commit()
        return get_user_by_id(user_id)
    except Exception:
        return get_user_by_username(username)
    finally:
        conn.close()

def login_user(username, password):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT * FROM users WHERE username=?", (username,))
    row = c.fetchone()

    if not row:
        conn.close()
        return None

    stored_hash = row[2]
    is_valid = verify_password(password, stored_hash)
    if not is_valid:
        conn.close()
        return None

    # Geçmiş SHA256 kullanıcılarını başarılı login sırasında bcrypt'e geçir.
    if _is_legacy_hash(stored_hash):
        new_hash = hash_password(password)
        _execute_query(c, "UPDATE users SET password_hash=? WHERE id=?", (new_hash, row[0]))
        conn.commit()

    conn.close()
    return _format_user(row)

def get_user_by_id(user_id):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT * FROM users WHERE id=?", (user_id,))
    row = c.fetchone()
    conn.close()
    if row:
        return _format_user(row)
    return None

def get_user_by_username(username):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT * FROM users WHERE username=?", (username,))
    row = c.fetchone()
    conn.close()
    if row:
        return _format_user(row)
    return None

def update_profile(user_id, display_name, age, gender, profession, city, marital_status, child_count, chronic_illness, trauma_summary, avatar="default"):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, """UPDATE users SET 
                 display_name=?, age=?, gender=?, profession=?, city=?, marital_status=?, child_count=?, chronic_illness=?, trauma_summary=?, avatar=? 
                 WHERE id=?""", 
              (display_name, age, gender, profession, city, marital_status, child_count, chronic_illness, trauma_summary, avatar, user_id))
    conn.commit()
    conn.close()
    
    return get_user_by_id(user_id)

def _format_user(row):
    return {
        "id": row[0],
        "username": row[1],
        "display_name": row[3],
        "age": row[4],
        "gender": row[5],
        "profession": row[6],
        "city": row[7],
        "marital_status": row[8],
        "child_count": row[9],
        "chronic_illness": row[10],
        "trauma_summary": row[11],
        "avatar": row[12],
        "created_at": row[13]
    }

# --- 3. SOHBET (CHATS) İŞLEMLERİ ---
def create_session(user_id, title="Yeni Sohbet", is_voice_session=False):
    conn = get_connection()
    c = conn.cursor()
    session_id = _insert_query(c, "INSERT INTO sessions (user_id, title, is_voice_session, created_at) VALUES (?, ?, ?, ?)", 
              (user_id, title, is_voice_session, datetime.now()))
    conn.commit()
    conn.close()
    return session_id

def get_user_sessions(user_id):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT id, title, is_voice_session, created_at FROM sessions WHERE user_id=? ORDER BY created_at DESC", (user_id,))
    sessions = [{"id": row[0], "title": row[1], "is_voice_session": row[2], "created_at": row[3]} for row in c.fetchall()]
    conn.close()
    return sessions

def delete_session(session_id):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "DELETE FROM messages WHERE session_id=?", (session_id,))
    _execute_query(c, "DELETE FROM sessions WHERE id=?", (session_id,))
    deleted = c.rowcount > 0
    conn.commit()
    conn.close()
    return deleted

def save_message(session_id, role, content, audio_url=None):
    conn = get_connection()
    c = conn.cursor()
    message_id = _insert_query(c, "INSERT INTO messages (session_id, role, content, audio_url, created_at) VALUES (?, ?, ?, ?, ?)", 
              (session_id, role, content, audio_url, datetime.now()))
    conn.commit()
    conn.close()
    return message_id

def get_session_messages(session_id):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT id, role, content, audio_url, created_at FROM messages WHERE session_id=? ORDER BY created_at ASC", (session_id,))
    messages = [{"id": row[0], "role": row[1], "content": row[2], "audio_url": row[3], "created_at": row[4]} for row in c.fetchall()]
    conn.close()
    return messages

def get_session_owner(session_id):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c, "SELECT user_id FROM sessions WHERE id=?", (session_id,))
    row = c.fetchone()
    conn.close()
    if not row:
        return None
    return row[0]

def _hash_refresh_token(token):
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

def store_refresh_token(user_id, refresh_token, expires_at):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c,
        """INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_at)
           VALUES (?, ?, ?, ?)""",
        (
            user_id,
            _hash_refresh_token(refresh_token),
            expires_at.astimezone(timezone.utc).isoformat(),
            datetime.now(timezone.utc).isoformat(),
        ),
    )
    conn.commit()
    conn.close()

def validate_refresh_token(refresh_token):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c,
        """SELECT user_id, expires_at, revoked_at
           FROM refresh_tokens
           WHERE token_hash=?""",
        (_hash_refresh_token(refresh_token),),
    )
    row = c.fetchone()
    conn.close()
    if not row:
        return None

    user_id, expires_at_text, revoked_at = row
    if revoked_at is not None:
        return None

    try:
        expires_at = datetime.fromisoformat(expires_at_text)
    except ValueError:
        return None

    if datetime.now(timezone.utc) >= expires_at:
        return None

    return get_user_by_id(user_id)

def revoke_refresh_token(refresh_token):
    conn = get_connection()
    c = conn.cursor()
    _execute_query(c,
        """UPDATE refresh_tokens
           SET revoked_at=?
           WHERE token_hash=? AND revoked_at IS NULL""",
        (datetime.now(timezone.utc).isoformat(), _hash_refresh_token(refresh_token)),
    )
    conn.commit()
    changed = c.rowcount
    conn.close()
    return changed > 0

# Dosya import edildiğinde ve veritabanı adresi tanımlıysa tabloları oluştur
if IS_POSTGRES or DB_NAME:
    try:
        init_db()
    except Exception as e:
        print(f"Database initialization warning (can be ignored if not fully configured yet): {e}")