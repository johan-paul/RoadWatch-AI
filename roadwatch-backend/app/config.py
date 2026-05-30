from pydantic_settings import BaseSettings
from typing import List
from pathlib import Path
import json

# Always resolve .env relative to the project root, not cwd
# Works on Windows, Mac, Linux regardless of where you run uvicorn from
_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


class Settings(BaseSettings):
    # App
    APP_NAME: str = "RoadWatch AI"
    APP_ENV: str = "development"
    BACKEND_CORS_ORIGINS: str = '["http://localhost:3000"]'

    # Database
    DATABASE_URL: str

    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"

    # JWT
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Storage buckets
    STORAGE_BUCKET_COMPLAINTS: str = "complaint-images"
    STORAGE_BUCKET_REPAIRS: str = "repair-images"
    STORAGE_BUCKET_AVATARS: str = "avatars"

    # Admin web dashboard
    ADMIN_SECRET: str = "change-this-admin-secret-min-16-chars"

    # OTP / rate limiting
    OTP_EXPIRE_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 3
    OTP_MAX_REQUESTS_PER_HOUR: int = 5
    OTP_LOCKOUT_MINUTES: int = 15

    # Complaint limits
    MAX_COMPLAINTS_PER_CITIZEN_PER_DAY: int = 5
    MIN_TRUST_SCORE_FOR_ACTIVE: int = 20

    # AI model
    AI_MODEL_PATH: str = "models/road_damage.keras"
    AI_CONFIDENCE_THRESHOLD: float = 0.40   # Below this → damage_type="other"

    @property
    def cors_origins(self) -> List[str]:
        return json.loads(self.BACKEND_CORS_ORIGINS)

    model_config = {
        "env_file": str(_ENV_FILE),
        "env_file_encoding": "utf-8",
        "case_sensitive": True,
    }


settings = Settings()
