"""SC-003 / principio IV: sin consentimiento no se guarda ningún dato de salud."""

import uuid

import pytest
from sqlalchemy import text

from mykcal.main import PUBLIC_ROUTES

pytestmark = pytest.mark.privacy

HEALTH_DATA_ROUTES = {
    ("GET", "/v1/profile"),
    ("PUT", "/v1/profile"),
    ("GET", "/v1/target"),
    ("PUT", "/v1/target"),
    ("POST", "/v1/target/recalculate"),
    ("GET", "/v1/foods/search"),
    ("GET", "/v1/foods/barcode"),
    ("GET", "/v1/foods/custom"),
    ("POST", "/v1/foods/custom"),
    ("PUT", "/v1/foods/custom/{food_id}"),
    ("DELETE", "/v1/foods/custom/{food_id}"),
    ("GET", "/v1/foods/{food_id}"),
    ("GET", "/v1/diary/days/{date}"),
    ("POST", "/v1/diary/entries"),
    ("PATCH", "/v1/diary/entries/{entry_id}"),
    ("DELETE", "/v1/diary/entries/{entry_id}"),
    ("POST", "/v1/diary/entries/{entry_id}/restore"),
}
FOODS_QUERY = {
    "/v1/foods/search": {"q": "platano"},
    "/v1/foods/barcode": {"code": "8410000000016"},
}
DIARY_QUERY = {"/v1/diary/days": {"utc_offset_min": 0}, "/v1/diary/entries": {"utc_offset_min": 0}}
CUSTOM_FOOD_BODY = {
    "name": "Tarta",
    "base_unit": "g",
    "basis": "per_100",
    "values": {"kcal": 320, "protein_g": 6, "carbs_g": 45, "fat_g": 13},
}
NO_CONSENT_NEEDED = {
    ("GET", "/v1/me"),
    ("POST", "/v1/registration"),
    ("POST", "/v1/consent"),
    ("POST", "/v1/me/deactivation"),
    ("GET", "/v1/admin/invitation"),
    ("POST", "/v1/admin/invitation/rotate"),
} | PUBLIC_ROUTES


def test_toda_ruta_esta_clasificada(app):
    paths = app.openapi()["paths"]
    ops = {(m.upper(), p) for p, methods in paths.items() for m in methods}
    unclassified = ops - HEALTH_DATA_ROUTES - NO_CONSENT_NEEDED
    assert not unclassified, f"ruta nueva sin clasificar (¿datos de salud?): {unclassified}"


async def test_rutas_de_salud_exigen_consentimiento_y_no_escriben(
    app, client, zitadel, make_account, profile_body
):
    await make_account("u1")
    h = zitadel.headers("u1")
    target = {
        "kcal": 2000,
        "protein_g": 100,
        "carbs_g": 200,
        "fat_g": 60,
        "fiber_g": 30,
        "sodium_mg": 2000,
        "potassium_mg": 3500,
        "calcium_mg": 1000,
        "iron_mg": 8,
        "magnesium_mg": 400,
        "vitamin_d_ug": 15,
        "vitamin_c_mg": 90,
    }
    bodies = {
        ("PUT", "/v1/profile"): profile_body(),
        ("PUT", "/v1/target"): target,
        ("POST", "/v1/foods/custom"): CUSTOM_FOOD_BODY,
        ("PUT", "/v1/foods/custom/{food_id}"): CUSTOM_FOOD_BODY,
        ("POST", "/v1/diary/entries"): {
            "date": "2026-01-01",
            "meal": "lunch",
            "food_id": str(uuid.uuid4()),
            "quantity": 100,
        },
        ("PATCH", "/v1/diary/entries/{entry_id}"): {"quantity": 100},
    }
    for method, route in sorted(HEALTH_DATA_ROUTES):
        path = route.replace("{food_id}", str(uuid.uuid4())).replace(
            "{entry_id}", str(uuid.uuid4())
        )
        path = path.replace("{date}", "2026-01-01")
        resp = await client.request(
            method,
            path,
            headers=h,
            json=bodies.get((method, route)),
            params=FOODS_QUERY.get(route) or DIARY_QUERY.get(route.split("{")[0].rstrip("/")),
        )
        assert resp.status_code == 403, (method, path)
        assert resp.json()["code"] == "CONSENT_REQUIRED", (method, path)
    async with app.state.sessionmaker() as s:
        for table in ("user_profile", "weight_entry", "daily_target", "food", "diary_entry"):
            assert (await s.execute(text(f"SELECT count(*) FROM {table}"))).scalar_one() == 0
