import sys
import os

# Add the university_app directory to the path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config.database import DatabaseConfig
from cli.menu import main


if __name__ == "__main__":
    DatabaseConfig.initialize()
    try:
        main()
    finally:
        DatabaseConfig.close()
