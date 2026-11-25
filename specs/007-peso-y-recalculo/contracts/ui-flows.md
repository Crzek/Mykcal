# Flujos de interfaz (app)

Feature Flutter `lib/features/weight/`. Textos externalizados en `l10n/app_es.arb` (principio VIII).
Todo en español, kg, tema claro/oscuro, WCAG 2.1 AA, controles etiquetados para lector de pantalla.

## F1 — Registrar peso (US1)

1. Desde la pantalla principal, acceso a «Peso». Campo numérico (kg, 1 decimal) y selector de fecha
   con **hoy** (fecha local del móvil) por defecto; el selector no permite fechas futuras.
2. Guardar → `POST /v1/weight`. Si ya hay registro ese día, lo sustituye (aviso breve).
3. Rango 30–300: fuera de rango, mensaje con el rango válido; no se guarda.
4. Lista de registros debajo (fecha + peso) con editar y borrar por fila.
5. Editar → `PUT /v1/weight/{date}`; borrar → `DELETE /v1/weight/{date}` (confirmación). La gráfica se
   actualiza.
6. Offline: aviso y el valor escrito se conserva en el campo.

Accesibilidad: cada control etiquetado; la lista es navegable; errores anunciados.

## F2 — Gráfica de peso (US2)

1. En la pantalla de peso, gráfica (`fl_chart`) con puntos diarios y línea de media semanal.
2. Selector de periodo: **30 días / 90 días / todo** → `GET /v1/weight/chart?period=...`.
3. Días sin registro no se dibujan; la media solo aparece en días con ≥3 registros en su ventana.
4. Alternativa textual (siempre presente, no solo con lector): resumen «peso actual, media semanal,
   variación en el periodo» + lista de registros (de F1).
5. Con menos de 2 registros: mensaje «necesitas más registros» en lugar de la gráfica.

## F3 — Propuesta de recálculo (US3)

1. Al abrir la app (tras resumen/arranque) se consulta `GET /v1/recalc-proposal`.
   - También se reevalúa tras guardar/editar/borrar un peso.
2. Si `status == pending`: diálogo con el **objetivo actual** y el **objetivo propuesto**
   (reutiliza/extiende `features/target/recalc_dialogs.dart`, con `macroLine`).
   - Si `was_manual`: aviso «aceptar sustituirá tus valores editados».
   - Si `large_change`: aviso «variación muy grande, revisa si hay un registro erróneo».
3. **Aceptar** → `POST /v1/recalc-proposal/accept`; se muestra el objetivo nuevo (antes → ahora) y la
   pantalla de objetivo se refresca.
4. **Ignorar** → `POST /v1/recalc-proposal/ignore`; el diálogo se cierra y no reaparece en 7 días.
5. Si el usuario cierra sin responder, al reabrir la app la misma propuesta vuelve a mostrarse
   (US3.7): sigue `pending` en el servidor.

Accesibilidad: el diálogo recibe el foco, los botones Aceptar/Ignorar están etiquetados, y el
contenido (actual/propuesto) se lee como texto, no solo como gráfico.
