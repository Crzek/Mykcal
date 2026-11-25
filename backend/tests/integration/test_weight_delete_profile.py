"""T048 (007): borrar el único peso (el del onboarding) no rompe el perfil ni el recálculo."""

from datetime import UTC, datetime

OFF = {"utc_offset_min": 0}


async def test_borrar_el_unico_peso_no_rompe_perfil_ni_recalculo(
    client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("onb"))
    h = zitadel.headers("onb")
    today = datetime.now(UTC).date()
    assert (await client.put("/v1/profile", json=profile_body(), headers=h)).status_code == 200
    target_before = (await client.get("/v1/target", headers=h)).json()

    assert (await client.delete(f"/v1/weight/{today}", params=OFF, headers=h)).status_code == 204

    profile = await client.get("/v1/profile", headers=h)
    assert profile.status_code == 200
    assert profile.json()["weight_kg"] == 80.0
    assert (
        profile.json()["weight_measured_on"] == target_before["calculation"]["calculated_at"][:10]
    )
    recalc = await client.post("/v1/target/recalculate", headers=h)
    assert recalc.status_code == 200
    assert recalc.json()["calculation"]["weight_kg"] == 80.0
    after = (await client.get("/v1/target", headers=h)).json()
    assert after["values"] == target_before["values"]

    await client.post(
        "/v1/weight",
        json={"measured_on": today.isoformat(), "weight_kg": 79.0},
        params=OFF,
        headers=h,
    )
    assert (await client.get("/v1/profile", headers=h)).json()["weight_kg"] == 79.0
