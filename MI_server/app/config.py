from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    mongo_uri: str
    mongo_db: str = "farm"

    jwt_secret: str
    jwt_days: int = 30

    public_url: str = ""
    subscription_days: int = 30
    invite_hours: int = 24

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_pass: str = ""
    smtp_from: str = ""

    ingest_key: str = ""
    amqp_url: str = ""
    queue_name: str = "test_queue"

    model_path: str = "models/cow_intake_lgbm.joblib"


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
