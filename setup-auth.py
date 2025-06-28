#!/usr/bin/env python3
"""
Enhanced authentication setup for DeskDev.ai
"""
import os
import json
import sqlite3
from pathlib import Path

def setup_database():
    """Setup user database"""
    db_path = "/opt/deskdev/data/users.db"
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            github_id INTEGER UNIQUE,
            username TEXT NOT NULL,
            email TEXT,
            avatar_url TEXT,
            access_token TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            settings TEXT DEFAULT '{}'
        )
    ''')
    
    # Create sessions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            user_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()
    print("Database setup completed!")

def setup_default_config():
    """Setup default configuration"""
    config = {
        "llm": {
            "provider": "ollama",
            "model": "deepseek-coder:base",
            "base_url": "http://host.docker.internal:11434",
            "api_key": "ollama",
            "temperature": 0.1,
            "max_tokens": 4096
        },
        "app": {
            "name": "DeskDev.ai",
            "description": "AI-Powered Software Development Assistant",
            "landing_page": True,
            "github_auth": True
        },
        "features": {
            "auto_configure_llm": True,
            "show_landing_page": True,
            "require_auth": True
        }
    }
    
    config_path = "/opt/deskdev/data/config.json"
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print("Default configuration created!")

if __name__ == "__main__":
    setup_database()
    setup_default_config()
    print("Authentication setup completed!")