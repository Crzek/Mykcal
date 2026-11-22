# Contrato: configuración en Zitadel (`https://mg-zitadel.cruzerick.com`)

Lo que tiene que existir en la instancia, que ya está en funcionamiento. No se despliega ninguna
instancia nueva. Decisiones en research R2, R3 y R4.

## 0. Comprobación previa de la instancia

- [ ] **SMTP configurado** (*Default settings → SMTP*). Sin SMTP no llega el correo de
  verificación y el autorregistro no se completa.
- [ ] Ajustes OIDC de la instancia (compartidos con Ligón, **no se tocan**): access token 15 min,
  refresh 7 días sin uso y 30 días en total.

## 1. Organización `mykcal`

Es nueva y está separada de la de Ligón, para no abrir el registro allí.
`OIDC_ORG_ID` = ID de la organización.

### Política de inicio de sesión (*Organization → Settings → Login behavior*)

| Ajuste | Valor |
|---|---|
| Username/password allowed | sí |
| Register allowed | **sí** (opción A, R1) |
| Passwordless (passkeys) allowed | sí |
| External IdP allowed | no |
| Force MFA | no |
| Ignore unknown usernames | sí |

- **Política de contraseña**: la de la instancia por defecto.
- **Branding** (opcional): nombre «Mykcal» en la página de acceso.

## 2. Proyecto `mykcal` (en la organización `mykcal`)

| Ajuste | Valor |
|---|---|
| Assert roles on authentication | no |
| Check authorization on authentication | **no**, porque los autorregistrados no tienen grants (R3) |
| Check for project on authentication | no |

- No hay roles: el administrador sale de `ADMIN_SUBJECT` (R6).
- `OIDC_PROJECT_ID` = ID del proyecto.

### Aplicaciones nativas

| Ajuste | `mykcal-android` (prod) | `mykcal-android-dev` (dev) |
|---|---|---|
| Tipo | Native | Native |
| Auth method | PKCE | PKCE |
| Grant types | Authorization Code, Refresh Token | igual |
| Redirect URIs | `com.cruzerick.mykcal:/oauth2redirect` | `com.cruzerick.mykcal.dev:/oauth2redirect` |
| Post logout URIs | `com.cruzerick.mykcal:/logout` | `com.cruzerick.mykcal.dev:/logout` |
| Auth Token Type | **JWT** | **JWT** |
| Development mode | no | no |

El `client_id` de cada aplicación va en `OIDC_CLIENT_ID` de la app de su sabor. El backend no lo
necesita, porque valida por `aud` = ID del proyecto.

## 3. Usuario administrador

1. Con la app de prod (o desde la página de registro de la organización), Erick crea su usuario
   en la organización `mykcal`.
2. En la consola: *Users →* ese usuario *→* copiar **User ID**. Ese valor es `ADMIN_SUBJECT`.
3. El mismo valor vale para prod y para dev, porque los usuarios son compartidos.

## 4. Scopes que pide la app

```
openid profile email offline_access
urn:zitadel:iam:org:id:<OIDC_ORG_ID>
urn:zitadel:iam:org:project:id:<OIDC_PROJECT_ID>:aud
```

## 5. Endpoints usados

- **Backend**: `/.well-known/openid-configuration`, `jwks_uri` y `userinfo_endpoint`.
- **App**: `authorization_endpoint`, `token_endpoint`, `revocation_endpoint` y
  `end_session_endpoint`.

## Valores que no son secretos (van en `app/config/<sabor>.json` y en el entorno del backend)

`OIDC_ISSUER=https://mg-zitadel.cruzerick.com`, `OIDC_ORG_ID`, `OIDC_PROJECT_ID` y
`OIDC_CLIENT_ID` (uno por sabor).
