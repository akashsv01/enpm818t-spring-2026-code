"""
university_app/main.py
Entry point. Responsibilities:
  1. Initialize the connection pool (once at startup).
  2. Start the CLI loop.
  3. Close the pool on exit.
"""

from config.database import DatabaseConfig
from cli import menu


def main() -> None:
    DatabaseConfig.initialize()
    try:
        menu.main()
    finally:
        DatabaseConfig.close()


if __name__ == "__main__":
    main()
