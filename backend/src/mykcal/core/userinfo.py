"""Nombre visible desde el endpoint userinfo de Zitadel (research R5). El email no se guarda."""

from __future__ import annotations

import httpx

from mykcal.core.auth import OidcClient


async def fetch_display_name(oidc: OidcClient, token: str) -> str | None:
    try:
        cfg = await oidc.discovery()
        resp = await oidc.http.get(
            cfg["userinfo_endpoint"], headers={"Authorization": f"Bearer {token}"}
        )
        resp.raise_for_status()
        data = resp.json()
    except (httpx.HTTPError, KeyError, ValueError):
        return None
    name = data.get("name") or data.get("preferred_username")
    if not isinstance(name, str):
        return None
    name = name.strip()[:200]
    return name or None
