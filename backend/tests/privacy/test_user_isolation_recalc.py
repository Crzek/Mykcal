"""FR-010 / principio V (007): la propuesta de A no llega a B."""

from datetime import UTC, datetime, timedelta

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}


async def test_la_propuesta_de_a_no_aparece_ni_se_resuelve_desde_b(
    client, user_with_consent, make_target_version, make_profile, make_weight
):
    a, ha = await user_with_consent("recalc-a")
    _, hb = await user_with_consent("recalc-b")
    await make_target_version(a, NOW - timedelta(days=30))
    await make_profile(a)
    for ago in range(3):
        await make_weight(a, TODAY - timedelta(days=ago), 78.2)
    assert (await client.get("/v1/recalc-proposal", params=OFF, headers=ha)).json()[
        "status"
    ] == "pending"

    assert (await client.get("/v1/recalc-proposal", params=OFF, headers=hb)).json() == {
        "status": "none"
    }
    for action in ("accept", "ignore"):
        resp = await client.post(f"/v1/recalc-proposal/{action}", params=OFF, headers=hb)
        assert resp.status_code == 409 and resp.json()["code"] == "RECALC_NO_PROPOSAL"
    # La propuesta y el objetivo de A siguen intactos
    assert (await client.get("/v1/recalc-proposal", params=OFF, headers=ha)).json()[
        "status"
    ] == "pending"
    assert (await client.get("/v1/target", headers=ha)).json()["source"] == "calculated"
