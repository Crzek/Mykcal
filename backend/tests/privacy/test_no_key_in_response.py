"""T017 (006): FR-004, SC-003. La clave nunca vuelve al cliente ni queda en los registros."""

import json

import pytest

pytestmark = pytest.mark.privacy

KEY = "AIzaSyClaveSecretaDePrueba98765"


def strings(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for v in node.values():
            yield from strings(v)
    elif isinstance(node, list):
        for v in node:
            yield from strings(v)


async def test_las_respuestas_no_contienen_la_clave(client, user_with_consent, capsys):
    _, h = await user_with_consent("no-key-resp")
    bodies = []
    for resp in (
        await client.put("/v1/ai-key", headers=h, json={"raw_key": KEY}),
        await client.get("/v1/ai-key", headers=h),
    ):
        bodies.append(resp.json())
    delete = await client.delete("/v1/ai-key", headers=h)
    assert delete.content == b""
    chunks = [KEY[i : i + 8] for i in range(len(KEY) - 7)]
    for body in bodies:
        for value in strings(body):
            assert not any(c in value for c in chunks)
    out = capsys.readouterr().out
    assert KEY not in out
    for line in out.splitlines():
        json.loads(line)
