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
    }
)


def _allowlist(_logger: Any, _name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in event_dict.items() if k in ALLOWED_FIELDS}


def configure_logging() -> None:
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=logging.INFO, force=True)
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
