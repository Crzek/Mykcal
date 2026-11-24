"""SC-005 / principio V: el usuario B nunca ve ni toca una entrada del diario de A."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]

TODAY = datetime.now(UTC).date()
Q = "?utc_offset_min=0"


@pytest.fixture
async def two_users(user_with_consent, make_target_version):
    a, ha = await user_with_consent("diary-a")
    b, hb = await user_with_consent("diary-b")
    for account in (a, b):
        await make_target_version(account, datetime.now(UTC) - timedelta(days=5))
    return (a, ha), (b, hb)


async def test_b_no_puede_editar_borrar_ni_restaurar_una_entrada_de_a(
    client, two_users, make_entry
):
    (a, ha), (_, hb) = two_users
    entry = await make_entry(a, TODAY, quantity=100, kcal=300, name="Cena secreta de A")
    ghost = uuid.uuid4()
    calls = [
        ("PATCH", "", {"quantity": 5}),
        ("DELETE", "", None),
        ("POST", "/restore", None),
    ]
    for method, suffix, body in calls:
        theirs = await client.request(
            method, f"/v1/diary/entries/{entry}{suffix}{Q}", json=body, headers=hb
        )
        nobody = await client.request(
            method, f"/v1/diary/entries/{ghost}{suffix}{Q}", json=body, headers=hb
        )
        assert theirs.status_code == nobody.status_code == 404, method
        assert theirs.json()["code"] == "ENTRY_NOT_FOUND"
        # Indistinguible de un id inexistente (salvo el id de la petición).
        assert {k: v for k, v in theirs.json().items() if k != "request_id"} == {
            k: v for k, v in nobody.json().items() if k != "request_id"
        }
    # La entrada de A sigue intacta.
    day = (await client.get(f"/v1/diary/days/{TODAY.isoformat()}{Q}", headers=ha)).json()
    assert day["totals"]["consumed"]["kcal"] == 300


async def test_el_dia_de_b_nunca_incluye_entradas_de_a_aunque_tengan_la_misma_fecha(
    client, two_users, make_entry
):
    (a, _), (b, hb) = two_users
    await make_entry(a, TODAY, "lunch", quantity=100, kcal=800, name="Plato de A")
    await make_entry(b, TODAY, "lunch", quantity=100, kcal=100, name="Plato de B")
    resp = await client.get(f"/v1/diary/days/{TODAY.isoformat()}{Q}", headers=hb)
    body = resp.json()
    assert body["totals"]["consumed"]["kcal"] == 100
    assert "Plato de A" not in resp.text


async def test_b_no_puede_añadir_un_personalizado_de_a(client, two_users, make_food):
    (a, _), (_, hb) = two_users
    ajeno = await make_food("Tarta de A", kind="custom", owner=a)
    resp = await client.post(
        f"/v1/diary/entries{Q}",
        json={"date": TODAY.isoformat(), "meal": "dinner", "food_id": str(ajeno), "quantity": 50},
        headers=hb,
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "FOOD_NOT_FOUND"
