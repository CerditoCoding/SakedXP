-- Texts. Spanish first (the author plays in Spanish), English for every other client.
local _, ns = ...

local es = {
    TITLE = "SakedMap",
    HELP = "/smap (mostrar/ocultar), /smap diag, /smap brujula (activa Rotar minimapa), /smap reset (me perdí), /smap test (prueba al aire libre), /smap olvidar (borra entradas aprendidas)",
    DIAG_HEADER = "Diagnóstico:",
    COMPASS = "Brújula del minimapa",
    FACING = "Orientación",
    CALIBRATION = "Calibración brújula",
    SUBZONE = "Subzona",
    DATA = "datos",
    ESTIMATE = "Estimación",
    NONE = "ninguna",
    YES = "sí", NO = "no",
    RESEEDED = "Buscando tu posición de nuevo en toda la mazmorra.",
    COMPASS_ON = "Rotar minimapa activado: la flecha usa la brújula del minimapa para saber hacia dónde mirás.",
    FORGOT = "Entradas aprendidas de esta mazmorra borradas.",
    LEARNED_ENTRANCE = "Aprendí un punto de entrada nuevo para esta mazmorra.",
    FOLLOW = "Seguir",
    FAINT = "Otros niveles",
    LEVEL = "Nivel",
    HINT = "Rueda: zoom · Arrastrar: mover · Clic medio: ver todo · Mayús+clic: estoy aquí",
    NO_FACING = "Sin orientación: activá Rotar minimapa (/smap brujula) y dejá el minimapa visible",
    FACING_COMPASS = "Orientación: brújula del minimapa",
    FACING_API = "Orientación: juego",
    LOCKED = "±%d yd",
    SEARCHING = "buscando… (caminá un poco)",
    NO_DATA = "Esta mazmorra todavía no tiene mapa en SakedMap.",
    TEST_ON = "Prueba al aire libre: caminá en línea recta, girá, retrocedé y caminá de costado. Cada 10 s comparo la estimación con tu posición real. /smap test para terminar.",
    TEST_OFF = "Prueba terminada.",
    TEST_LINE = "Prueba: recorrido %.0f yd, error %.1f yd (%.1f%%), orientación %s, ejes %s",
    TEST_INSTANCE = "La prueba solo funciona fuera de mazmorras (ahí el juego sí da la posición real).",
}

local en = {
    TITLE = "SakedMap",
    HELP = "/smap (toggle), /smap diag, /smap compass (turns Rotate Minimap on), /smap reset (I'm lost), /smap test (outdoor test), /smap forget (clear learned entrances)",
    DIAG_HEADER = "Diagnostics:",
    COMPASS = "Minimap compass",
    FACING = "Facing",
    CALIBRATION = "Compass calibration",
    SUBZONE = "Subzone",
    DATA = "data",
    ESTIMATE = "Estimate",
    NONE = "none",
    YES = "yes", NO = "no",
    RESEEDED = "Looking for you again across the whole dungeon.",
    COMPASS_ON = "Rotate Minimap on: the arrow reads the minimap compass to know where you face.",
    FORGOT = "Learned entrances for this dungeon cleared.",
    LEARNED_ENTRANCE = "Learned a new entrance point for this dungeon.",
    FOLLOW = "Follow",
    FAINT = "Other levels",
    LEVEL = "Level",
    HINT = "Wheel: zoom · Drag: pan · Middle click: fit · Shift+click: I'm here",
    NO_FACING = "No facing: turn on Rotate Minimap (/smap compass) and keep the minimap visible",
    FACING_COMPASS = "Facing: minimap compass",
    FACING_API = "Facing: game",
    LOCKED = "±%d yd",
    SEARCHING = "searching… (walk a little)",
    NO_DATA = "SakedMap has no map for this dungeon yet.",
    TEST_ON = "Outdoor test: walk straight, turn, back up and strafe. Every 10 s the estimate is compared with your real position. /smap test to stop.",
    TEST_OFF = "Test stopped.",
    TEST_LINE = "Test: walked %.0f yd, error %.1f yd (%.1f%%), facing %s, axes %s",
    TEST_INSTANCE = "The test only works outside dungeons (there the game gives the real position).",
}

local loc = GetLocale and GetLocale() or "enUS"
ns.L = (loc == "esES" or loc == "esMX") and es or en
setmetatable(ns.L, { __index = en })

BINDING_HEADER_SAKEDMAP = "SakedMap"
BINDING_NAME_SAKEDMAP_TOGGLE = ns.L == nil and "Toggle map" or (GetLocale and (GetLocale() == "esES" or GetLocale() == "esMX") and "Mostrar/ocultar mapa" or "Toggle map")
