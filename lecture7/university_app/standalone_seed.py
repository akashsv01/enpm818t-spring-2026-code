"""
standalone_seed.py
Demonstrates two bulk-insert methods: executemany() and copy().
Run once against university_db to populate the department table.
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

# ----------------------------------------------------------------
# Method 1: executemany()
# One INSERT per tuple; simple and readable.
# Fine for small batches (under ~100 rows).
# ----------------------------------------------------------------

departments = [
    ("Computer Science",),
    ("Mathematics",),
    ("Mechanical Engineering",),
    ("Electrical Engineering",),
]

with psycopg.connect(conn_str) as conn:
    with conn.transaction():
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO department (dept_name) VALUES (%s)"
                " ON CONFLICT DO NOTHING",
                departments,
            )
            print(f"executemany: {cur.rowcount} rows inserted")

# ----------------------------------------------------------------
# Method 2: copy()
# Streams rows via the PostgreSQL COPY protocol.
# No per-row round trips -- much faster for large datasets.
# Cannot use RETURNING; use executemany() if you need generated PKs.
# ----------------------------------------------------------------

dept_names = [
    "Linguistics",
    "History",
    "Art History",
]

with psycopg.connect(conn_str) as conn:
    with conn.cursor() as cur:
        with cur.copy("COPY department (dept_name) FROM STDIN") as copy:
            for name in dept_names:
                copy.write_row((name,))
    conn.commit()
    print(f"copy: {len(dept_names)} rows streamed")

# ----------------------------------------------------------------
# Verify
# ----------------------------------------------------------------

with psycopg.connect(conn_str) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT dept_id, dept_name FROM department ORDER BY dept_id")
        rows = cur.fetchall()

print("\ndepartment table:")
for dept_id, dept_name in rows:
    print(f"  {dept_id:>3}  {dept_name}")