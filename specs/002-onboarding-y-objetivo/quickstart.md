# Quickstart: validación de la 002

## 1. Pruebas automáticas

```bash
cd backend && uv run ruff check && uv run pytest     # unit (cálculo), integración, contrato y privacy
cd app && flutter analyze && flutter test
```

Todo en verde. En particular:

- `tests/unit/test_target_calc.py`: las 13 filas de `contracts/calc-cases.md` y la rejilla de
  propiedades (SC-002).
- `tests/privacy/`: rutas de salud sin consentimiento → `403 CONSENT_REQUIRED` sin escribir nada
  (SC-003); aislamiento entre usuarios; cuenta dada de baja → `403 ACCOUNT_DISABLED` (SC-005).
- `tests/integration/test_recalculation.py`: un objetivo manual no cambia tras `PUT /v1/profile`
  (SC-004).

## 2. Migración

```bash
cd backend && docker compose -f docker-compose.dev.yml up -d && uv run alembic upgrade head
```

Debe aplicar `0002_onboarding` sobre `0001_access` sin errores. `alembic downgrade -1` la revierte.

## 3. APK en el emulador y en el móvil

```bash
app/scripts/build_apk.sh dev
adb install -r app/build/app/outputs/flutter-apk/app-dev-release.apk
```

Usar una cuenta nueva de desarrollo (con el código de invitación vigente del entorno `dev`).

## 4. Escenarios

| # | Pasos | Resultado esperado | Requisito |
|---|---|---|---|
| 1 | Cuenta recién creada → abrir la app | Pantalla de consentimiento antes que ninguna otra | US1.1, FR-001 |
| 2 | No marcar la casilla | «Aceptar y continuar» deshabilitado; solo se puede cerrar sesión | US1.2 |
| 3 | Marcar y aceptar | Pantalla de perfil. En la base, fila en `health_consent` con versión y hora | US1.3, FR-003 |
| 4 | Cerrar la app en el perfil y volver a abrirla | Vuelve al perfil, no al consentimiento | Edge case |
| 5 | Altura 30 → «Calcular mi objetivo» | «Entre 100 y 250 cm» junto al campo; nada guardado | US1.5 |
| 6 | Edad 17 | «Entre 18 y 100 años» | Edge case |
| 7 | Hombre, 30, 180, 80, moderada, mantener | 2.759 kcal · P 144 · C 373 · G 77; fibra 30 g y los 7 micros | US2.1, US2.2 |
| 8 | «Empezar» | Inicio con la tarjeta del objetivo | US2.1 |
| 9 | Ajustes → Mi perfil → objetivo «Perder grasa» → Guardar | Diálogo «Tu objetivo se ha actualizado»: 2.207 · P 176 · C 238 · G 61 | US2.3, US2.4 |
| 10 | Mi objetivo → Editar → kcal 2.000 sin tocar macros | Aviso de macros que no cuadran; se puede guardar; aparece «Editado a mano» | US3.1, US3.4 |
| 11 | Mi perfil → actividad «Alta» → Guardar → «Mantener el mío» | El objetivo sigue en 2.000 kcal | US3.2, SC-004 |
| 12 | Repetir 11 con «Recalcular» | Objetivo recalculado; desaparece «Editado a mano» | US2.4 |
| 13 | Editar de nuevo → «Volver al cálculo» → confirmar | Objetivo calculado con los datos actuales | US3.3 |
| 14 | Mujer, 55, 160, 50, sedentaria, perder grasa | 1.200 kcal con el aviso del mínimo seguro; hierro 8 mg | Edge case, FR-009, FR-011 |
| 15 | Modo avión → cambiar el perfil → Guardar | Aviso sin conexión; los valores siguen escritos | Edge case |
| 16 | Lector de pantalla (TalkBack) y texto al 200% en las pantallas 1–7 de `contracts/ui-flows.md` | Todo se lee y nada se corta | FR-020 |
| 17 | Ajustes → Darse de baja → Cancelar | No pasa nada | US4.1 |
| 18 | Darse de baja → confirmar | Pantalla de acceso con «Tu cuenta se ha dado de baja.» | US4.2 |
| 19 | Iniciar sesión otra vez con la misma cuenta | Pantalla «Cuenta desactivada» | US4.3, SC-005 |
| 20 | Como administrador → Invitaciones | Cuentas activas una menos que antes de la baja | US4.2 |
| 21 | Cronometrar 1–8 con una cuenta nueva | Menos de 3 minutos | SC-001 |

## 5. Comprobaciones en la base (entorno local o dev)

```sql
-- SC-003: ningún dato de salud sin consentimiento
SELECT count(*) FROM user_profile p
LEFT JOIN health_consent c ON c.user_id = p.user_id WHERE c.id IS NULL;   -- 0

-- Un solo objetivo vigente por usuario
SELECT user_id, count(*) FROM daily_target WHERE is_current GROUP BY user_id HAVING count(*) > 1;  -- vacío

-- El peso del onboarding es el primer registro y el peso usado en el cálculo (FR-006)
SELECT w.weight_kg, t.calc_weight_kg FROM weight_entry w
JOIN daily_target t ON t.user_id = w.user_id AND t.is_current;
```

## 6. Cierre

- Pruebas en verde, escenarios 1–21 anotados en el PR de `002-onboarding-y-objetivo` → `dev`.
- Desplegado en Dokploy `dev`; el APK de `dev` publicado con `app/scripts/publish_apk.sh dev`
  (principio IX).
