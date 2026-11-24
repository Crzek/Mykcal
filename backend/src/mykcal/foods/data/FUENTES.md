# Fuentes de los alimentos genéricos

`generic_foods.csv` se genera con `backend/scripts/build_generic_seed.py` a partir de CIQUAL y de
la selección curada en `backend/data/ciqual/ciqual_es.csv`. No se edita a mano.

## Atribución

> Anses. Table de composition nutritionnelle des aliments Ciqual.
> <https://ciqual.anses.fr>

- **Edición**: CIQUAL 2025 (ficheros `alim_`, `const_` y `compo_` de noviembre de 2025).
- **Licencia**: la edición 2025 se publica en Zenodo (registro 17550133) bajo **CC BY 4.0**; las
  ediciones anteriores, en data.gouv.fr bajo Licence Ouverte. Las dos exigen citar la fuente.
- **Cambios de Mykcal**: los nombres están traducidos al español, se añadieron sinónimos para la
  búsqueda y la selección de unos 360 alimentos es de Mykcal. Los valores nutricionales no se
  modifican: se toman de CIQUAL (`parse_cell` de `mykcal/foods/ciqual.py` convierte las trazas y
  «< x» en 0 y deja sin dato los campos vacíos o «-»).

## Cómo actualizar

1. Descargar la edición nueva de CIQUAL fuera de git (por ejemplo `~/datos/ciqual/`).
2. Revisar `backend/data/ciqual/ciqual_es.csv` (el script falla si un código ya no existe o le
   faltan kcal o macros).
3. Regenerar: `cd backend && uv run python scripts/build_generic_seed.py ~/datos/ciqual/
   data/ciqual/ciqual_es.csv src/mykcal/foods/data/generic_foods.csv`.
4. Cambiar `ciqualEdition` en `app/lib/features/settings/data_sources_screen.dart`.
5. Al desplegar, `python -m mykcal.foods.load_generic` detecta el cambio (hash SHA-256), actualiza
   los alimentos y archiva los que ya no están.
