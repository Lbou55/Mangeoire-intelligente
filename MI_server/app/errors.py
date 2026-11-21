"""Errors are returned as {"error": <code>, "detail": <French message>}.

The Flutter apps translate the `error` code (French / Arabic), so codes are stable.
"""
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    def __init__(self, status: int, code: str, detail: str = ""):
        self.status = status
        self.code = code
        self.detail = detail or code


def bad_request(code: str, detail: str = "") -> ApiError:
    return ApiError(400, code, detail)


def unauthorized(code: str = "invalid_token", detail: str = "Session invalide") -> ApiError:
    return ApiError(401, code, detail)


def forbidden(code: str = "forbidden", detail: str = "Accès refusé") -> ApiError:
    return ApiError(403, code, detail)


def not_found(code: str = "not_found", detail: str = "Introuvable") -> ApiError:
    return ApiError(404, code, detail)


def conflict(code: str = "conflict", detail: str = "Déjà existant") -> ApiError:
    return ApiError(409, code, detail)


def subscription_expired() -> ApiError:
    return ApiError(402, "subscription_expired", "Abonnement expiré")


def install_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_: Request, exc: ApiError):
        return JSONResponse(
            {"error": exc.code, "detail": exc.detail}, status_code=exc.status
        )

    @app.exception_handler(RequestValidationError)
    async def _val(_: Request, exc: RequestValidationError):
        fields = ", ".join(
            ".".join(str(p) for p in e.get("loc", [])[1:]) for e in exc.errors()
        )
        return JSONResponse(
            {"error": "validation_error", "detail": fields or "Données invalides"},
            status_code=422,
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException):
        return JSONResponse(
            {"error": "http_error", "detail": str(exc.detail)},
            status_code=exc.status_code,
        )
