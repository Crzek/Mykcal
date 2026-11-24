# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, que es el
que leen las pruebas de contrato. Esta feature le añade las rutas y los *schemas* de abajo, y el
código `FOOD_*` en `ErrorBody`. `info.version` pasa a `0.3.0`.

Todas las rutas nuevas exigen `bearerToken`, cuenta activa y consentimiento (research R14). No hay
rutas públicas nuevas.

## Resumen

| Método y ruta | Respuestas |
|---|---|
| `GET /v1/foods/search?q=` | `200 FoodSearchResult`, `400 VALIDATION_ERROR` |
| `GET /v1/foods/barcode?code=` | `200 BarcodeLookup`, `400 VALIDATION_ERROR`, `503 FOOD_SOURCE_UNAVAILABLE` |
| `GET /v1/foods/{food_id}` | `200 Food`, `404 FOOD_NOT_FOUND` |
| `GET /v1/foods/custom` | `200 CustomFoodList` |
| `POST /v1/foods/custom` | `201 CustomFoodSaved`, `400 VALIDATION_ERROR`, `409 FOOD_BARCODE_TAKEN` |
| `PUT /v1/foods/custom/{food_id}` | `200 CustomFoodSaved`, `400`, `404 FOOD_NOT_FOUND`, `409 FOOD_BARCODE_TAKEN` |
| `DELETE /v1/foods/custom/{food_id}` | `204`, `404 FOOD_NOT_FOUND` |

Todas pueden devolver además `401`, `403` (`ACCOUNT_NOT_REGISTERED`, `ACCOUNT_DISABLED`,
`CONSENT_REQUIRED`) y `503 AUTH_UNAVAILABLE`.

Códigos nuevos en `ErrorCode`: `FOOD_NOT_FOUND`, `FOOD_BARCODE_TAKEN`,
`FOOD_SOURCE_UNAVAILABLE`.

Los números decimales viajan como números JSON con 2 decimales como máximo. `null` en un
nutriente significa «sin dato».

## Fragmento OpenAPI

```yaml
paths:
  /v1/foods/search:
    get:
      summary: Busca alimentos por nombre (FR-004, FR-005)
      description: >
        Sin distinguir mayúsculas ni tildes. Devuelve hasta 20 resultados: primero los personalizados
        del usuario, después los genéricos y después los envasados ya consultados (research R6).
      parameters:
        - name: q
          in: query
          required: true
          schema: { type: string, minLength: 2, maxLength: 100 }
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/FoodSearchResult" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/foods/barcode:
    get:
      summary: Busca un producto por código de barras (FR-006–FR-010)
      description: >
        Orden: personalizado propio → copia local (≤ 30 días) → Open Food Facts (research R9).
        El código va en la query para que no quede en el registro de accesos.
      parameters:
        - name: code
          in: query
          required: true
          schema: { type: string, pattern: "^[0-9]{8}$|^[0-9]{12,14}$" }
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/BarcodeLookup" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503":
          description: >
            FOOD_SOURCE_UNAVAILABLE (Open Food Facts no responde y no hay copia local) o
            AUTH_UNAVAILABLE
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }

  /v1/foods/custom:
    get:
      summary: Lista los alimentos personalizados del usuario, por nombre
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/CustomFoodList" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    post:
      summary: Crea un alimento personalizado (FR-011–FR-014)
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/CustomFoodInput" }
      responses:
        "201":
          description: Creado
          content:
            application/json:
              schema: { $ref: "#/components/schemas/CustomFoodSaved" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "409":
          description: FOOD_BARCODE_TAKEN. El usuario ya tiene un alimento con ese código
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/foods/custom/{food_id}:
    parameters:
      - { name: food_id, in: path, required: true, schema: { type: string, format: uuid } }
    put:
      summary: Edita un alimento personalizado propio (no cambia el diario, FR-015)
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/CustomFoodInput" }
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/CustomFoodSaved" }
        "400": { $ref: "#/components/responses/ValidationError" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/FoodNotFound" }
        "409":
          description: FOOD_BARCODE_TAKEN
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    delete:
      summary: Elimina un alimento personalizado propio (borrado lógico)
      responses:
        "204": { description: Eliminado }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/FoodNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/foods/{food_id}:
    get:
      summary: Detalle de un alimento visible para el usuario
      parameters:
        - { name: food_id, in: path, required: true, schema: { type: string, format: uuid } }
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Food" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404": { $ref: "#/components/responses/FoodNotFound" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

components:
  responses:
    ValidationError:
      description: VALIDATION_ERROR, con los nombres de los campos en `fields` (nueva; la 002 lo declaraba en línea)
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }
    FoodNotFound:
      description: >
        FOOD_NOT_FOUND. No existe, está eliminado o es un personalizado de otro usuario (las tres
        situaciones responden igual)
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorBody" }

  schemas:
    Nutrients:
      type: object
      description: Valores por 100 g o 100 ml según base_unit. null = sin dato (FR-003)
      additionalProperties: false
      required: [kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, potassium_mg, calcium_mg,
                 iron_mg, magnesium_mg, vitamin_d_ug, vitamin_c_mg]
      properties:
        kcal: { type: number, minimum: 0, maximum: 900 }
        protein_g: { type: number, minimum: 0, maximum: 100 }
        carbs_g: { type: number, minimum: 0, maximum: 100 }
        fat_g: { type: number, minimum: 0, maximum: 100 }
        fiber_g: { type: [number, "null"], minimum: 0, maximum: 100 }
        sodium_mg: { type: [number, "null"], minimum: 0, maximum: 40000 }
        potassium_mg: { type: [number, "null"], minimum: 0, maximum: 10000 }
        calcium_mg: { type: [number, "null"], minimum: 0, maximum: 5000 }
        iron_mg: { type: [number, "null"], minimum: 0, maximum: 500 }
        magnesium_mg: { type: [number, "null"], minimum: 0, maximum: 2000 }
        vitamin_d_ug: { type: [number, "null"], minimum: 0, maximum: 1000 }
        vitamin_c_mg: { type: [number, "null"], minimum: 0, maximum: 5000 }

    FoodSummary:
      type: object
      additionalProperties: false
      required: [id, kind, name, brand, base_unit, kcal, is_mine]
      properties:
        id: { type: string, format: uuid }
        kind: { type: string, enum: [generic, packaged, custom] }
        name: { type: string }
        brand: { type: [string, "null"] }
        base_unit: { type: string, enum: [g, ml] }
        kcal: { type: number, description: kcal por 100 g/ml }
        is_mine: { type: boolean, description: true solo en los personalizados (US3.3) }

    FoodSearchResult:
      type: object
      additionalProperties: false
      required: [items]
      properties:
        items:
          type: array
          maxItems: 20
          items: { $ref: "#/components/schemas/FoodSummary" }

    Food:
      type: object
      additionalProperties: false
      required: [id, kind, name, brand, barcode, base_unit, per_100, serving_size, is_mine, source,
                 updated_at]
      properties:
        id: { type: string, format: uuid }
        kind: { type: string, enum: [generic, packaged, custom] }
        name: { type: string }
        brand: { type: [string, "null"] }
        barcode: { type: [string, "null"] }
        base_unit: { type: string, enum: [g, ml] }
        per_100: { $ref: "#/components/schemas/Nutrients" }
        serving_size: { type: [number, "null"], description: Ración en base_unit (FR-010) }
        is_mine: { type: boolean }
        source: { type: string, enum: [ciqual, "off", user] }
        updated_at: { type: string, format: date-time }

    BarcodeLookup:
      type: object
      additionalProperties: false
      required: [result, code]
      properties:
        result:
          type: string
          enum: [found, not_found, incomplete]
          description: >
            found: hay alimento utilizable. not_found: OFF no lo conoce (US2.3). incomplete: OFF lo
            conoce pero le faltan kcal o macros (US2.4). En los dos últimos la app ofrece crear
            un personalizado con el código.
        code: { type: string, description: Código normalizado (UPC-A → EAN-13) }
        food: { $ref: "#/components/schemas/Food", description: Solo con found }
        stale:
          type: boolean
          description: Solo con found; true si la copia local tiene más de 30 días y OFF no respondió
        product_name: { type: [string, "null"], description: Solo con incomplete, para precargar el formulario }
        brand: { type: [string, "null"], description: Solo con incomplete }

    CustomFoodInput:
      type: object
      additionalProperties: false
      required: [name, base_unit, basis, values]
      properties:
        name: { type: string, minLength: 1, maxLength: 120 }
        brand: { type: [string, "null"], maxLength: 80 }
        barcode: { type: [string, "null"], pattern: "^[0-9]{8}$|^[0-9]{12,14}$" }
        base_unit: { type: string, enum: [g, ml] }
        basis:
          type: string
          enum: [per_100, per_serving]
          description: Cómo vienen los valores. Con per_serving, serving_size es obligatorio (FR-013)
        serving_size: { type: [number, "null"], exclusiveMinimum: 0, maximum: 5000 }
        values:
          type: object
          additionalProperties: false
          required: [kcal, protein_g, carbs_g, fat_g]
          description: Valores por 100 o por ración según basis. Los opcionales ausentes o null = sin dato
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

    CustomFoodSaved:
      type: object
      additionalProperties: false
      required: [food, warnings]
      properties:
        food: { $ref: "#/components/schemas/Food" }
        warnings:
          type: array
          items: { type: string, enum: [KCAL_MISMATCH] }

    CustomFoodList:
      type: object
      additionalProperties: false
      required: [items]
      properties:
        items:
          type: array
          items: { $ref: "#/components/schemas/FoodSummary" }
```

## Notas

- `VALIDATION_ERROR` en `POST`/`PUT /v1/foods/custom` devuelve en `fields` los campos que fallan
  (por ejemplo `["fat_g"]` o `["protein_g","carbs_g","fat_g","fiber_g"]` si la suma pasa de 100),
  nunca los valores (R14 de la 002). La app pone el mensaje junto a cada campo.
- `GET /v1/foods/custom` se declara antes que `GET /v1/foods/{food_id}` en el router. Además,
  `food_id` es de tipo UUID, así que `custom` no puede confundirse con un id.
