# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, que es el
que leen las pruebas de contrato. Esta feature le añade las rutas y los *schemas* de abajo, una
cabecera en `POST /v1/diary/entries` y dos códigos en `ErrorBody`. `info.version` pasa a `0.5.0`.

Todas las rutas nuevas exigen `bearerToken`, cuenta activa y consentimiento (research R10). No hay
rutas públicas nuevas.

## Resumen

| Método y ruta | Respuestas |
|---|---|
| `GET /v1/foods/recent` | `200 QuickFoodList` (≤ 30) |
| `GET /v1/foods/favorites` | `200 QuickFoodList` |
| `PUT /v1/foods/favorites/{food_id}` | `204`, `404 FOOD_NOT_FOUND` |
| `DELETE /v1/foods/favorites/{food_id}` | `204` (también si no era favorito) |
| `GET /v1/diary/copy-sources` | `200 CopySourceList`, `400 VALIDATION_ERROR` / `DIARY_DATE_OUT_OF_RANGE` |
| `POST /v1/diary/copies` | `201 DiaryCopyResult`, `400 VALIDATION_ERROR` / `DIARY_DATE_OUT_OF_RANGE` / `COPY_SOURCE_EMPTY`, `404 TARGET_NOT_FOUND` |
| `DELETE /v1/diary/copies/{copy_id}` | `200 DiaryDay`, `404 COPY_NOT_FOUND` |
| `POST /v1/diary/entries` (004) | sin cambios en el cuerpo; `201` añade la cabecera `Location` |

Todas pueden devolver además `401`, `403` (`ACCOUNT_NOT_REGISTERED`, `ACCOUNT_DISABLED`,
`CONSENT_REQUIRED`) y `503 AUTH_UNAVAILABLE`.

`POST /v1/diary/copies` y `DELETE /v1/diary/copies/{copy_id}` reciben `utc_offset_min` como las
rutas de la 004 (el del día destino). `GET /v1/diary/copy-sources` no lo necesita: no devuelve
objetivo.

Códigos nuevos en `ErrorCode`: `COPY_SOURCE_EMPTY`, `COPY_NOT_FOUND`.

`DELETE /v1/diary/entries/{id}` (004) sirve también para deshacer un añadido rápido (research R4).

**Orden de registro**: el router de `quick` va antes que el de `foods` en `main.py`, o
`GET /v1/foods/{food_id}` capturaría `recent` y `favorites` (research R10). Lo fija una prueba de
contrato.

## Fragmento OpenAPI

```yaml
paths:
  /v1/foods/recent:
    get:
      summary: Últimos 30 alimentos distintos registrados, por último uso (FR-001)
      responses:
        "200": { $ref: "#/components/responses/QuickFoodListOk" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/foods/favorites:
    get:
      summary: Favoritos por último uso; los nunca usados al final por nombre (FR-010)
      responses:
        "200": { $ref: "#/components/responses/QuickFoodListOk" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/foods/favorites/{food_id}:
    parameters:
      - { name: food_id, in: path, required: true, schema: { type: string, format: uuid } }
    put:
      summary: Marca un alimento como favorito (idempotente, FR-003)
      responses:
        "204": { description: Es favorito }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/FoodNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    delete:
      summary: Desmarca un favorito (idempotente, US2.3)
      responses:
        "204": { description: No es favorito }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/copy-sources:
    get:
      summary: Comidas con entradas de los 14 días anteriores al destino (FR-005)
      parameters:
        - { name: target_date, in: query, required: true, schema: { type: string, format: date } }
        - { name: target_meal, in: query, required: true, schema: { $ref: "#/components/schemas/Meal" } }
      responses:
        "200":
          description: Días del más reciente al más antiguo; solo días y comidas con entradas
          content:
            application/json:
              schema: { $ref: "#/components/schemas/CopySourceList" }
        "400": { $ref: "#/components/responses/DiaryBadRequest" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/copies:
    post:
      summary: Copia todas las entradas de una comida a una comida del día destino (FR-005, FR-006)
      parameters:
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/DiaryCopyCreate" }
      responses:
        "201":
          description: Copia hecha; día destino completo
          content:
            application/json:
              schema: { $ref: "#/components/schemas/DiaryCopyResult" }
        "400":
          description: VALIDATION_ERROR, DIARY_DATE_OUT_OF_RANGE o COPY_SOURCE_EMPTY
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/TargetNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/copies/{copy_id}:
    parameters:
      - { name: copy_id, in: path, required: true, schema: { type: string, format: uuid } }
      - { $ref: "#/components/parameters/UtcOffsetMin" }
    delete:
      summary: Deshace una copia hecha hace 60 s o menos; borra solo sus entradas (FR-007, US3.5)
      responses:
        "200": { $ref: "#/components/responses/DiaryDayOk" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404":
          description: COPY_NOT_FOUND (inexistente, ajena, ya deshecha o fuera de plazo)
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/entries:
    post:
      # Cambio aditivo sobre la 004:
      responses:
        "201":
          headers:
            Location:
              description: /v1/diary/entries/{id} de la entrada creada (research R3)
              schema: { type: string }

components:
  responses:
    QuickFoodListOk:
      description: Alimentos listos para añadir con un toque
      content:
        application/json:
          schema: { $ref: "#/components/schemas/QuickFoodList" }

  schemas:
    QuickFood:
      type: object
      required: [food, suggested_quantity, suggested_servings, last_used_at, is_favorite]
      properties:
        food: { $ref: "#/components/schemas/Food" }
        suggested_quantity: { type: number, exclusiveMinimum: 0, maximum: 10000 }
        suggested_servings: { type: [number, "null"], exclusiveMinimum: 0, maximum: 100 }
        last_used_at: { type: [string, "null"], format: date-time }
        is_favorite: { type: boolean }

    QuickFoodList:
      type: object
      required: [items]
      properties:
        items: { type: array, items: { $ref: "#/components/schemas/QuickFood" } }

    CopySourceEntry:
      type: object
      required: [food_name, food_brand, base_unit, quantity, servings, kcal]
      properties:
        food_name: { type: string }
        food_brand: { type: [string, "null"] }
        base_unit: { type: string, enum: [g, ml] }
        quantity: { type: number }
        servings: { type: [number, "null"] }
        kcal: { type: number, description: "Redondeado a entero, de la copia de la entrada" }

    CopySourceMeal:
      type: object
      required: [meal, entries, kcal, values_changed]
      properties:
        meal: { $ref: "#/components/schemas/Meal" }
        entries: { type: array, minItems: 1, items: { $ref: "#/components/schemas/CopySourceEntry" } }
        kcal: { type: number }
        values_changed:
          type: boolean
          description: Algún alimento disponible tiene hoy otros valores que la entrada (research R7)

    CopySourceDay:
      type: object
      required: [date, meals]
      properties:
        date: { type: string, format: date }
        meals:
          type: array
          minItems: 1
          maxItems: 5
          description: Primero la del mismo tipo que target_meal; luego en el orden fijo
          items: { $ref: "#/components/schemas/CopySourceMeal" }

    CopySourceList:
      type: object
      required: [days]
      properties:
        days: { type: array, maxItems: 14, items: { $ref: "#/components/schemas/CopySourceDay" } }

    DiaryCopyCreate:
      type: object
      additionalProperties: false
      required: [source_date, source_meal, target_date, target_meal]
      properties:
        source_date: { type: string, format: date }
        source_meal: { $ref: "#/components/schemas/Meal" }
        target_date: { type: string, format: date }
        target_meal: { $ref: "#/components/schemas/Meal" }

    DiaryCopyResult:
      type: object
      required: [copy_id, entry_ids, day]
      properties:
        copy_id: { type: string, format: uuid }
        entry_ids: { type: array, minItems: 1, items: { type: string, format: uuid } }
        day: { $ref: "#/components/schemas/DiaryDay" }

    ErrorCode:
      # + COPY_SOURCE_EMPTY, COPY_NOT_FOUND
```

## Ejemplos

`GET /v1/foods/recent`:

```json
{
  "items": [
    {
      "food": { "id": "…", "kind": "packaged", "name": "Pan de molde", "brand": "Bimbo",
                "barcode": "8410000000016", "base_unit": "g", "serving_size": 30,
                "per_100": { "kcal": 250, "protein_g": 8, "carbs_g": 46, "fat_g": 3.5, "…": "…" },
                "is_mine": false, "source": "off", "updated_at": "2026-11-20T10:00:00Z" },
      "suggested_quantity": 60,
      "suggested_servings": 2,
      "last_used_at": "2026-11-24T07:42:10Z",
      "is_favorite": false
    }
  ]
}
```

`POST /v1/diary/copies?utc_offset_min=60`:

```json
{ "source_date": "2026-11-23", "source_meal": "breakfast",
  "target_date": "2026-11-24", "target_meal": "breakfast" }
```

→ `201 { "copy_id": "…", "entry_ids": ["…", "…"], "day": { …DiaryDay… } }`
