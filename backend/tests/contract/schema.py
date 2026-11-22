"""Valida respuestas contra specs/001-acceso-y-despliegue/contracts/openapi.yaml."""

from __future__ import annotations

from jsonschema import Draft202012Validator


def _resolve(ref: str, spec: dict) -> dict:
    node = spec
    for part in ref.removeprefix("#/").split("/"):
        node = node[part]
    return node


def assert_matches_contract(spec: dict, path: str, method: str, status: int, body) -> None:
    op = spec["paths"][path][method.lower()]
    response = op["responses"].get(str(status))
    assert response is not None, f"{method} {path} {status} no está en el contrato"
    if "$ref" in response:
        response = _resolve(response["$ref"], spec)
    content = response.get("content", {}).get("application/json")
    if content is None:
        return
    schema = {**content["schema"], "components": spec["components"]}
    Draft202012Validator(schema).validate(body)
