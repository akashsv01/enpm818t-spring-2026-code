import os

import psycopg
import psycopg_pool
from dotenv import load_dotenv

load_dotenv()


class DatabaseConfig:
    _pool = None

    @classmethod
    def _conninfo(cls):
        """Build a libpq connection string from environment variables."""
        return (
            f"host={os.getenv('DB_HOST', 'localhost')} "
            f"port={os.getenv('DB_PORT', '5432')} "
            f"dbname={os.getenv('DB_NAME', 'university_db')} "
            f"user={os.getenv('DB_USER', 'postgres')} "
            f"password={os.getenv('DB_PASSWORD', '')}"
        )

    @classmethod
    def initialize(cls):
        """Create the connection pool. Call once at application startup."""
        try:
            cls._pool = psycopg_pool.ConnectionPool(
                conninfo=cls._conninfo(),
                min_size=2,
                max_size=10,
                open=True,
            )
        except psycopg.OperationalError as e:
            print("Error: Cannot connect to database. Check .env settings.")
            print(f"Details: {e}")
            raise SystemExit(1)

    @classmethod
    def get_connection(cls):
        """
        Borrow a connection from the pool.

        Usage:
            with DatabaseConfig.get_connection() as conn:
                with conn.cursor(row_factory=dict_row) as cur:
                    cur.execute("SELECT ...")
        """
        if cls._pool is None:
            cls.initialize()
        return cls._pool.connection()

    @classmethod
    def close(cls):
        """Close all connections. Call at application shutdown."""
        if cls._pool is not None:
            cls._pool.close()
            cls._pool = None
