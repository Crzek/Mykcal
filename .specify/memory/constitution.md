<!--
Sync Impact Report
- Version change: 1.2.0 → 1.2.1 (PATCH: aclaración de una restricción técnica; no cambia ningún
  principio)
- Cambios en 1.2.1:
  - Restricciones técnicas → Alimentos: la base genérica pasa de «BEDCA, licencia a verificar» a
    «CIQUAL (Anses) traducida al español»: decisión de Erick en la 003, porque CIQUAL se publica
    con licencia abierta (CC BY 4.0 en la edición 2025; Licence Ouverte en las anteriores) y
    ficheros descargables, y BEDCA no
  - Se añade la obligación de citar la fuente en la app (pantalla «Fuentes de datos»)
- Principios añadidos o eliminados: ninguno
- Plantillas: no se modifican (leen la constitución en tiempo de ejecución)
- Historial 1.2.0 — Version change: 1.1.1 → 1.2.0 (MINOR: se redefine el modelo de entornos; no se elimina ni
  renombra ningún principio)
- Cambios en 1.2.0:
  - Solo existe un entorno desplegado: producción (`main`). Se elimina el entorno de desarrollo
    desplegado
  - `dev` pasa a ser solo rama de integración, sin despliegue propio
  - Principio IX: una feature se da por cerrada al desplegarse desde `main` y probar sus flujos
    en el móvil; antes de fusionar, pruebas automáticas y, si hace falta, backend local
  - Restricciones técnicas → Despliegue: una Application y un PostgreSQL de Dokploy, solo en
    producción
  - Flujo de trabajo → Ramas y entornos reescrito
- Principios añadidos o eliminados: ninguno
- Plantillas: no se modifican (leen la constitución en tiempo de ejecución)
- TODOs diferidos: ninguno. Acciones de otras features (fuera de la constitución): retirar el
  entorno dev de `specs/001-acceso-y-despliegue/contracts/dokploy-setup.md`, de
  `docs/deploy/produccion.md` y del sabor `dev` de la app si ya no se usa
- Historial 1.1.1 — aclaraciones derivadas del plan de 001: rutas sin identidad, despliegue con
  Application + PostgreSQL de Dokploy, código de invitación gatea el alta de Mykcal
- Historial 1.1.0 — sección "Ramas y entornos" (main = producción, dev = desarrollo)
- Historial 1.0.0 — principios I–X definidos
-->

# Mykcal Constitution

## Core Principles

### I. La IA propone, el usuario confirma

- Ningún resultado de la IA (alimentos identificados, gramos estimados) se guarda en el diario
  sin que el usuario lo revise y lo confirme explícitamente.
- Si el análisis de la IA falla o no se completa, la foto queda como borrador y el usuario MUST
  poder continuar a mano.
- La respuesta de la IA MUST validarse contra un esquema estructurado (JSON con alimentos y
  gramos) antes de mostrarse; una respuesta inválida se trata como fallo.

**Razón**: la IA identifica bien los platos pero estima mal las cantidades; la precisión sale de
la confirmación del usuario.

### II. La base de alimentos es la única fuente nutricional

- Los valores nutricionales (kcal, macros, micros) MUST salir siempre de la base de alimentos
  (genérica, envasada o personalizada), nunca directamente de la IA.
- La IA solo propone qué alimentos hay y cuántos gramos; cada alimento propuesto MUST cruzarse
  con la base o sustituirse por uno de la base o por un alimento personalizado.

**Razón**: los valores de la IA no son fiables ni reproducibles; los de la base sí.

### III. La IA es opcional

- La app MUST ser plenamente usable sin clave de IA: registro por código de barras, búsqueda
  manual, recientes, favoritos, resumen y peso funcionan sin ella.
- Sin clave, la función de foto aparece desactivada con acceso a la guía para obtenerla.
- El acceso a la IA MUST quedar detrás de una interfaz de proveedor que permita añadir otros
  proveedores además de Gemini sin cambiar el resto del sistema.

**Razón**: muchos usuarios no tendrán clave; la foto es un añadido, no un requisito.

### IV. Privacidad y datos de salud (NON-NEGOTIABLE)

- Sin un consentimiento explícito registrado (con fecha) MUST NOT guardarse ningún dato de salud
  del usuario.
- Las fotos de comida MUST NOT guardarse en el servidor: se procesan en memoria y se descartan
  tras el análisis. Solo quedan en el móvil del usuario.
- La clave de IA de cada usuario MUST guardarse cifrada a nivel de aplicación con una clave
  maestra que vive en una variable de entorno, nunca en la base de datos.
- Ninguna respuesta del servidor MUST incluir la clave de IA de un usuario; las llamadas a la IA
  se hacen desde el backend con la clave descifrada en memoria.

**Razón**: se tratan datos de salud de personas cercanas; una fuga de la base de datos no debe
exponer claves ni fotos.

### V. Aislamiento por usuario y seguridad

- El 100% de los endpoints MUST exigir una identidad válida (JWT de Zitadel validado contra el
  JWKS); sin identidad la respuesta es un rechazo. Únicas excepciones: `/v1/health` y la descarga
  pública del APK (`/descargar/mykcal.apk`), que no devuelven datos de usuario; una prueba
  automática fija esa lista de rutas públicas.
- Los usuarios se identifican por el `sub` del token.
- Todo acceso a datos MUST filtrarse por el usuario autenticado; ningún usuario puede leer ni
  modificar datos de otro, incluido el administrador salvo que una spec lo apruebe expresamente.
- Las cuentas desactivadas MUST NOT poder operar.

**Razón**: aislamiento simple, verificable y sin roles de acceso a datos de terceros.

### VI. Cálculos deterministas y pruebas sin servicios reales

- Los cálculos del objetivo diario (gasto, ajuste por objetivo, macros, micros, recálculo por
  peso) MUST ser funciones puras y deterministas, cubiertas por pruebas con casos conocidos.
- Las pruebas MUST NOT usar claves reales ni llamar a Gemini ni a Open Food Facts: usan
  respuestas guardadas (fixtures).
- Las reglas de privacidad y aislamiento (principios IV y V) MUST tener pruebas automáticas.

**Razón**: un error de cálculo invalida la app; las pruebas deben ser reproducibles y gratuitas.

### VII. Simplicidad

- El sistema sirve a un máximo de 50 usuarios. MUST NOT añadirse piezas de infraestructura
  (colas, cachés externas, microservicios, réplicas) sin una necesidad medida y documentada en
  el plan.
- Ante dos soluciones, se elige la más simple que cumpla la spec (YAGNI).

**Razón**: plazo de ~60 h y un único mantenedor.

### VIII. Accesible, en español y métrica

- La interfaz está en español con todos los textos externalizados para traducir más adelante.
- MUST cumplir WCAG 2.1 AA en contraste, respetar el tamaño de texto del sistema y etiquetar
  todos los controles para el lector de pantalla.
- Tema claro y oscuro según el ajuste del sistema.
- Todas las unidades son métricas: kg, cm, g, ml y kcal.

**Razón**: usable por todo el círculo, sin conversiones ni barreras.

### IX. Entrega vertical y desplegada

- Cada feature MUST terminar con algo usable en el móvil (APK).
- Antes de fusionar a `main`, la feature MUST pasar sus pruebas automáticas; no hay entorno de
  desarrollo desplegado, así que lo que necesite un backend real se prueba en local.
- Una feature se da por cerrada tras desplegarse en Dokploy desde `main` y probar sus flujos en
  el móvil.

**Razón**: avanzar en incrementos reales y comprobables, no en capas a medias.

### X. Observabilidad sin contenido sensible

- El 100% de los errores del servidor MUST quedar registrados.
- Cada llamada a la IA MUST registrarse con usuario, resultado y causa del fallo si la hay.
- Los registros MUST NOT contener fotos, respuestas de la IA, claves ni tokens.

**Razón**: poder depurar sin crear otra copia de datos sensibles.

## Restricciones técnicas

- **App**: Flutter, solo Android en el MVP, distribuida como APK por enlace. Requiere conexión;
  sin ella avisa y no pierde lo que el usuario está escribiendo.
- **Backend**: Python con FastAPI y PostgreSQL, en un monorepo con la app.
- **Despliegue**: Dokploy, con una Application (Dockerfile) y un servicio PostgreSQL de Dokploy.
  Solo existe el entorno de producción, que se despliega desde `main`; Docker Compose solo en
  local. Secretos (clave maestra, credenciales) en variables
  de entorno de Dokploy.
- **Autenticación**: instancia autoalojada de Zitadel, proyecto nuevo; Flutter con PKCE (patrón
  de Ligón) y backend validando el JWT contra el JWKS. El alta de la cuenta de Mykcal solo es
  posible con el código de invitación vigente: el usuario puede existir en Zitadel sin él, pero
  sin cuenta de Mykcal ninguna función opera.
- **IA**: Google Gemini como único proveedor en el MVP; cada usuario aporta su propia clave.
- **Alimentos**: base genérica CIQUAL (Anses, licencia abierta) traducida al español e importada
  en PostgreSQL, con la fuente citada en la app; productos envasados desde Open Food Facts por
  código de barras, con caché local.
- **Datos**: baja = desactivar la cuenta, sin borrado; sin copias de seguridad (riesgos
  aceptados por Erick y documentados en el brief).

## Flujo de trabajo

- Cada feature sigue Spec Kit: spec → (clarify) → plan → tareas → implementación, en el orden
  de features del brief (001 a 007).
- Las preguntas abiertas que afecten a una feature MUST resolverse antes de su plan.
- El plan de cada feature MUST incluir un "Constitution Check" que verifique los principios
  I–X y justifique cualquier excepción en la tabla de complejidad.
- Implementación con Claude Code; documentación actual de librerías vía Context7.

### Ramas y entornos

- `main` es **producción** y el único entorno desplegado: lo que hay en `main` es lo que está
  desplegado para los usuarios. Nunca se hace commit directo en `main`.
- `dev` es la rama de **integración**: reúne las features terminadas. No tiene despliegue propio.
- Cada feature (spec) nace en su propia rama creada desde `dev`, con el mismo nombre que su
  directorio de spec (por ejemplo, `001-acceso-y-despliegue`).
- Una feature se une a `dev` cuando cumple su spec, pasa sus pruebas automáticas y es usable en el
  móvil (principio IX).
- `dev` se une a `main` cuando el conjunto está probado; ese merge es la publicación a producción
  y MUST hacerse con los textos definitivos (por ejemplo, el del consentimiento).
- Flujo: `feature` → `dev` → `main`. Los arreglos urgentes siguen el mismo camino.
- Si el plazo aprieta, las épicas P2 y P3 son las primeras en recortarse.

## Governance

- Esta constitución prevalece sobre cualquier otra práctica del proyecto.
- Las enmiendas se hacen con `/speckit-constitution`, quedan documentadas en el informe de
  impacto y requieren la aprobación de Erick.
- Versionado semántico: MAJOR para eliminar o redefinir principios; MINOR para añadir principios
  o secciones; PATCH para aclaraciones de redacción.
- Cada plan y cada revisión de código MUST comprobar el cumplimiento; las excepciones se
  justifican por escrito en el plan.

**Version**: 1.2.1 | **Ratified**: 2026-11-22 | **Last Amended**: 2026-11-24
