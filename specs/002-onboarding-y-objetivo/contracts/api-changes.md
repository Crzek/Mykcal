# Cambios de API

El contrato vivo sigue siendo `specs/001-acceso-y-despliegue/contracts/openapi.yaml`, porque las
pruebas de contrato lo leen. Esta feature le añade cinco rutas, amplía `Me` y `ErrorBody` y añade
los schemas de abajo. `info.version` pasa a `0.2.0`.

Todas las rutas nuevas exigen `bearerToken` y cuenta activa. Las de datos de salud exigen además
consentimiento (`data-model.md`, «Reglas de acceso»). No hay rutas públicas nuevas.

## Resumen

| Método y ruta | Consentimiento | Respuestas |
|---|---|---|
| `POST /v1/consent` | no | `201 Consent`, `409 CONSENT_VERSION_MISMATCH` |
| `GET /v1/profile` | sí | `200 Profile`, `404 PROFILE_NOT_FOUND` |
| `PUT /v1/profile` | sí | `200 ProfileSaved`, `400 VALIDATION_ERROR` |
| `GET /v1/target` | sí | `200 DailyTarget`, `404 TARGET_NOT_FOUND` |
| `PUT /v1/target` | sí | `200 DailyTarget`, `400 VALIDATION_ERROR`, `409 PROFILE_REQUIRED` |
| `POST /v1/target/recalculate` | sí | `200 DailyTarget`, `409 PROFILE_REQUIRED` |
| `POST /v1/me/deactivation` | no | `204` |

Además, todas pueden devolver `401`, `403` (`ACCOUNT_NOT_REGISTERED`, `ACCOUNT_DISABLED` y, en las
de salud, `CONSENT_REQUIRED`) y `503 AUTH_UNAVAILABLE`.

## Fragmento OpenAPI

```yaml
paths:
  /v1/consent:
    post:
      summary: Registra el consentimiento de datos de salud (FR-001–FR-003)
      description: >
        Idempotente para la misma versión. La hora la pone el servidor. Solo acepta la versión
        vigente del texto (research R8).
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [text_version]
              properties:
                text_version: { type: string, minLength: 1, maxLength: 32 }
      responses:
        "201":
          description: Consentimiento registrado (o ya existía con esa versión)
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Consent" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "409":
          description: CONSENT_VERSION_MISMATCH. La app envía una versión que el servidor no conoce
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/profile:
    get:
      summary: Perfil del usuario y su peso actual
      responses:
        "200":
          description: Perfil
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Profile" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404":
          description: PROFILE_NOT_FOUND
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    put:
      summary: Crea o actualiza el perfil (FR-004–FR-006) y aplica o propone el recálculo
      description: >
        La primera vez crea perfil, registro de peso y objetivo calculado en una transacción
        (research R11). Después, si cambian los datos del cálculo: recalcula si el objetivo es
        calculated o devuelve una propuesta sin guardarla si es manual (research R12).
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/ProfileInput" }
      responses:
        "200":
          description: Perfil guardado
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ProfileSaved" }
        "400":
          description: VALIDATION_ERROR con fields
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/target:
    get:
      summary: Objetivo diario vigente
      responses:
        "200":
          description: Objetivo vigente
          content:
            application/json:
              schema: { $ref: "#/components/schemas/DailyTarget" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "404":
          description: TARGET_NOT_FOUND
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }
    put:
      summary: Sobrescribe el objetivo a mano (FR-014)
      description: Guarda una versión manual con los 12 valores. Copia los datos del cálculo anterior.
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/TargetValues" }
      responses:
        "200":
          description: Nueva versión manual
          content:
            application/json:
              schema: { $ref: "#/components/schemas/DailyTarget" }
        "400":
          description: VALIDATION_ERROR con fields
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "409":
          description: PROFILE_REQUIRED. Aún no hay perfil ni objetivo
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/target/recalculate:
    post:
      summary: Recalcula con el perfil y el peso actuales (FR-016, aceptar propuesta)
      responses:
        "200":
          description: Nueva versión calculated
          content:
            application/json:
              schema: { $ref: "#/components/schemas/DailyTarget" }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "409":
          description: PROFILE_REQUIRED
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorBody" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

  /v1/me/deactivation:
    post:
      summary: Da de baja la cuenta (FR-018, FR-019)
      description: >
        Desactiva la cuenta de Mykcal y conserva los datos. No toca el usuario de Zitadel. La app
        cierra la sesión a continuación (research R15).
      responses:
        "204": { description: Cuenta desactivada }
        "401": { $ref: "#/components/responses/Unauthorized" }
        "403": { $ref: "#/components/responses/Forbidden" }
        "503": { $ref: "#/components/responses/AuthUnavailable" }

components:
  schemas:
    Me:
      # Se añade onboarding a required y a properties:
      properties:
        onboarding:
          type: string
          enum: [consent, profile, done]
          description: Paso pendiente del onboarding (research R10)

    Consent:
      type: object
      additionalProperties: false
      required: [text_version, accepted_at]
      properties:
        text_version: { type: string }
        accepted_at: { type: string, format: date-time }

    ProfileInput:
      type: object
      additionalProperties: false
      required: [age, sex, height_cm, weight_kg, activity_level, goal, measured_on]
      properties:
        age: { type: integer, minimum: 18, maximum: 100 }
        sex: { type: string, enum: [male, female] }
        height_cm: { type: integer, minimum: 100, maximum: 250 }
        weight_kg:
          type: number
          minimum: 30
          maximum: 300
          description: Con un decimal como máximo; el servidor valida con Decimal (research R14)
        activity_level: { type: string, enum: [sedentary, light, moderate, high, very_high] }
        goal: { type: string, enum: [lose_fat, maintain, gain_muscle] }
        measured_on:
          type: string
          format: date
          description: Fecha local del móvil para el registro de peso (research R6)

    Profile:
      type: object
      additionalProperties: false
      required: [age, sex, height_cm, weight_kg, weight_measured_on, activity_level, goal, updated_at]
      properties:
        age: { type: integer }
        sex: { type: string, enum: [male, female] }
        height_cm: { type: integer }
        weight_kg: { type: number, description: Peso del registro más reciente }
        weight_measured_on: { type: string, format: date }
        activity_level: { type: string, enum: [sedentary, light, moderate, high, very_high] }
        goal: { type: string, enum: [lose_fat, maintain, gain_muscle] }
        updated_at: { type: string, format: date-time }

    ProfileSaved:
      type: object
      additionalProperties: false
      required: [profile, target, recalculation]
      properties:
        profile: { $ref: "#/components/schemas/Profile" }
        target:
          $ref: "#/components/schemas/DailyTarget"
          description: Objetivo vigente tras guardar
        recalculation:
          type: object
          additionalProperties: false
          required: [status]
          properties:
            status:
              type: string
              enum: [created, applied, proposed, none]
              description: >
                created = primer objetivo; applied = recalculado automáticamente;
                proposed = objetivo manual, ver proposed; none = sin cambios en el cálculo
            previous:
              $ref: "#/components/schemas/TargetValues"
              description: Solo con applied; valores anteriores para mostrar el cambio
            proposed:
              $ref: "#/components/schemas/TargetValues"
              description: Solo con proposed; no se ha guardado

    TargetValues:
      type: object
      additionalProperties: false
      required: [kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, potassium_mg, calcium_mg,
                 iron_mg, magnesium_mg, vitamin_d_ug, vitamin_c_mg]
      properties:
        kcal: { type: integer, minimum: 1, maximum: 10000 }
        protein_g: { type: integer, minimum: 0, maximum: 1000 }
        carbs_g: { type: integer, minimum: 0, maximum: 2000 }
        fat_g: { type: integer, minimum: 0, maximum: 1000 }
        fiber_g: { type: integer, minimum: 0, maximum: 200 }
        sodium_mg: { type: integer, minimum: 0, maximum: 20000 }
        potassium_mg: { type: integer, minimum: 0, maximum: 20000 }
        calcium_mg: { type: integer, minimum: 0, maximum: 10000 }
        iron_mg: { type: integer, minimum: 0, maximum: 200 }
        magnesium_mg: { type: integer, minimum: 0, maximum: 5000 }
        vitamin_d_ug: { type: integer, minimum: 0, maximum: 500 }
        vitamin_c_mg: { type: integer, minimum: 0, maximum: 5000 }

    DailyTarget:
      type: object
      additionalProperties: false
      required: [values, source, effective_from, calculation]
      properties:
        values: { $ref: "#/components/schemas/TargetValues" }
        source: { type: string, enum: [calculated, manual] }
        effective_from: { type: string, format: date-time }
        calculation:
          type: object
          additionalProperties: false
          required: [weight_kg, age, sex, height_cm, activity_level, goal, calculated_at, notices]
          description: Datos usados en el último cálculo (FR-013)
          properties:
            weight_kg: { type: number }
            age: { type: integer }
            sex: { type: string, enum: [male, female] }
            height_cm: { type: integer }
            activity_level: { type: string, enum: [sedentary, light, moderate, high, very_high] }
            goal: { type: string, enum: [lose_fat, maintain, gain_muscle] }
            calculated_at: { type: string, format: date-time }
            notices:
              type: array
              items: { type: string, enum: [MIN_KCAL_APPLIED, CARBS_CLAMPED] }

    ErrorBody:
      # code.enum añade: CONSENT_REQUIRED, CONSENT_VERSION_MISMATCH, PROFILE_NOT_FOUND,
      #                  PROFILE_REQUIRED, TARGET_NOT_FOUND
      properties:
        fields:
          type: array
          items: { type: string }
          description: Solo con VALIDATION_ERROR; nombres de campo, nunca valores (research R14)
```

## Pruebas `privacy` afectadas

- `test_lista_publica_cerrada`: la lista de rutas no públicas pasa a incluir las siete nuevas.
- `ALLOW_WITHOUT_ACTIVE_ACCOUNT`: sin cambios. Todas las rutas nuevas exigen cuenta activa.
- **Nueva** `HEALTH_DATA_ROUTES`: lista cerrada de las rutas que exigen consentimiento. Una prueba
  comprueba que cada una responde `403 CONSENT_REQUIRED` sin consentimiento y no escribe nada.
  Otra comprueba que toda ruta nueva está en `HEALTH_DATA_ROUTES` o en la lista
  `NO_CONSENT_NEEDED = {POST /v1/consent, POST /v1/me/deactivation, GET /v1/me, POST /v1/registration, /v1/admin/*}`.
- **Nueva**: aislamiento. El usuario A no puede leer ni modificar el perfil, el peso ni el objetivo
  de B (no hay identificadores en las rutas, pero se comprueba que cada consulta filtra por
  `user_id`).
