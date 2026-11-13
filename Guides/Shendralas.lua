-- SakedXP · Shen'dralas (38-45), new WoW Forever zone. Map 2652.
-- South end of Desolace through the Valley of Bones. No flight path.
-- Pylon chain and coordinates: Wowhead Forever via Forever Dungeon Journal.

local _, S = ...
local GB = S.GuideBuilder
local MAP = 2652
local DESOLACE = 1443

local PYLON    = { 43.6, 34.2 }
local PYLON_E  = { 73.0, 23.0 }
local PYLON_S  = { 47.0, 78.0 }
local MORDENT  = { 35.0, 46.4 }
local KIRANDIS = { 47.2, 75.8 }
local MITHERA  = { 52.8, 76.0 }
local WOODWYRD = { 53.5, 76.0 }
local KOGTHUG  = { 72.6, 31.4 }

local WORK = "Completá los objetivos (el progreso se actualiza solo)"

local b = GB.new({ name = "38-43 Shen'dralas", group = "SakedXP Forever", subgroup = "Zonas nuevas", map = MAP })

b:step({ say = "Viajá a |cRXP_FRIENDLY_Shen'dralas|r: desde el sur de Desolace seguí el |cRXP_WARN_Valle de los Huesos|r hacia el sur. |cRXP_WARN_No hay ruta de vuelo|r: fijá la piedra de hogar en el templo (Adarien).",
    manual = "Llegué a Shen'dralas" })

-- Valley of Bones hubs (both factions)
b:talk("Uthek the Wise", "Valle de los Huesos", nil, { accept = { 93034, 92894, 92873, 92847, 92893 } })
b:talk("Nerlokh", nil, nil, { accept = { 93041, 93035, 93037, 93062, 93058 } })
b:talk("Warug", nil, nil, { only = "Alliance", accept = { 92841, 92846, 92844 } })
b:talk("Nerlokh", nil, nil, { only = "Horde", accept = { 93122 } })
for _, id in ipairs({ 93041, 93035, 93037, 92894, 92873, 92847, 92893, 93062, 93058 }) do b:work(id, WORK) end
b:step({ only = "Alliance", work = 92846, say = WORK })
b:step({ only = "Alliance", work = 92844, say = WORK })
b:step({ only = "Horde", work = 93122, say = WORK })
b:talk("Uthek the Wise", "Valle de los Huesos", nil, { turnin = { 92894, 92873, 92847, 92893 }, accept = { { 93066, 92893 } } })
b:talk("Nerlokh", nil, nil, { turnin = { 93041, 93035, 93037, 93062, 93058 } })
b:talk("Warug", nil, nil, { only = "Alliance", turnin = { 92846, 92844 } })
b:talk("Nerlokh", nil, nil, { only = "Horde", turnin = { 93122 } })

-- The pylon chain: opens the rest of the zone
b:step({ at = PYLON, say = "Hacé clic en el |cRXP_PICK_Pilón Shen'dralar|r (cristal agrietado sobre un pedestal, custodiado por elementales de maná)", accept = { 92914 } })
b:step({ at = PYLON_E, say = "Explorá el pilón del este (|cRXP_WARN_más elementales arcanos; te desmontan|r)", work = 92914 })
b:step({ at = PYLON_S, say = "Explorá el pilón del sur, dentro del gran edificio de Shen'dralas", work = 92914 })
b:talk("Mordent Evenshade", "Mirador de Evenshade", MORDENT, { turnin = { 92914 }, accept = { 96010, 96018 } })
b:step({ map = DESOLACE, at = { 37.0, 80.0 }, say = "Recuperá el fragmento del pilón en la aldea Gelkis (Desolace)", work = 96010 })
b:step({ map = DESOLACE, at = { 70.0, 75.0 }, say = "Recuperá el fragmento del pilón en la aldea Magram (Desolace)", work = 96010 })
b:step({ at = PYLON_S, say = "Tomá el |cRXP_PICK_Tamiz de maná|r en el piso superior del templo. Absorbé 8 de maná de los orbes arcanos y usá 4 en cada pilón", work = 96018 })
b:talk("Mordent Evenshade", "Mirador de Evenshade", MORDENT, { turnin = { 96010, 96018 }, accept = { 93016 } })
b:talk("Mordent Evenshade", "Mirador de Evenshade", MORDENT, { turnin = { 93016 }, accept = { 93394 } })
b:talk("Magister Kirandis", "dentro del templo", KIRANDIS, { turnin = { 93394 } })

-- Forlorn Gardens
b:talk("Mithera", "Jardines Desolados", MITHERA, { accept = { 93341 } })
b:work(93341, "Investigá los |cRXP_FRIENDLY_Jardines Desolados|r", { at = MITHERA })
b:talk("Mithera", "Jardines Desolados", MITHERA, { turnin = { 93341 }, accept = { 93594 } })
b:talk("Woodwyrd", "Jardines Desolados", WOODWYRD, { turnin = { 93594 }, accept = { 93601 } })
b:step({ at = WOODWYRD, say = "Opcional (|cRXP_WARN_Maraudon|r): Woodwyrd ofrece |cRXP_WARN_Rot and Regret|r. Necesitás el Vial de Agua del Canto de la Tierra (géiser junto a Rotgrip). Usalo en el árbol en llamas, no en Woodwyrd.",
    manual = "Entendido" })
b:talk("Kog'thug the Brave", "Refugio Bristleback", KOGTHUG, { turnin = { 93601 } })
b:step({ at = KOGTHUG, say = "Opcional (|cRXP_WARN_Zahúrda Rajacieno|r): Kog'thug ofrece |cRXP_WARN_Agamaggan's Blood|r. Hacé clic en un Caldero de Sangre de Agamaggan dentro de la mazmorra para invocar la sangre.",
    manual = "Entendido" })

-- Bristleback Retreat (Uthek) and Warug follow-ups
b:work(93066, "Refugio Bristleback: completá los objetivos de |cRXP_FRIENDLY_Uthek|r", { at = KOGTHUG })
b:talk("Uthek the Wise", "Valle de los Huesos", nil, { turnin = { 93066 } })
b:talk("Warug", nil, nil, { accept = { 93072, 93129 } })
b:work(93072, WORK)
b:work(93129, WORK)
b:talk("Warug", nil, nil, { turnin = { 93072, 93129 }, accept = { 93125, 93188 } })
b:work(93125, WORK)
b:talk("Orgrul", nil, nil, { turnin = { 93188 } })
b:register()
