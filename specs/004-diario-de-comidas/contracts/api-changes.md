# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, que es el
que leen las pruebas de contrato. Esta feature le añade las rutas y los *schemas* de abajo, un campo
en `Me` y dos códigos en `ErrorBody`. `info.version` pasa a `0.4.0`.

Todas las rutas nuevas exigen `bearerToken`, cuenta activa y consentimiento (research R11). No hay
rutas públicas nuevas.

## Resumen

| Método y ruta | Respuestas |
|---|---|
| `GET /v1/diary/days/{date}` | `200 DiaryDay`, `400 VALIDATION_ERROR` / `DIARY_DATE_OUT_OF_RANGE`, `404 TARGET_NOT_FOUND` |
| `POST /v1/diary/entries` | `201 DiaryDay`, `400`, `404 FOOD_NOT_FOUND` / `TARGET_NOT_FOUND` |
| `PATCH /v1/diary/entries/{entry_id}` | `200 DiaryDay`, `400 VALIDATION_ERROR`, `404 ENTRY_NOT_FOUND` |
| `DELETE /v1/diary/entries/{entry_id}` | `200 DiaryDay`, `404 ENTRY_NOT_FOUND` |
| `POST /v1/diary/entries/{entry_id}/restore` | `200 DiaryDay`, `404 ENTRY_NOT_FOUND` |

Todas pueden devolver además `401`, `403` (`ACCOUNT_NOT_REGISTERED`, `ACCOUNT_DISABLED`,
`CONSENT_REQUIRED`) y `503 AUTH_UNAVAILABLE`.

Todas reciben el parámetro de consulta `utc_offset_min` (entero, −840 a 840, obligatorio): el
desfase de la zona del móvil al final del día que se consulta o modifica (research R3).

Códigos nuevos en `ErrorCode`: `DIARY_DATE_OUT_OF_RANGE`, `ENTRY_NOT_FOUND`.

`Me` añade `registered_at` (obligatorio, `date-time`): primer día navegable (research R2).

Los decimales viajan como números JSON. `null` en un nutriente significa «sin dato».

## Fragmento OpenAPI

```yaml
paths:
  /v1/diary/days/{date}:
    get:
      summary: Día del diario con resumen y comidas (FR-006–FR-012)
      parameters:
        - { $ref: "#/components/parameters/DiaryDate" }
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      responses:
        "200": { $ref: "#/components/responses/DiaryDayOk" }
        "400": { $ref: "#/components/responses/DiaryBadRequest" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/TargetNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/entries:
    post:
      summary: Añade un alimento a una comida (FR-002–FR-004)
      description: >
        Copia el nombre y los valores por 100 del alimento (research R5). Lleva `quantity` o
        `servings`, nunca los dos. Responde con el día completo de `date`.
      parameters:
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/DiaryEntryCreate" }
      responses:
        "201": { $ref: "#/components/responses/DiaryDayOk" }
        "400": { $ref: "#/components/responses/DiaryBadRequest" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404":
          description: Alimento no disponible para el usuario o sin objetivo
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/entries/{entry_id}:
    patch:
      summary: Cambia la cantidad o la comida de una entrada (FR-005)
      description: >
        Solo dentro del mismo día. Los valores se recalculan con la copia guardada, no con el
        alimento actual (FR-004). Enviar `quantity` pone `servings` a null.
      parameters:
        - { $ref: "#/components/parameters/EntryId" }
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/DiaryEntryUpdate" }
      responses:
        "200": { $ref: "#/components/responses/DiaryDayOk" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/EntryNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    delete:
      summary: Borra una entrada; se puede deshacer (FR-005, research R8)
      parameters:
        - { $ref: "#/components/parameters/EntryId" }
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      responses:
        "200": { $ref: "#/components/responses/DiaryDayOk" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/EntryNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/diary/entries/{entry_id}/restore:
    post:
      summary: Deshace el borrado (hasta 60 s después)
      parameters:
        - { $ref: "#/components/parameters/EntryId" }
        - { $ref: "#/components/parameters/UtcOffsetMin" }
      responses:
        "200": { $ref: "#/components/responses/DiaryDayOk" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/EntryNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

components:
  parameters:
    DiaryDate:
      name: date
      in: path
      required: true
      schema: { type: string, format: date }
    EntryId:
      name: entry_id
      in: path
      required: true
      schema: { type: string, format: uuid }
    UtcOffsetMin:
      name: utc_offset_min
      in: query
      required: true
      schema: { type: integer, minimum: -840, maximum: 840 }

  responses:
    DiaryDayOk:
      description: Día completo y recalculado
      content:
        application/json:
          schema: { $ref: "#/components/schemas/DiaryDay" }
    DiaryBadRequest:
      description: "`VALIDATION_ERROR` o `DIARY_DATE_OUT_OF_RANGE`"
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    EntryNotFound:
      description: "`ENTRY_NOT_FOUND`: no existe, es de otro usuario o venció el plazo de deshacer"
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    TargetNotFound:
      description: "`TARGET_NOT_FOUND`"
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }

  schemas:
    Meal:
      type: string
      enum: [breakfast, lunch, afternoon_snack, dinner, snacks]

    DiaryEntryCreate:
      type: object
      additionalProperties: false
      required: [date, meal, food_id]
      properties:
        date: { type: string, format: date }
        meal: { $ref: "#/components/schemas/Meal" }
        food_id: { type: string, format: uuid }
        quantity: { type: number, exclusiveMinimum: 0, maximum: 10000, multipleOf: 0.1 }
        servings: { type: number, exclusiveMinimum: 0, maximum: 100, multipleOf: 0.01 }
      oneOf:
        - required: [quantity]
        - required: [servings]

    DiaryEntryUpdate:
      type: object
      additionalProperties: false
      minProperties: 1
      properties:
        meal: { $ref: "#/components/schemas/Meal" }
        quantity: { type: number, exclusiveMinimum: 0, maximum: 10000, multipleOf: 0.1 }
        servings: { type: number, exclusiveMinimum: 0, maximum: 100, multipleOf: 0.01 }
      not:
        required: [quantity, servings]

    DiaryEntry:
      type: object
      additionalProperties: false
      required: [id, meal, food_id, food_kind, food_name, food_brand, base_unit, serving_size,
                 per_100, quantity, servings, values, incomplete, created_at]
      properties:
        id: { type: string, format: uuid }
        meal: { $ref: "#/components/schemas/Meal" }
        food_id: { type: string, format: uuid }
        food_kind: { type: string, enum: [generic, packaged, custom] }
        food_name: { type: string }
        food_brand: { type: [string, "null"] }
        base_unit: { type: string, enum: [g, ml] }
        serving_size: { type: [number, "null"] }
        per_100:
          $ref: "#/components/schemas/Nutrients"
          description: Copia por 100 guardada al registrar; la app la usa para la vista previa al editar
        quantity: { type: number }
        servings: { type: [number, "null"] }
        values:
          $ref: "#/components/schemas/NutrientAmounts"
          description: Valores de la entrada (no por 100), redondeados para mostrar (research R10)
        incomplete:
          type: array
          items: { type: string }
          description: Nutrientes sin dato en esta entrada
        created_at: { type: string, format: date-time }

    NutrientAmounts:
      type: object
      description: >
        Cantidades de una entrada o de un total (no por 100), sin los máximos por 100 de
        `Nutrients`. En un total ninguno es null; en una entrada, un opcional es null si la copia
        no tenía el dato.
      additionalProperties: false
      required: [kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, potassium_mg, calcium_mg,
                 iron_mg, magnesium_mg, vitamin_d_ug, vitamin_c_mg]
      properties:
        kcal: { type: number, minimum: 0 }
        protein_g: { type: number, minimum: 0 }
        carbs_g: { type: number, minimum: 0 }
        fat_g: { type: number, minimum: 0 }
        fiber_g: { type: [number, "null"], minimum: 0 }
        sodium_mg: { type: [number, "null"], minimum: 0 }
        potassium_mg: { type: [number, "null"], minimum: 0 }
        calcium_mg: { type: [number, "null"], minimum: 0 }
        iron_mg: { type: [number, "null"], minimum: 0 }
        magnesium_mg: { type: [number, "null"], minimum: 0 }
        vitamin_d_ug: { type: [number, "null"], minimum: 0 }
        vitamin_c_mg: { type: [number, "null"], minimum: 0 }

    NutrientTotals:
      type: object
      additionalProperties: false
      required: [consumed, incomplete]
      properties:
        consumed: { $ref: "#/components/schemas/NutrientAmounts" }
        incomplete:
          type: array
          items: { type: string }
          description: Nutrientes con alguna entrada sin dato (FR-008)

    DiaryMeal:
      type: object
      additionalProperties: false
      required: [meal, entries, totals]
      properties:
        meal: { $ref: "#/components/schemas/Meal" }
        entries:
          type: array
          items: { $ref: "#/components/schemas/DiaryEntry" }
          description: En orden de creación
        totals: { $ref: "#/components/schemas/NutrientTotals" }

    DiaryDay:
      type: object
      additionalProperties: false
      required: [date, target, totals, remaining, meals]
      properties:
        date: { type: string, format: date }
        target:
          $ref: "#/components/schemas/TargetValues"
          description: Objetivo vigente al final de ese día (FR-011, research R3)
        totals: { $ref: "#/components/schemas/NutrientTotals" }
        remaining:
          type: object
          description: >
            objetivo − consumido, con los 12 nutrientes. Negativo = exceso. En el sodio, lo que
            queda hasta el máximo.
          additionalProperties: { type: number }
        meals:
          type: array
          minItems: 5
          maxItems: 5
          items: { $ref: "#/components/schemas/DiaryMeal" }
          description: Siempre las 5, en orden fijo (FR-001)
```

Notas:

- En `consumed` nada es `null`: un dato que falta cuenta como 0 y el nutriente aparece en
  `incomplete` (FR-008, mismo criterio que `sum_nutrients` de la 003). En `values` de una entrada,
  un opcional es `null` si la copia no lo tiene.
- `Me` añade `registered_at: { type: string, format: date-time }` a sus `required`.
- `ErrorCode` añade `DIARY_DATE_OUT_OF_RANGE` y `ENTRY_NOT_FOUND` a su `enum`.
