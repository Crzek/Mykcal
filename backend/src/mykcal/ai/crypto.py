"""Cifrado de la clave de IA en reposo: AES-256-GCM, `nonce(12) ‖ ciphertext ‖ tag` (R1)."""

from __future__ import annotations

import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

NONCE_BYTES = 12


def decode_master(master_b64: str) -> bytes:
    key = base64.b64decode(master_b64, validate=True)
    if len(key) != 32:
        raise ValueError("AI_KEY_MASTER debe decodificar a 32 bytes")
    return key


def encrypt_key(raw_key: str, master_b64: str) -> bytes:
    nonce = os.urandom(NONCE_BYTES)
    return nonce + AESGCM(decode_master(master_b64)).encrypt(nonce, raw_key.encode(), None)


def decrypt_key(blob: bytes, master_b64: str) -> str:
    nonce, data = blob[:NONCE_BYTES], blob[NONCE_BYTES:]
    return AESGCM(decode_master(master_b64)).decrypt(nonce, data, None).decode()
