"""
university_app/config/database.py
Responsibilities: connection string, pool creation, pool teardown.
Rules: no SQL queries, no business logic.
"""

import os

import psycopg_pool
from dotenv import load_dotenv

load_dotenv()


class DatabaseConfig:
    _pool: psycopg_pool.ConnectionPool | None = None

    @classmethod
    def _conninfo(cls) -> str:
        return (
            f"host={os.getenv('DB_HOST', 'localhost')} "
            f"port={os.getenv('DB_PORT', '5432')} "
            f"dbname={os.getenv('DB_NAME')} "
            f"user={os.getenv('DB_USER')} "
            f"password={os.getenv('DB_PASSWORD')}"
        )

    @classmethod
    def initialize(cls) -> None:
        """Open the pool. Call once at application startup in main.py."""
        cls._pool = psycopg_pool.ConnectionPool(
            conninfo=cls._conninfo(),
            min_size=2,
            max_size=10,
            open=True,
        )

    @classmethod
    def get_connection(cls):
        """
        Borrow a connection from the pool.
        Usage:
            with DatabaseConfig.get_connection() as conn:
                ...
        The pool reclaims the connection when the with block exits.
        """
        if cls._pool is None:
            cls.initialize()
        return cls._pool.connection()

    @classmethod
    def close(cls) -> None:
        """Shut down the pool. Call once at application exit in main.py."""
        if cls._pool is not None:
            cls._pool.close()
            cls._pool = None
