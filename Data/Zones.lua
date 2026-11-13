-- SakedXP · Zone data (WoW Forever, 1-60)
-- Sources: Blizzard/Wowhead Forever data as collected by BindOnForever,
-- ForeverChanges and Forever Dungeon Journal (Nov 2026), plus classic data.
-- faction: "A" Alliance, "H" Horde, "C" contested (both).
-- guides: keywords matched against SakedXP guide names.
-- mapID: UiMap ID, used by the automatic route generator.

local _, S = ...

local Z = {}
S.Zones = Z

local function zone(t) Z[#Z + 1] = t; return t end

---------------------------------------------------------------------------
-- 1-12: starting zones
---------------------------------------------------------------------------
local function starter(t)
    t.pros = t.pros or { "Misiones de clase y de raza", "Todo cerca: aprendés los controles sin caminar mucho" }
    t.cons = t.cons or { "Zona compartida con muchos personajes nuevos" }
    t.dungeons = t.dungeons or {}
    t.rares = t.rares or {}
    t.professions = t.professions or { "Entrenadores de nivel aprendiz en la capital cercana" }
    t.vendors = t.vendors or { "Vendedor general, reparación y posada en el pueblo principal" }
    return zone(t)
end

starter { id = "elwynn", name = "Elwynn Forest", nameES = "Bosque de Elwynn", mapID = 1429, levels = { 1, 12 }, faction = "A",
    guides = { "Elwynn", "Northshire" }, hub = "Abadía de Villanorte → Villadorada", gathering = "Minería: Cobre · Herboristería: Flor de paz, Hojaplata",
    rares = { { "Mother Fang" }, { "Morgaine the Sly" }, { "Fedfennel" }, { "Gruff Swiftbite" }, { "Hogger", "Élite de misión" } } }
starter { id = "dunmorogh", name = "Dun Morogh", nameES = "Dun Morogh", mapID = 1426, levels = { 1, 12 }, faction = "A",
    guides = { "Dun Morogh", "Coldridge" }, hub = "Valle de Crestanevada → Kharanos", gathering = "Minería: Cobre · Herboristería: Flor de paz, Hojaplata",
    rares = { { "Timber" }, { "Old Icebeard" }, { "Gibblewilt" }, { "Bjarn" } } }
starter { id = "teldrassil", name = "Teldrassil", nameES = "Teldrassil", mapID = 1438, levels = { 1, 12 }, faction = "A",
    guides = { "Teldrassil", "Shadowglen" }, hub = "Cañada Umbría → Dolanaar", gathering = "Herboristería: Flor de paz, Hojaplata, Marregal",
    rares = { { "Duskstalker" }, { "Fury Shelda" }, { "Grimmaw" } } }
starter { id = "durotar", name = "Durotar", nameES = "Durotar", mapID = 1411, levels = { 1, 12 }, faction = "H",
    guides = { "Durotar" }, hub = "Valle de los Retos → Aldea Razor Hill", gathering = "Minería: Cobre · Herboristería: Flor de paz, Hojaplata, Raíz de tierra",
    rares = { { "Death Flayer" }, { "Felweaver Scornn" }, { "Warlord Kolkanis" }, { "Captain Flat Tusk" } } }
starter { id = "mulgore", name = "Mulgore", nameES = "Mulgore", mapID = 1412, levels = { 1, 12 }, faction = "H",
    guides = { "Mulgore" }, hub = "Campamento Narache → Poblado Pezuña de Sangre", gathering = "Minería: Cobre · Herboristería: Flor de paz, Hojaplata, Raíz de tierra",
    rares = { { "Snagglespear" }, { "Mazzranache" }, { "Ghost Howl" }, { "The Rake" } } }
starter { id = "tirisfal", name = "Tirisfal Glades", nameES = "Claros de Tirisfal", mapID = 1420, levels = { 1, 12 }, faction = "H",
    guides = { "Tirisfal" }, hub = "Camposanto → Rémol", gathering = "Minería: Cobre · Herboristería: Flor de paz, Hojaplata",
    dungeons = { { name = "Ruinas de Lordaeron (nuevo)", levels = "15-22", note = "Bajo Entrañas." } },
    rares = { { "Maggot Eye" }, { "Fellicent's Shade" }, { "Muad" }, { "Sri'skulk" } } }
starter { id = "zephras", name = "Zephras Isle", nameES = "Isla Zephras", mapID = 2521, new = true, levels = { 1, 12 }, faction = "C",
    guides = { "Zephras" }, hub = "Aldea Thendal → Aldea Shen'dar → Valanaar",
    access = "Zona de inicio de los Skyborne (requiere el paquete Heroico o superior).", onlyRace = "Skyborne",
    pros = { "Zona nueva y completa para los Skyborne (1-12)", "Misiones bien agrupadas en tres hubs" },
    cons = { "Sólo para Skyborne", "Sin mazmorra" },
    gathering = "Datos de nodos aún sin confirmar" }

---------------------------------------------------------------------------
-- 10-25
---------------------------------------------------------------------------
zone {
    id = "westfall", name = "Westfall", nameES = "Páramos de Poniente", mapID = 1436,
    levels = { 10, 20 }, faction = "A", guides = { "Westfall" },
    hub = "Colina del Centinela (posada, vuelo, reparación)",
    dungeons = { { name = "Las Minas de la Muerte", levels = "17-26", note = "Entrada en Villa Oscura; muchas misiones en Colina del Centinela." } },
    pros = { "Cadena larga de la Hermandad Defias con buena recompensa", "Misiones agrupadas cerca de Colina del Centinela", "Muy cerca de Ventormenta para entrenar" },
    cons = { "Zonas de recolección dispersas (granjas)", "Mucha competencia en servidores llenos" },
    professions = { "Ventormenta a un paso: todos los entrenadores" },
    vendors = { "Posada y vendedor general en Colina del Centinela", "Granjero Saldean: comida" },
    rares = { { "Foe Reaper 4000", "Gólem en los campos" }, { "Leprithus", "Sólo de noche" }, { "Sargento Brashclaw" }, { "Brack" } },
    gathering = "Herboristería: Hojaplata, Brezospina, Raíz de tierra · Minería: Cobre, Estaño",
}

zone {
    id = "lochmodan", name = "Loch Modan", nameES = "Loch Modan", mapID = 1432,
    levels = { 10, 20 }, faction = "A", guides = { "Loch Modan" },
    hub = "Thelsamar (posada, vuelo)",
    dungeons = { { name = "Sala de los Thanes (nuevo)", levels = "13-20", note = "Bajo Forjaz. Cadena 'Old Ironforge Incursion'." } },
    pros = { "Compacta y rápida", "Buena minería de cobre/estaño", "Cerca de Forjaz" },
    cons = { "Pocas misiones al final (17+)", "Tenés que seguir a Páramos u Orilla Oscura" },
    professions = { "Forjaz cerca: todos los entrenadores" },
    vendors = { "Thelsamar: posadero, vendedor general, reparación" },
    rares = { { "Lord Condar" }, { "Grawmug" }, { "Shanda la Hilandera" }, { "Large Loch Crocolisk" } },
    gathering = "Minería: Cobre, Estaño · Herboristería: Hojaplata, Brezospina",
}

zone {
    id = "darkshore", name = "Darkshore", nameES = "Costa Oscura", mapID = 1439,
    levels = { 11, 20 }, faction = "A", guides = { "Darkshore" },
    hub = "Auberdine (posada, vuelo, barco a Menethil)",
    dungeons = {},
    pros = { "Muchísimas misiones para 14-21", "Una sola ciudad: rutas cortas", "Pesca y cocina fáciles" },
    cons = { "Zona alargada: mucho caminar", "Sin mazmorra propia" },
    professions = { "Auberdine: Pesca y Cocina (mariscos)", "Darnassus para el resto" },
    vendors = { "Auberdine: posadero, vendedor general, comida" },
    rares = { { "Lady Vespia" }, { "Firecaller Radison" }, { "Licillin" }, { "Grimclaw" } },
    gathering = "Herboristería: Hojaplata, Brezospina, Marregal · Minería: Cobre, Estaño",
}

zone {
    id = "barrens", name = "The Barrens", nameES = "Los Baldíos", mapID = 1413,
    levels = { 10, 25 }, faction = "H", guides = { "Barrens" },
    hub = "El Cruce (posada, vuelo) · Trinquete (barco)",
    dungeons = {
        { name = "Cuevas de los Lamentos", levels = "15-24", note = "Oasis del norte." },
        { name = "Horado Rajacieno", levels = "29-38", note = "Sur de los Baldíos." },
        { name = "Zahúrda Rajacieno", levels = "37-46", note = "Frontera con Las Mil Agujas." },
    },
    pros = { "Zona enorme con misiones para 10 niveles", "Tres mazmorras con misiones", "Hub central muy cómodo" },
    cons = { "Muchas caminatas largas", "Algunas misiones de élite (Kolkar, Durotar)" },
    professions = { "Orgrimmar y Cima del Trueno cerca", "Trinquete: Pesca" },
    vendors = { "El Cruce: posadero, vendedor general, reparación" },
    rares = { { "Humar el Orgulloso" }, { "Takk el Saltador" }, { "Brokespear" }, { "Hermana Rathtalon" }, { "Snort el Burlón" } },
    gathering = "Herboristería: Hojaplata, Raíz de tierra, Marregal · Minería: Cobre, Estaño",
}

zone {
    id = "silverpine", name = "Silverpine Forest", nameES = "Bosque de Argénteos", mapID = 1421,
    levels = { 10, 20 }, faction = "H", guides = { "Silverpine" },
    hub = "El Sepulcro (posada, vuelo)",
    dungeons = {
        { name = "Castillo de Colmillo Oscuro", levels = "20-30", note = "Al sur del bosque." },
        { name = "Ruinas de Lordaeron (nuevo)", levels = "15-22", note = "Bajo Entrañas. Misiones en El Sepulcro y Entrañas." },
    },
    pros = { "Cerca de Entrañas", "Misiones compactas alrededor del Sepulcro" },
    cons = { "Pocas misiones después de 18" },
    professions = { "Entrañas: todos los entrenadores" },
    vendors = { "El Sepulcro: posadero, vendedor general" },
    rares = { { "Gorefang" }, { "Old Vicejaw" }, { "Krethis Shadowspinner" }, { "Snarlmane" } },
    gathering = "Herboristería: Hojaplata, Marregal · Minería: Cobre, Estaño",
}

zone {
    id = "redridge", name = "Redridge Mountains", nameES = "Montañas Crestagrana", mapID = 1433,
    levels = { 15, 25 }, faction = "A", guides = { "Redridge" },
    hub = "Villa del Lago (posada, vuelo)",
    dungeons = {},
    pros = { "Cerca de Villa del Lago, misiones rápidas", "Conecta con Riverglades por el norte" },
    cons = { "Muchas misiones de matar orcos Roca Negra" },
    professions = { "Ventormenta cerca" },
    vendors = { "Villa del Lago: posadero, panadero, reparación" },
    rares = { { "Kazon" }, { "Squiddic" }, { "Rohh el Silencioso" }, { "Ribchaser" }, { "Boulderheart" } },
    gathering = "Minería: Cobre, Estaño, Plata · Herboristería: Brezospina, Marregal",
}

zone {
    id = "stonetalon", name = "Stonetalon Mountains", nameES = "Sierra Espolón", mapID = 1442,
    levels = { 15, 27 }, faction = "C", guides = { "Stonetalon" },
    hub = "Roca del Sol (H) · Refugio Piedrahonda (A)",
    dungeons = {},
    pros = { "Buen complemento para Baldíos/Vallefresno", "Cadena de los goblins Venture Co." },
    cons = { "Terreno montañoso, rutas lentas" },
    professions = {},
    vendors = { "Roca del Sol: posadero, vendedor general" },
    rares = { { "Hermana Riven" }, { "Hermano Ravenoak" }, { "Taskmaster Whipfang" }, { "Pridewing Patriarch" } },
    gathering = "Minería: Estaño, Plata, Hierro · Herboristería: Brezospina, Marregal, Hierba cardenal",
}

zone {
    id = "ashenvale", name = "Ashenvale", nameES = "Vallefresno", mapID = 1440,
    levels = { 18, 30 }, faction = "C", guides = { "Ashenvale" },
    hub = "Astranaar (A) · Puesto del Hachazo (H)",
    dungeons = { { name = "Cavernas de Brazanegra", levels = "24-32", note = "Costa de Zoram." } },
    pros = { "Muchas misiones para ambas facciones", "Mazmorra con misiones en la zona" },
    cons = { "PvP en servidores JcJ", "Hubs separados" },
    professions = {},
    vendors = { "Astranaar / Hachazo: posadero, vendedor general" },
    rares = { { "Akkrilus" }, { "Ursol'lok" }, { "Rorgish Jowl" }, { "Terrowulf Packlord" }, { "Prince Raze" } },
    gathering = "Herboristería: Marregal, Hierba cardenal, Pálida · Minería: Estaño, Plata, Hierro",
}

---------------------------------------------------------------------------
-- 20-35
---------------------------------------------------------------------------
zone {
    id = "wetlands", name = "Wetlands", nameES = "Los Humedales", mapID = 1437,
    levels = { 20, 30 }, faction = "A", guides = { "Wetlands" },
    hub = "Puerto de Menethil (posada, vuelo, barcos)",
    dungeons = { { name = "Sitio de Excavación: Humedales (nuevo)", levels = "26-33", note = "Requiere 'Dragonmaw Rumors' (Zaruk, Sentinela Hammerfall) para la Horda." } },
    pros = { "Nueva mazmorra con buenas recompensas", "Conecta Forjaz con Trabalomas" },
    cons = { "Algunas misiones de élite (Dun Modr)", "Zona muy plana y larga" },
    professions = { "Menethil: Pesca; Forjaz cerca" },
    vendors = { "Menethil: posadero, vendedor general, reparación, panadero" },
    rares = { { "Ma'ruk Wyrmscale" }, { "Leech Widow" }, { "Dragonmaw Battlemaster" }, { "Garneg Charskull" }, { "Gnawbone" } },
    gathering = "Herboristería: Marregal, Hierba cardenal · Minería: Estaño, Hierro, Plata",
}

zone {
    id = "duskwood", name = "Duskwood", nameES = "Bosque del Ocaso", mapID = 1431,
    levels = { 18, 32 }, faction = "A", guides = { "Duskwood" },
    hub = "Villa Oscura (posada, vuelo)",
    dungeons = {},
    pros = { "Cadenas con mucha historia y XP alta", "Hub central, rutas cortas" },
    cons = { "Mor'Ladim (élite) y misiones de grupo", "Arañas y lobos agresivos" },
    professions = {},
    vendors = { "Villa Oscura: posadero, vendedor general, reparación" },
    rares = { { "Mor'Ladim", "Élite de misión" }, { "Naraxis" }, { "Lupos" }, { "Commander Felstrom" }, { "Fenros" } },
    gathering = "Herboristería: Marregal, Hierba cardenal, Musgo de tumba · Minería: Estaño, Hierro",
}

zone {
    id = "hillsbrad", name = "Hillsbrad Foothills", nameES = "Laderas de Trabalomas", mapID = 1424,
    levels = { 20, 32 }, faction = "C", guides = { "Hillsbrad" },
    hub = "Costasur (A) · Molino Tarren (H)",
    dungeons = {},
    pros = { "Muchas misiones para ambas facciones", "Puerta a Arathi y Alterac" },
    cons = { "PvP constante entre Costasur y Tarren", "Algunas misiones de élite (Yetis, Ro'Bark)" },
    professions = { "Costasur: Pesca, Cocina" },
    vendors = { "Costasur / Molino Tarren: posadero, vendedor general" },
    rares = { { "Big Samras" }, { "Ro'Bark" }, { "Lady Zephris" }, { "Creepthess" }, { "Ricter" } },
    gathering = "Herboristería: Marregal, Hierba cardenal, Musgo de tumba · Minería: Estaño, Hierro, Plata",
}

zone {
    id = "needles", name = "Thousand Needles", nameES = "Las Mil Agujas", mapID = 1441,
    levels = { 25, 35 }, faction = "C", guides = { "Thousand Needles", "Shimmering Flats" },
    hub = "Gran Elevador · Campamento Pezuña Libre (H) · Llanos Centelleantes (neutral)",
    dungeons = { { name = "Zahúrda Rajacieno", levels = "37-46", note = "En la frontera norte." } },
    pros = { "Llanos Centelleantes: misiones neutrales muy rentables", "Carreras goblin/gnomo" },
    cons = { "Muchos escalones entre mesetas", "Hub de la Alianza limitado" },
    professions = {},
    vendors = { "Llanos Centelleantes: posada goblin, reparación" },
    rares = { { "Achellios el Desterrado" }, { "Silithid Ravager" }, { "Ironeye el Invencible" }, { "Vile Sting" } },
    gathering = "Herboristería: Hierba cardenal, Pálida · Minería: Hierro, Plata",
}

zone {
    id = "arathi", name = "Arathi Highlands", nameES = "Tierras Altas de Arathi", mapID = 1417,
    levels = { 30, 40 }, faction = "C", guides = { "Arathi" },
    hub = "Refugio de la Zaga (A) · Sentinela Hammerfall (H)",
    dungeons = {},
    pros = { "Buenas misiones de 30-36", "Doctor Gregory Victor (H): Primeros auxilios artesano" },
    cons = { "Elites en el Círculo de Atadura", "Hubs en extremos opuestos" },
    professions = { "Hammerfall (H): Peletería elemental (Brumn Winterhoof)", "Hammerfall (H): Primeros auxilios artesano" },
    vendors = { "Refugio de la Zaga / Hammerfall: posadero, reparación" },
    rares = { { "Foulbelly" }, { "Kovork" }, { "Molok el Destructor" }, { "Prince Nazjak" }, { "Nimar el Asesino" } },
    gathering = "Minería: Hierro, Oro, Mitril · Herboristería: Hierba cardenal, Pálida, Mostacho de Khadgar",
}

zone {
    id = "alterac", name = "Alterac Mountains", nameES = "Montañas de Alterac", mapID = 1416,
    levels = { 30, 40 }, faction = "C", guides = { "Alterac", "Dalaran" },
    hub = "Sin hub: misiones desde Trabalomas · Dalaran (nuevo)",
    dungeons = { { name = "Ciudad de Dalaran (nueva)", levels = "28-33", note = "Entrada por las alcantarillas; Ranath Nightstride en la posada." } },
    pros = { "Nueva mazmorra de Dalaran", "Yetis y ogros con buena XP" },
    cons = { "Muchos élites en Ruinas de Alterac", "Sin posada propia" },
    professions = {},
    vendors = { "Dalaran: posada (Ranath Nightstride)" },
    rares = { { "Lo'Grosh" }, { "Gravis Slipknot" }, { "Cranky Benj" } },
    gathering = "Minería: Hierro, Plata, Oro · Herboristería: Pálida, Mostacho de Khadgar",
}

zone {
    id = "desolace", name = "Desolace", nameES = "Desolace", mapID = 1443,
    levels = { 30, 40 }, faction = "C", guides = { "Desolace" },
    hub = "Atalaya de Nijel (A) · Campamento Sombraolvido (H)",
    dungeons = { { name = "Maraudon", levels = "45-52", note = "Al sur; misiones de Shen'dralas también te llevan ahí." } },
    pros = { "Reputación con centauros (Magram/Gelkis)", "Acceso a Shen'dralas" },
    cons = { "Zona grande y vacía", "Kodos y centauros agresivos" },
    professions = {},
    vendors = { "Nijel / Sombraolvido: posadero, vendedor general" },
    rares = { { "Hissperak" }, { "Prince Kellen" }, { "Lord Azrethoc" } },
    gathering = "Minería: Hierro, Oro, Mitril · Herboristería: Pálida, Mostacho de Khadgar",
}

zone {
    id = "stv", name = "Stranglethorn Vale", nameES = "Vega de Tuercespina", mapID = 1434,
    levels = { 30, 45 }, faction = "C", guides = { "Stranglethorn", "STV" },
    hub = "Bahía del Botín (neutral) · Campamento Rebelde (A) · Grom'gol (H)",
    dungeons = { { name = "La Ciudad Sumergida (nueva)", levels = "35-40", note = "Bajo el agua al oeste del Arrecife Vil (Hondonada Sumergida)." } },
    pros = { "Cantidad enorme de misiones", "Bahía del Botín: comerciantes de recetas, pesca", "Cacería de Hemet Nesingwary" },
    cons = { "PvP intenso", "Páginas de Hemet y rutas largas" },
    professions = { "Bahía del Botín: Pesca (Old Man Heming), Ingeniería gnómica (Oglethorpe)", "Grom'gol/Bahía (H): Peletería tribal (Se'Jib)" },
    vendors = { "Bahía del Botín: recetas de cocina, patrones, fuegos artificiales, armas", "Comerciantes Velasangre" },
    rares = { { "King Bangalash" }, { "Kurmokk" }, { "Verifonix" }, { "Roloch" }, { "Scale Belly" }, { "Lord Sakrasis" } },
    gathering = "Minería: Hierro, Oro, Mitril · Herboristería: Mostacho de Khadgar, Vidarraíz",
}

---------------------------------------------------------------------------
-- 35-45 (incluye zonas nuevas)
---------------------------------------------------------------------------
zone {
    id = "riverglades", name = "Riverglades", nameES = "Riverglades", mapID = 2548, new = true,
    levels = { 36, 44 }, faction = "C", guides = { "Riverglades" },
    hub = "Bastión Farholde (A) · Rog'mar (H) · Puerto Powderfuse (neutral)",
    access = "Desde Crestagrana por el camino norte, o en el barco Steamwheedle desde Puerto Steamwheedle (Tanaris).",
    dungeons = { { name = "Fortaleza Krol'dok (nueva)", levels = "40-45", note = "Cueva a la izquierda de la piedra de reunión, sobre Sunnyglade (37.5, 37.3). Corré una vez por la XP de misiones." } },
    pros = { "~170 misiones: podés quedarte 8 niveles en una sola zona", "Hubs completos (posada, banco, vuelo, entrenadores)", "Cadena del Martillo Crepuscular que abre la mazmorra", "Nuevas misiones del Anillo de Bloodmaster (H)" },
    cons = { "Zona nueva: rutas todavía sin optimizar", "Muchas misiones de élite (Ghostmaw, Kilgar, Snargl)", "Zona contestada: PvP" },
    professions = {
        "Herrería: Alphonse Dumas (A, Farholde) · Gur'dok (H, Rog'mar)",
        "Encantamiento: Melanie Sable (A, Farholde)",
        "Ingeniería: Melbin Powderfuse (Puerto Powderfuse)",
        "Cocina: Gorg (H) · Minería: Grungle · Pesca: Krix",
    },
    vendors = {
        "Suministros: Herrería (Mika Darby), Ingeniería (Kor'gar), Sastrería (Stitch Pinwizzle)",
        "Componentes: Marla Bell · Venenos: Krikshank · Bienes comerciables: Gilliwigs",
        "Cocina: Miranda Turner · Carnicero: Naluk · Pescadera: Gritta Chumwater",
        "Mercado negro: Mister Graphed / Madam Swyndle · Bienes raros: Dorb",
        "Armero: Fizzix Boomshot · Instructor de armas: Ember Bladewhisper",
    },
    rares = {
        { "Gul'gash", "Raro élite nv 49" }, { "Twilight Forgemaster", "Raro élite nv 46" },
        { "Scaldaron", "Raro élite nv 43" }, { "Mad Marrius", "Raro élite nv 41" },
        { "Ghostmaw", "Élite nv 42 (misión WANTED)" }, { "Old Rot-Chum", "Élite nv 42 (misión WANTED)" },
        { "Executioner Morg", "Élite nv 46" }, { "Krek the Noxious", "Élite nv 42" },
    },
    gathering = "Datos de nodos aún sin confirmar · se espera Hierro/Mitril y hierbas de rango 150-225",
}

zone {
    id = "shendralas", name = "Shen'dralas", nameES = "Shen'dralas", mapID = 2652, new = true,
    levels = { 38, 45 }, faction = "C", guides = { "Shen'dralas", "Shendralas" },
    hub = "Templo de Shen'dralas (Magister Kirandis) · Mirador de Evenshade",
    access = "Extremo sur de Desolace, siguiendo el Valle de los Huesos hacia el sur.",
    dungeons = {
        { name = "Maraudon", levels = "45-52", note = "Misiones de Shen'dralas te envían ahí." },
        { name = "Zahúrda Rajacieno", levels = "37-46", note = "Misiones de Shen'dralas te envían ahí." },
    },
    pros = { "Zona corta (~38 misiones) para ambas facciones", "Combina bien con Desolace y Feralas", "Sin competencia de facción" },
    cons = { "Sin ruta de vuelo propia", "Pocas misiones: no alcanza para más de 2-3 niveles" },
    professions = { "Peletería: Jarael", "Sastrería: Melanori" },
    vendors = { "Bienes comerciables: Maralus · Comida: Naria · Bebida: Arondel", "Herrero (reparación): Vindael · Posadero: Adarien" },
    rares = {
        { "Magram Necrokhan", "nv 45" }, { "Corpsefeeder", "nv 45 (inicia misión)" },
        { "Outcast Necrokhan", "nv 45" }, { "Kog'thug the Brave", "nv 43, Bristleback Retreat (72.6, 31.4)" },
        { "Nascent Pylon Protector", "nv 43" },
    },
    gathering = "Datos de nodos aún sin confirmar",
}

zone {
    id = "dustwallow", name = "Dustwallow Marsh", nameES = "Marjal Revolcafango", mapID = 1445,
    levels = { 35, 45 }, faction = "C", guides = { "Dustwallow" },
    hub = "Theramore (A) · Refugio Brackenwall (H)",
    dungeons = { { name = "Prisión de Alcaz (nueva)", levels = "48-53", note = "Isla de Alcaz, noreste del marjal; el portal está en el sótano." } },
    pros = { "Nueva mazmorra en la isla de Alcaz", "Nat Pagle: Pesca artesano", "Theramore (A): Primeros auxilios artesano" },
    cons = { "Dragones negros y élites en el sur", "Ciénaga lenta de recorrer" },
    professions = { "Theramore (A): Primeros auxilios artesano (Dr. Gustaf VanHowzen)", "Nat Pagle: misiones de Pesca" },
    vendors = { "Theramore: todos los servicios · Brackenwall: posada, reparación" },
    rares = { { "Brimgore" }, { "Darkmist Widow" }, { "Garn Mathers" } },
    gathering = "Herboristería: Mostacho de Khadgar, Vidarraíz · Minería: Hierro, Mitril",
}

zone {
    id = "badlands", name = "Badlands", nameES = "Tierras Inhóspitas", mapID = 1418,
    levels = { 35, 45 }, faction = "C", guides = { "Badlands" },
    hub = "Kargath (H) · Sin hub de Alianza",
    dungeons = { { name = "Uldaman", levels = "38-48", note = "Este de la zona; cadena de los discos titánicos." } },
    pros = { "Uldaman con muchas misiones", "Minería excelente" },
    cons = { "Pocas misiones para la Alianza", "Zona árida y abierta" },
    professions = { "Kargath (H): Peletería de dragontinas (Thorkaf Dragoneye)" },
    vendors = { "Kargath: posadero, reparación" },
    rares = { { "Broken Tooth", "Mascota de cazador muy buscada" }, { "Anathemus" }, { "Rumbler" }, { "Zaricotl" }, { "Siege Golem" } },
    gathering = "Minería: Hierro, Oro, Mitril, Veraplata",
}

zone {
    id = "swamp", name = "Swamp of Sorrows", nameES = "Pantano de las Penas", mapID = 1435,
    levels = { 35, 45 }, faction = "C", guides = { "Swamp of Sorrows" },
    hub = "Stonard (H)",
    dungeons = { { name = "Templo de Atal'Hakkar", levels = "49-56", note = "En el centro del pantano." } },
    pros = { "Corta y complementa bien Tierras Inhóspitas/Riverglades" },
    cons = { "Sin hub de Alianza", "Pocas misiones" },
    professions = {},
    vendors = { "Stonard: todos los servicios (H)" },
    rares = { { "Lord Captain Wyrmak" }, { "Gilmorian" }, { "Fingat" }, { "Molt Thorn" } },
    gathering = "Herboristería: Vidarraíz, Sangrerreal · Minería: Hierro, Mitril",
}

---------------------------------------------------------------------------
-- 40-55
---------------------------------------------------------------------------
zone {
    id = "feralas", name = "Feralas", nameES = "Feralas", mapID = 1444,
    levels = { 40, 50 }, faction = "C", guides = { "Feralas" },
    hub = "Bastión Plumaluna (A) · Campamento Mojache (H)",
    dungeons = { { name = "La Masacre (Dire Maul)", levels = "55-60", note = "Este, Oeste y Norte." } },
    pros = { "Muchas misiones bien pagadas", "Acceso a La Masacre" },
    cons = { "Bastión Plumaluna está en una isla", "Gnolls y ogros élite en Masacre" },
    professions = { "Plumaluna (A): Peletería tribal (Caryssia Moonhunter)" },
    vendors = { "Plumaluna / Mojache: posadero, vendedor general" },
    rares = { { "Old Grizzlegut" }, { "Antilus the Soarer" }, { "Lord Shalzaru" }, { "Arash-ethis" }, { "Snarler" } },
    gathering = "Herboristería: Sangrerreal, Hojasueño, Sansam dorado · Minería: Mitril, Veraplata",
}

zone {
    id = "tanaris", name = "Tanaris", nameES = "Tanaris", mapID = 1446,
    levels = { 40, 50 }, faction = "C", guides = { "Tanaris" },
    hub = "Gadgetzan (neutral)",
    dungeons = { { name = "Zul'Farrak", levels = "43-50", note = "Noroeste del desierto." } },
    pros = { "Gadgetzan neutral con todos los servicios", "Barco a Riverglades (Puerto Steamwheedle)", "Zul'Farrak con buenas misiones" },
    cons = { "Desierto enorme", "Piratas élite en la costa" },
    professions = { "Gadgetzan: Ingeniería goblin (Nixx Sprocketspring)" },
    vendors = { "Gadgetzan: posada, banco, subasta neutral, recetas" },
    rares = { { "Cyclok the Mad" }, { "Kregg Keelhaul" }, { "Murderous Blisterpaw" }, { "Omgorn the Lost" }, { "Warleader Krazzilak" } },
    gathering = "Minería: Mitril, Veraplata · Herboristería: Flor de fuego",
}

zone {
    id = "hinterlands", name = "The Hinterlands", nameES = "Tierras del Interior", mapID = 1425,
    levels = { 41, 50 }, faction = "C", guides = { "Hinterlands" },
    hub = "Nido Aquilino (A) · Bastión Revantusk (H)",
    dungeons = {},
    pros = { "Misiones de trols y grifos con buena XP" },
    cons = { "Trols élite en Jintha'Alor", "Lejos de las capitales" },
    professions = {},
    vendors = { "Nido Aquilino / Revantusk: posadero, reparación" },
    rares = { { "Jalinde Summerdrake" }, { "Mith'rethis the Enchanter" }, { "Old Cliff Jumper" }, { "Witherheart the Stalker" }, { "Grimungous" } },
    gathering = "Herboristería: Sangrerreal, Hojasueño · Minería: Mitril, Veraplata",
}

zone {
    id = "searing", name = "Searing Gorge", nameES = "La Garganta de Fuego", mapID = 1427,
    levels = { 43, 50 }, faction = "C", guides = { "Searing Gorge" },
    hub = "Punta Torio (Hermandad del Torio)",
    dungeons = { { name = "Montaña Roca Negra", levels = "52-60", note = "Profundidades y Cumbre de Roca Negra." } },
    pros = { "Reputación con la Hermandad del Torio", "Puerta a Roca Negra" },
    cons = { "Pocas misiones", "Llegar es incómodo" },
    professions = { "Peletería elemental (A): Sarah Tanner" },
    vendors = { "Punta Torio: vendedores de la Hermandad" },
    rares = { { "Highlord Mastrogonde" }, { "Faulty War Golem" }, { "Scald" }, { "Shleipnarr" } },
    gathering = "Minería: Mitril, Veraplata, Torio · Hierro oscuro dentro de Roca Negra",
}

zone {
    id = "azshara", name = "Azshara", nameES = "Azshara", mapID = 1447,
    levels = { 45, 55 }, faction = "C", guides = { "Azshara" },
    hub = "Talrendis (A) · Campamento Valormok (H)",
    dungeons = { { name = "Bastión Fauces Negras (nuevo)", levels = "55-60", note = "Puerta furbolg al norte; túnel largo hacia Winterspring." } },
    pros = { "Nueva mazmorra de nivel alto", "Peletería de dragontinas (A): Peter Galen" },
    cons = { "Pocas misiones", "Lejos de todo" },
    professions = { "Peletería de dragontinas (A): Peter Galen" },
    vendors = { "Talrendis / Valormok: servicios básicos" },
    rares = { { "Monnos the Elder" }, { "Lady Sesspira" }, { "Antilos" } },
    gathering = "Herboristería: Hojasueño, Sansam dorado · Minería: Mitril, Torio",
}

zone {
    id = "blasted", name = "Blasted Lands", nameES = "Las Tierras Devastadas", mapID = 1419,
    levels = { 45, 55 }, faction = "C", guides = { "Blasted Lands" },
    hub = "Bastión Nethergarde (A)",
    dungeons = {},
    pros = { "Misiones de entrega (colmillos, glándulas) que dan buffs", "XP rápida combinada con STV/Swamp" },
    cons = { "Mucho farmeo de objetos" },
    professions = {},
    vendors = { "Nethergarde: posadero, reparación" },
    rares = { { "Akubar the Seer" }, { "Clack the Reaver" }, { "Deatheye" }, { "Magronos the Unyielding" }, { "Grunter" } },
    gathering = "Herboristería: Flor de fuego, Musgo de tumba · Minería: Mitril, Torio",
}

zone {
    id = "ungoro", name = "Un'Goro Crater", nameES = "Cráter de Un'Goro", mapID = 1449,
    levels = { 48, 55 }, faction = "C", guides = { "Un'Goro", "UnGoro" },
    hub = "Refugio de Marshal (neutral)",
    dungeons = { { name = "Terraza del Modelador (nueva)", levels = "58-60", note = "Templo titán sobre el Refugio de Marshal." } },
    pros = { "Hub neutral", "Cristales de poder y misiones de pilones", "Nueva mazmorra titán" },
    cons = { "Devilsaurios y élites", "Mucho a pie (sin vuelo hasta Refugio)" },
    professions = { "Cristales de Un'Goro para Alquimia/Encantamiento" },
    vendors = { "Refugio de Marshal: posada, reparación" },
    rares = { { "King Mosh", "Diablosaurio élite" }, { "Clutchmother Zavas" }, { "Uhk'loc" } },
    gathering = "Herboristería: Hojasueño, Sansam dorado, Salviargenta de montaña · Minería: Mitril, Torio",
}

zone {
    id = "felwood", name = "Felwood", nameES = "Frondavil", mapID = 1448,
    levels = { 48, 55 }, faction = "C", guides = { "Felwood" },
    hub = "Bosque Esmeralda / Árbol Zafiro (neutral)",
    dungeons = {},
    pros = { "Reputación Fauces de Madera", "Herboristería top (Gromsanguina, Flor de peste)" },
    cons = { "Muchos sátiros y demonios", "Rutas largas norte-sur" },
    professions = { "Gromsanguina y Flor de peste para Alquimia" },
    vendors = { "Bosque Esmeralda: posada, vuelo" },
    rares = { { "Ragepaw" }, { "Olm the Wise" }, { "Immolatus" }, { "Mongress" } },
    gathering = "Herboristería: Gromsanguina, Hojasueño, Sansam dorado, Flor de peste · Minería: Torio",
}

---------------------------------------------------------------------------
-- 50-60
---------------------------------------------------------------------------
zone {
    id = "steppes", name = "Burning Steppes", nameES = "Las Estepas Ardientes", mapID = 1428,
    levels = { 50, 58 }, faction = "C", guides = { "Burning Steppes" },
    hub = "Atalaya de Morgan (A) · Flamado (H)",
    dungeons = { { name = "Montaña Roca Negra", levels = "52-60", note = "Al norte." } },
    pros = { "Misiones que encadenan con Roca Negra", "Dragonkin con buena XP" },
    cons = { "Élites de Roca Negra por todos lados" },
    professions = {},
    vendors = { "Atalaya de Morgan / Flamado: servicios básicos" },
    rares = { { "Hematos" }, { "Terrorspark" }, { "Volchan" }, { "Gorgon'och" } },
    gathering = "Minería: Torio, Hierro oscuro (Roca Negra) · Herboristería: Sansam dorado, Flor de fuego",
}

zone {
    id = "wpl", name = "Western Plaguelands", nameES = "Tierras de la Peste del Oeste", mapID = 1422,
    levels = { 51, 58 }, faction = "C", guides = { "Western Plaguelands", "WPL", "Western PL" },
    hub = "Campamento de la Cruzada Argenta (Fiebre de Chillwind A / Bulwark H)",
    dungeons = { { name = "Scholomance", levels = "58-60", note = "Isla de Caer Darrow." } },
    pros = { "Reputación Alba Argenta", "Cadenas largas con muy buena XP" },
    cons = { "Muertos vivientes por todos lados", "Algunas élites de Escarlata" },
    professions = {},
    vendors = { "Chillwind / Bulwark: reparación" },
    rares = { { "Foreman Jerris" }, { "Lord Maldazzar" }, { "Scarlet Executioner" }, { "Scarlet Interrogator" }, { "Scarlet Judge" } },
    gathering = "Herboristería: Flor de peste, Sansam dorado, Lágrimas de Arthas · Minería: Torio",
}

zone {
    id = "epl", name = "Eastern Plaguelands", nameES = "Tierras de la Peste del Este", mapID = 1423,
    levels = { 53, 60 }, faction = "C", guides = { "Eastern Plaguelands", "EPL", "Eastern PL" },
    hub = "Capilla de la Esperanza de la Luz (neutral)",
    dungeons = { { name = "Stratholme", levels = "58-60", note = "Norte de la zona." } },
    pros = { "Misiones de 55-60 con mucha XP", "Capilla neutral" },
    cons = { "Abominaciones élite", "Lejos de las capitales" },
    professions = {},
    vendors = { "Capilla: Alba Argenta, reparación" },
    rares = { { "Duggan Wildhammer" }, { "Lord Darkscythe" }, { "Ranger Lord Hawkspear" }, { "Hed'mush the Rotting" }, { "Zul'Brin Warpbranch" } },
    gathering = "Herboristería: Flor de peste, Salviargenta de montaña · Minería: Torio",
}

zone {
    id = "winterspring", name = "Winterspring", nameES = "Cuna del Invierno", mapID = 1452,
    levels = { 53, 60 }, faction = "C", guides = { "Winterspring" },
    hub = "Everlook (neutral)",
    dungeons = { { name = "Bastión Fauces Negras (nuevo)", levels = "55-60", note = "Túnel desde Azshara bajo la Garganta Susurroscuro." } },
    pros = { "Everlook neutral", "Cadena de Donova Snowden", "Torio rico y Sangre de hielo" },
    cons = { "Muy alejada", "Furbolgs y yetis en cantidad" },
    professions = { "Everlook: recetas de cocina e ingeniería" },
    vendors = { "Everlook: posada, banco, subasta neutral" },
    rares = { { "Rak'shiri" }, { "Grizzle Snowpaw" }, { "Mezzir the Howler" }, { "Kashoch the Reaver" }, { "Lady Hederine" } },
    gathering = "Herboristería: Sansam dorado, Setelo · Minería: Torio, Torio rico",
}

zone {
    id = "silithus", name = "Silithus", nameES = "Silithus", mapID = 1451,
    levels = { 55, 60 }, faction = "C", guides = { "Silithus" },
    hub = "Fuerte Cenarion (neutral)",
    dungeons = {},
    pros = { "Reputación Círculo Cenarion", "Combina bien con Winterspring" },
    cons = { "Silítidos agresivos en masa" },
    professions = {},
    vendors = { "Fuerte Cenarion: posada, vuelo" },
    rares = { { "Rex Ashil" }, { "Zora" }, { "Setis" } },
    gathering = "Minería: Torio rico · Herboristería: Salviargenta de montaña",
}

zone {
    id = "hyjal", name = "Mount Hyjal", nameES = "Monte Hyjal", mapID = 2482, new = true,
    levels = { 55, 60 }, faction = "C", guides = { "Hyjal" },
    hub = "Elderwild (campamento compartido) · aldea elfa junto al Árbol del Mundo",
    access = "Desde Everlook (Cuna del Invierno) por la Garganta Susurroscuro: un túnel lleva a la zona. El vuelo de Hyjal sólo conecta con Everlook.",
    dungeons = {
        { name = "Hyjal Summit (raid 20)", levels = "60", note = "13 jefes. Portal en la base del Árbol del Mundo. Abre el 9/12/2026." },
        { name = "Barrow Deeps (raid 10)", levels = "60", note = "8 jefes; una de sus tres entradas está en Hyjal. Abre el 9/12/2026." },
    },
    pros = { "~100 misiones nuevas de 55-60, la mayoría para ambas facciones", "Reputación Guardianes de Hyjal y vendedor de recetas de Artesano en la posada", "Campamento compartido: sin PvP de hubs" },
    cons = { "Zona nueva: dadores de misiones y rutas aún sin publicar", "Doomguards élite patrullando y Plaga muy fuerte en Mourning's Rest", "Lejos de todo (sólo vuelo a Everlook)" },
    professions = { "Vendedor de recetas de rango Artesano en la posada de la aldea elfa", "Dazka Shadowsleep (creaciones alquímicas)" },
    vendors = {
        "Posaderos: Caitir Flinthew, Ortak Lomgok, Sebelia",
        "Suministros de herrería: Toron Rockhoof · Reparación: Chagrak Hammerstrike, Trigg Ironhand",
        "Bienes generales: Lenedil Moonwing · Establos: Aili Greenwillow",
        "Vuelo: Bluebell, Fayran Elthas",
    },
    rares = { { "Celastrus the Bitter", "Élite de misión" }, { "Ve'han Talongrasp", "Élite de misión (Ve'han's Fall)" }, { "Doomguard", "Élites patrullando el campamento de la Horda" } },
    gathering = "Datos de nodos aún sin confirmar",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
function Z.ForPlayer(level, faction)
    local f = faction == "Alliance" and "A" or faction == "Horde" and "H" or "C"
    local out = {}
    for _, z in ipairs(Z) do
        if Z.Allowed(z, f) then
            local lo, hi = z.levels[1], z.levels[2]
            local fit
            if level >= lo and level <= hi - 2 then fit = "ideal"
            elseif level >= lo - 3 and level < lo then fit = "low"
            elseif level > hi - 2 and level <= hi then fit = "high" end
            if fit then out[#out + 1] = { zone = z, fit = fit } end
        end
    end
    local order = { ideal = 1, low = 2, high = 3 }
    table.sort(out, function(a, b)
        if a.zone.new ~= b.zone.new then return a.zone.new and true or false end
        if order[a.fit] ~= order[b.fit] then return order[a.fit] < order[b.fit] end
        return a.zone.levels[1] < b.zone.levels[1]
    end)
    return out
end

function Z.Allowed(z, f)
    if z.onlyRace then
        local _, raceFile, raceID = UnitRace("player")
        local isSkyborne = raceID == 95 or raceID == 96 or (raceFile and raceFile:find(z.onlyRace, 1, true))
        if not isSkyborne then return false end
    end
    return z.faction == "C" or z.faction == f
end

function Z.ByMap(mapID)
    if not mapID then return end
    for _, z in ipairs(Z) do
        if z.mapID == mapID then return z end
    end
end

function Z.ByName(name)
    if not name then return end
    local n = name:lower()
    for _, z in ipairs(Z) do
        for _, k in ipairs(z.guides) do
            if n:find(k:lower(), 1, true) then return z end
        end
    end
end
