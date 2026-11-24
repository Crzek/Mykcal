"""structlog en JSON con lista blanca de campos (principio X, FR-014).

Nunca se registran cabeceras, cuerpos, tokens ni el `sub`.
"""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog

ALLOWED_FIELDS = frozenset(
    {
        "event",
        "level",
        "timestamp",
        "path",
        "method",
        "status",
        "error_code",
        "error_class",
        "auth_reason",
        "duration_ms",
        "request_id",
        "user_id",
        "from_revision",
        "to_revision",
        "sqlstate",
        "where",
        "fields",
        "source",
        # 003: alimentos. Nunca la consulta, el código de barras ni valores nutricionales.
        "result",
        "result_count",
        "sha256",
        "edition",
        "rows",
        "rows_upserted",
        "rows_archived",
        "food_id",
    }
)


def _allowlist(_logger: Any, _name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in event_dict.items() if k in ALLOWED_FIELDS}


def configure_logging() -> None:
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=logging.INFO, force=True)
    # httpx registra la URL completa de cada petición: con Open Food Facts incluiría el código
    # de barras que consulta una persona (principio X, research R15).
    for noisy in ("httpx", "httpcore"):
        logging.getLogger(noisy).setLevel(logging.WARNING)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            _allowlist,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        logger_factory=structlog.PrintLoggerFactory(file=sys.stdout),
        cache_logger_on_first_use=False,
    )


def get_logger() -> Any:
    return structlog.get_logger("mykcal")
