"""Daily feed-intake prediction (LightGBM regression, MI_module_AI_Regression).

Optional: needs `pip install -r requirements-ai.txt`. Without it the endpoint
answers 501 and the apps simply hide the prediction card.
"""
from functools import lru_cache

from fastapi import APIRouter, Depends

from ..config import get_settings
from ..deps import Principal, auth
from ..errors import ApiError
from .profiles import farm_cow

router = APIRouter(tags=["ai"])

BREED_TYPE = {
    "Holstein": "dairy", "Jersey": "dairy",
    "Angus": "beef", "Limousin": "beef", "Charolais": "beef",
    "Simmental": "dual",
}


@lru_cache(maxsize=1)
def _load():
    import joblib  # noqa: PLC0415 - optional heavy dependency

    model = joblib.load(get_settings().model_path)
    cats = model.booster_.pandas_categorical
    return model, list(cats[0]), list(cats[1])


def predict_intake(age_months: float, weight_kg: float, cow_type: str, breed: str) -> float:
    import pandas as pd  # noqa: PLC0415

    model, types, breeds = _load()
    if breed not in breeds:
        raise ValueError(f"breed must be one of {breeds}")
    frame = pd.DataFrame(
        {
            "age_months": [float(age_months)],
            "weight_kg": [float(weight_kg)],
            "type": pd.Categorical([cow_type or BREED_TYPE[breed]], categories=types),
            "breed": pd.Categorical([breed], categories=breeds),
        }
    )
    return float(model.predict(frame[["age_months", "weight_kg", "type", "breed"]])[0])


@router.get("/predict/{cow_id}")
async def predict(cow_id: str, p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    from .profiles import cow_json  # noqa: PLC0415

    cow = cow_json(await farm_cow(p, cow_id))
    try:
        kg = predict_intake(cow["age_months"], cow["weight_kg"], cow["type"], cow["breed"])
    except ImportError:
        raise ApiError(501, "prediction_unavailable", "Prédiction non disponible") from None
    except (ValueError, FileNotFoundError) as exc:
        raise ApiError(502, "prediction_failed", str(exc)) from None
    return {
        "cow_id": cow["cow_id"],
        "predicted_intake_kg_dm": round(kg, 2),
        "model": "lightgbm",
        "inputs": {
            "age_months": cow["age_months"],
            "weight_kg": cow["weight_kg"],
            "type": cow["type"],
            "breed": cow["breed"],
        },
    }
