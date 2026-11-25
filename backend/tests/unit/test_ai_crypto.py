import base64
import os

import pytest
from cryptography.exceptions import InvalidTag

from mykcal.ai.crypto import decrypt_key, encrypt_key

MASTER = base64.b64encode(os.urandom(32)).decode()
OTHER = base64.b64encode(os.urandom(32)).decode()


def test_cifrar_y_descifrar_devuelve_el_original():
    assert decrypt_key(encrypt_key("AIza-clave-123", MASTER), MASTER) == "AIza-clave-123"


def test_otra_clave_maestra_no_descifra():
    with pytest.raises(InvalidTag):
        decrypt_key(encrypt_key("AIza-clave-123", MASTER), OTHER)


def test_nonce_aleatorio_da_bytes_distintos():
    assert encrypt_key("AIza-clave-123", MASTER) != encrypt_key("AIza-clave-123", MASTER)


def test_el_blob_no_contiene_la_clave_en_claro():
    assert b"AIza-clave-123" not in encrypt_key("AIza-clave-123", MASTER)


def test_blob_manipulado_no_descifra():
    blob = bytearray(encrypt_key("AIza-clave-123", MASTER))
    blob[-1] ^= 1
    with pytest.raises(InvalidTag):
        decrypt_key(bytes(blob), MASTER)
