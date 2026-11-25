# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml` (lo leen las
pruebas de contrato). Esta feature le añade las rutas de peso y de propuesta de recálculo y los
schemas de abajo. `info.version` pasa de `0.5.0` a `0.6.0`.

Todas las rutas nuevas exigen `bearerToken`, cuenta activa **y consentimiento** (datos de salud,
principio IV). No hay rutas públicas nuevas. Todas pueden devolver `401`, `403`
(`ACCOUNT_NOT_REGISTERED`, `ACCOUNT_DISABLED`, `CONSENT_REQUIRED`) y `503 AUTH_UNAVAILABLE`.

## Resumen

| Método y ruta | Descripción | Respuestas |
|---|---|---|
| `GET /v1/weight` | Lista de registros de peso del usuario (opcional `from`,`to`) | `200 WeightList` |
| `POST /v1/weight` | Crea o sustituye el registro de un día | `200 WeightEntry`, `400 VALIDATION_ERROR` |
| `PUT /v1/weight/{date}` | Edita el peso de un día existente | `200 WeightEntry`, `400 VALIDATION_ERROR`, `404 WEIGHT_NOT_FOUND` |
| `DELETE /v1/weight/{date}` | Borra el registro de un día | `204`, `404 WEIGHT_NOT_FOUND` |
| `GET /v1/weight/chart` | Serie para la gráfica + resumen accesible | `200 WeightChart` |
| `GET /v1/recalc-proposal` | Propuesta pendiente (evalúa el umbral al abrir) | `200 RecalcProposal` (o `{status:"none"}`) |
| `POST /v1/recalc-proposal/accept` | Acepta: recalcula con la media semanal | `200 DailyTarget`, `409 RECALC_NO_PROPOSAL` |
| `POST /v1/recalc-proposal/ignore` | Ignora 7 días | `204`, `409 RECALC_NO_PROPOSAL` |

`utc_offset_min` (query, entero entre −840 y 840) es **obligatorio** en `POST`, `PUT` y `DELETE`
`/v1/weight`, en `GET /v1/weight/chart` y en `GET /v1/recalc-proposal`: determina el «hoy» local del
móvil (igual que el diario). Una fecha de registro posterior a ese «hoy» se rechaza con
`400 VALIDATION_ERROR` (`fields: [measured_on]`); también la anterior a la fecha de alta − 1 día.

### Códigos de error nuevos

- `WEIGHT_NOT_FOUND` (404): no hay registro de peso en esa fecha.
- `RECALC_NO_PROPOSAL` (409): no hay propuesta pendiente que aceptar o ignorar.

(Se añaden a `mykcal/core/errors.py::ErrorCode`.)

## Fragmento OpenAPI

```yaml
paths:
  /v1/weight:
    get:
      summary: Lista los registros de peso del usuario (FR-002, FR-010)
      parameters:
        - { name: from, in: query, required: false, schema: { type: string, format: date } }
        - { name: to, in: query, required: false, schema: { type: string, format: date } }
      responses:
        "200":
          description: Registros ordenados por fecha descendente
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WeightList" }
    post:
      summary: Crea o sustituye el peso de un día (FR-001)
      parameters:
        - { name: utc_offset_min, in: query, required: true, schema: { type: integer, minimum: -840, maximum: 840 } }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/WeightInput" }
      responses:
        "200":
          description: Registro guardado
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WeightEntry" }
        "400": { $ref: "#/components/responses/ValidationError" }
  /v1/weight/{date}:
    put:
      summary: Edita el peso de un día (FR-002)
      parameters:
        - { name: date, in: path, required: true, schema: { type: string, format: date } }
        - { name: utc_offset_min, in: query, required: true, schema: { type: integer, minimum: -840, maximum: 840 } }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [weight_kg]
              properties:
                weight_kg: { type: number, minimum: 30, maximum: 300 }
      responses:
        "200":
          description: Registro editado
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WeightEntry" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "404":
          description: No hay registro en esa fecha (WEIGHT_NOT_FOUND)
    delete:
      summary: Borra el peso de un día (FR-002)
      parameters:
        - { name: date, in: path, required: true, schema: { type: string, format: date } }
        - { name: utc_offset_min, in: query, required: true, schema: { type: integer, minimum: -840, maximum: 840 } }
      responses:
        "204": { description: Borrado }
        "404":
          description: No hay registro en esa fecha (WEIGHT_NOT_FOUND)
  /v1/weight/chart:
    get:
      summary: Serie de la gráfica y resumen accesible (FR-003, FR-004)
      parameters:
        - name: period
          in: query
          required: true
          schema: { type: string, enum: [p30, p90, all] }
        - { name: utc_offset_min, in: query, required: true, schema: { type: integer, minimum: -840, maximum: 840 } }
      responses:
        "200":
          description: Puntos diarios, media móvil y resumen
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WeightChart" }
  /v1/recalc-proposal:
    get:
      summary: Propuesta de recálculo pendiente, evaluada al abrir la app (FR-005, FR-007)
      parameters:
        - { name: utc_offset_min, in: query, required: true, schema: { type: integer, minimum: -840, maximum: 840 } }
      responses:
        "200":
          description: Propuesta pendiente o ninguna
          content:
            application/json:
              schema: { $ref: "#/components/schemas/RecalcProposal" }
  /v1/recalc-proposal/accept:
    post:
      summary: Acepta la propuesta y recalcula con la media semanal (FR-006)
      responses:
        "200":
          description: Objetivo recalculado
          content:
            application/json:
              schema: { $ref: "#/components/schemas/DailyTarget" }
        "409":
          description: No hay propuesta pendiente (RECALC_NO_PROPOSAL)
  /v1/recalc-proposal/ignore:
    post:
      summary: Ignora la propuesta durante 7 días (FR-007)
      responses:
        "204": { description: Ignorada }
        "409":
          description: No hay propuesta pendiente (RECALC_NO_PROPOSAL)

components:
  schemas:
    WeightInput:
      type: object
      additionalProperties: false
      required: [measured_on, weight_kg]
      properties:
        measured_on: { type: string, format: date }
        weight_kg: { type: number, minimum: 30, maximum: 300 }
    WeightEntry:
      type: object
      required: [measured_on, weight_kg, updated_at]
      properties:
        measured_on: { type: string, format: date }
        weight_kg: { type: number }
        updated_at: { type: string, format: date-time }
    WeightList:
      type: object
      required: [entries]
      properties:
        entries:
          type: array
          items: { $ref: "#/components/schemas/WeightEntry" }
    WeightChartPoint:
      type: object
      required: [date, weight_kg, average_kg]
      properties:
        date: { type: string, format: date }
        weight_kg: { type: number, nullable: true }   # null: día sin registro (no se dibuja punto)
        average_kg: { type: number, nullable: true }  # null: ventana con <3 registros
    WeightChart:
      type: object
      required: [period, points, summary]
      properties:
        period: { type: string, enum: [p30, p90, all] }
        points:
          type: array
          items: { $ref: "#/components/schemas/WeightChartPoint" }
        summary:
          type: object
          required: [count]
          properties:
            count: { type: integer }                     # nº de registros en el periodo
            current_weight_kg: { type: number, nullable: true }
            weekly_average_kg: { type: number, nullable: true }
            change_kg: { type: number, nullable: true }  # variación en el periodo
    RecalcProposal:
      type: object
      required: [status]
      properties:
        status: { type: string, enum: [pending, none] }
        reference_weight_kg: { type: number, nullable: true }
        weekly_average_kg: { type: number, nullable: true }
        was_manual: { type: boolean, nullable: true }
        large_change: { type: boolean, nullable: true }   # variación >10% (aviso)
        current: { $ref: "#/components/schemas/TargetValues" }   # objetivo actual (nullable)
        proposed: { $ref: "#/components/schemas/TargetValues" }  # objetivo propuesto (nullable)
```

Nota de contrato: `current`/`proposed` se omiten (`response_model_exclude_none`) cuando
`status = none`.
