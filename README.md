# SakedXP

Guías de nivelación 1-60 para **WoW Forever**: rutas automáticas por zona, flecha de navegación, detección de cadenas y prerrequisitos, selector de zonas, checklist de mazmorras y guías de profesiones.

## Instalar con WowUp (se actualiza solo)

1. Instalá [WowUp](https://wowup.io).
2. Si no detecta WoW Forever, en **Opciones → Instalaciones** agregá la carpeta `World of Warcraft\_forever_`.
3. En **Obtener addons → Instalar desde URL** pegá el link de este repositorio.
4. Cuando haya una versión nueva, WowUp muestra **Actualizar**.

## Instalar a mano

Descargá el `.zip` de la última versión en **Releases** y descomprimilo en `World of Warcraft\_forever_\Interface\AddOns\`.

## Recomendado

- **QuestieDB**: sin él sólo funcionan las guías escritas a mano (no las rutas automáticas ni la flecha a NPCs).
- **ForeverDungeonJournal**: para el checklist de mazmorras.

## Comandos

`/sxp` · `/sxp ruta` · `/sxp zonas` · `/sxp prof` · `/sxp flecha` · `/sxp config`

## Publicar una versión (para quien mantiene el addon)

1. Subí `## Version:` en `SakedXP.toc`.
2. `git commit -am "v0.3.1"` y `git tag v0.3.1`
3. `git push && git push --tags`

GitHub Actions arma el `.zip` y crea la release; WowUp la detecta sola.
