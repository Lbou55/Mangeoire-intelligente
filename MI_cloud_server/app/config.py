from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- MongoDB (use a TEST database while developing) ---
    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db: str = "farm_test"
    mongo_collection: str = "feeding_events"  # ESP32 daily data (same name as before)

    # --- RabbitMQ ingestion (empty = disabled, handy on your PC) ---
    amqp_url: str = ""
    queue_name: str = "test_queue"

    # --- security ---
    secret_key: str = "dev-secret-change-me"      # CHANGE on Render
    token_minutes: int = 60 * 24 * 7              # login lasts 7 days
    service_key: str = "dev-service-key"          # used by Node-RED / the Pi to set cow status

    # --- AI verdict -> class (normal / alerte / danger) ---
    danger_threshold: float = 0.85                # p_flagged >= this  => danger

    cors_origins: str = "*"                       # fine for tests; restrict later


settings = Settings()
