# SakedMap

Addon para **WoW Forever** que muestra el mapa de la mazmorra con una **flecha estimada de dónde estás**. Resalta la sala actual, atenúa los demás niveles y la flecha sigue al personaje.

Dentro de las mazmorras el juego no le da a los addons tu posición ni tu orientación: `UnitPosition`, `C_Map.GetPlayerMapPosition` y `GetPlayerFacing` devuelven nil desde el parche 7.1, y Forever mantiene esa regla. SakedMap reconstruye la posición con lo que el cliente sí entrega:

| Dato | De dónde sale |
|---|---|
| Velocidad | `GetUnitSpeed("player")` (si en combate viene "secreta", usa la última velocidad de carrera conocida) |
| Dirección del paso | ganchos en `MoveForwardStart`, `StrafeLeftStart`, `MoveBackwardStart`, autorun… (adelante, atrás, de costado, diagonal) |
| Hacia dónde mirás | la rotación de la **brújula del minimapa** (`MinimapCompassTexture:GetRotation()`) con **Rotar minimapa** activado. La calibra solo al aire libre, comparándola con `GetPlayerFacing()` |
| Paredes, escaleras, pisos | el suelo caminable de la mazmorra, sacado de su geometría (WMO) en grilla de 2 yardas con todas las alturas por celda |
| En qué sala estás | `GetSubZoneText()` comparado con los nombres de sala del juego (en español también) |
| Dónde empezás | los puntos de entrada de cada mazmorra, verificados contra el suelo, más los que el addon aprende |

Todo eso alimenta un **filtro de partículas**: cientos de hipótesis de posición que se mueven con tus pasos. Las que atraviesan paredes o caen en una sala con otro nombre pierden peso; lo que sobrevive es tu posición. Es la "mejor matemática" que el del video decía que le faltaba: en vez de solo sumar velocidad × dirección (que se va desviando), las paredes y los nombres de sala corrigen el error todo el tiempo.

## Instalación

1. Copiá la carpeta `SakedMap` a `World of Warcraft\_forever_\Interface\AddOns\`.
2. Entrá al juego y escribí `/smap brujula`. Activa **Rotar minimapa**, que es lo que permite saber hacia dónde mirás dentro de la mazmorra. También podés activarlo desde Modo Edición → Minimapa.
3. Dejá el **minimapa visible**: si está oculto, la brújula deja de girar.

## Uso

- Al entrar a una mazmorra con datos, el mapa se abre solo.
- **Rueda**: zoom · **Arrastrar**: mover · **Clic medio**: ver todo · **Clic derecho**: volver a seguir la flecha.
- **Mayús + clic** en el mapa: "estoy aquí". Corrige la posición al instante; si lo hacés justo al entrar, además aprende esa entrada.
- Botones **1, 2, 3…**: niveles de la mazmorra. Con **Seguir** activado, el nivel cambia solo.
- La flecha se ve semitransparente mientras busca y sólida cuando está segura; el anillo amarillo muestra la incertidumbre.

Comandos:

| Comando | Qué hace |
|---|---|
| `/smap` | mostrar u ocultar el mapa (también tiene atajo de teclado en Opciones → Atajos → AddOns) |
| `/smap diag` | muestra qué datos entrega el juego: brújula, orientación, velocidad, subzona, estimación |
| `/smap brujula` | activa Rotar minimapa |
| `/smap reset` | "me perdí": busca tu posición de nuevo en toda la mazmorra |
| `/smap test` | **prueba al aire libre** (abajo) |
| `/smap olvidar` | borra las entradas aprendidas de la mazmorra actual |
| `/smap debug` | dibuja las partículas del filtro |

## Probarlo sin entrar a mazmorras

Afuera el juego sí da la posición real, así que `/smap test` usa la misma lectura de movimiento que la flecha (velocidad, teclas, orientación) y cada 10 segundos compara la estimación con tu posición verdadera. Caminá recto, girá, retrocedé y caminá de costado: debería marcar un error de pocas yardas por cada 100 recorridas. Mientras jugás al aire libre con Rotar minimapa activado, el addon también calibra la brújula sola.

Después, la primera vez que entres a una mazmorra, `/smap diag` te dice si la brújula responde ahí dentro. Girá y volvé a ejecutarlo: el valor tiene que cambiar.

## Mazmorras incluidas

16 mazmorras:

- **Un solo WMO** (11): Ragefire Chasm, Wailing Caverns, Blackfathom Deeps, Stormwind Stockade, Gnomeregan, Uldaman, Maraudon, Sunken Temple, **Blackrock Depths**, **Blackrock Spire** y **Dire Maul**.
- **Terreno + edificios** (5): **Stratholme**, **Scholomance**, **Blackmaw Hold**, **The Shaper's Terrace** y **Alcaz Prison**. Usan el relieve del terreno, los edificios ubicados en él y el nombre de subzona de cada parcela de terreno al aire libre.

Faltan las de nivel bajo que también mezclan terreno: Hall of Thanes, Ruins of Lordaeron, Deadmines, Shadowfang Keep, Excavation Site: Wetlands, Razorfen Kraul, City of Dalaran, Scarlet Monastery, Razorfen Downs, The Drowned City, Krol'dok Stronghold y Zul'Farrak. Las raids tampoco están. Se agregan sumando su ID a `tools/build.py`.

Blackmaw Hold, The Shaper's Terrace y Alcaz Prison no tienen un punto de entrada conocido. La primera vez el addon te busca en toda la mazmorra, ayudado por los nombres de subzona. En Alcaz eso alcanza: en simulación se ubica solo en 8 a 21 segundos. En las dos al aire libre puede tardar o no ubicarte, así que la primera vez conviene hacer **Mayús+clic donde aparecés apenas entrás**; el addon aprende esa entrada para las próximas.

En Alcaz Prison el terreno de la superficie se descarta: es una tapa unas 20 yardas por encima de toda la cárcel subterránea.

## Precisión esperada

En simulación, caminando rutas reales sobre el suelo de cada mazmorra (`tests/sim.lua`) y con la orientación de la brújula, partiendo de la entrada, el error mediano es de **1 a 5 yardas** en las mazmorras con entrada conocida (Stratholme y Scholomance: alrededor de 2 yardas). La estimación se asegura en 5 a 45 segundos. Sin orientación (brújula apagada u oculta), el filtro no logra ubicarte y el addon te lo avisa en la barra de abajo.

Lo que la simulación no cubre y puede empeorar la estimación en el juego: empujones y knockbacks, cargas o teletransportes dentro de la mazmorra, y quedarte trabado contra mobs. Para eso están Mayús+clic y `/smap reset`.

## ¿Es legal? ¿Me pueden banear?

- **No es ilegal.** Es un addon que corre dentro del cliente y usa solo la API de Lua que Blizzard expone. No lee la memoria del juego, no intercepta tráfico de red y no automatiza nada: muestra información y vos decidís qué hacer.
- **Encaja en las reglas de addons.** Blizzard permite mostrar información y prohíbe automatizar acciones o modificar el cliente, y esto no hace ninguna de las dos cosas.
- **Riesgo real:** la lectura de la brújula del minimapa es un hueco que Blizzard podría cerrar en un parche, como ya hizo con otras lecturas del minimapa en Forever. Si pasa, la flecha deja de funcionar (el addon lo detecta y te avisa); no hay motivo de baneo por usar la API de addons.
- **Los datos de los mapas** (IDs de archivo de las texturas, coordenadas, nombres de salas) se generaron desde las tablas públicas del juego (wago.tools). El addon no incluye ninguna imagen de Blizzard: le pide al propio cliente sus texturas del minimapa por ID.

## Para desarrolladores

- `tools/build.py`: genera `SakedMap/Data/M<mapID>.lua` (suelo, salas, texturas, niveles, entradas) desde los datos del build `1.60.1.71139`. Descarga y cachea en `tools/.cache`.
- `tools/verify_tiles.py`: comprueba la ubicación de las texturas del minimapa contra la geometría (98–99% de coincidencia).
- `tools/preview.py`: dibuja el mapa generado en PNG (`--floors`, `--level N`, `--path ruta.csv`).
- `tools/floormap.py`: el mismo mapa con el suelo caminable teñido y las entradas marcadas.
- `tests/run.sh`: pruebas unitarias, prueba de humo con una imitación de la API de WoW (`tests/wowstub.lua`) y simulaciones en las 11 mazmorras. Necesita `lua5.1`.

Datos verificados durante la construcción:
- Mundo de la instancia = WMO rotado 180° (x → −x, y → −y). Los disparadores de área del cliente caen exactamente sobre el suelo solo con esa transformación (BRS, BRD, Dire Maul).
- WMO ubicados sobre terreno (MODF): mundo = (32 parcelas − pos.z, 32 parcelas − pos.x, pos.y), giro = rot.y + 180°. Las cajas transformadas coinciden con los límites que guarda el propio juego, y en Stratholme las dos entradas y los dos disparadores del cliente caen sobre el suelo generado.
- En los mapas de terreno solo se guarda el suelo alcanzable a pie desde los edificios de la mazmorra y sus entradas, más las subzonas con nombre. El terreno de esos mapas sigue por kilómetros, y las puertas o muros invisibles del juego no están en la geometría.
- Texturas del minimapa por sala: 2 píxeles por yarda, bloques de 128 yardas desde la esquina mínima de la sala, con el eje derecho de la imagen = +x del WMO y el eje hacia abajo = −y.
- Entradas: 13 de 15 puntos de aparición conocidos caen sobre suelo generado (a ≤0,2 yardas de altura); los otros 2 se descartaron.
