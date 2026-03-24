"""
standalone_connection_test.py
Demonstrates a connection to the database
This script is not part of university_app.
"""

import os

import psycopg
from dotenv import load_dotenv

load_dotenv()

conn_str = (
    f"host={os.getenv('DB_HOST', 'localhost')} "
    f"port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('DB_NAME', '')} "
    f"user={os.getenv('DB_USER', '')} "
    f"password={os.getenv('DB_PASSWORD', '')}"
)

with psycopg.connect(conn_str) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT version()")
        row = cur.fetchone()
        if row is not None:
            print("Version:", row[0])