-- SakedXP · Mount Hyjal (55-60), new WoW Forever zone. UiMap 2482.
-- Quest givers and coordinates are not published yet (Nov 2026), so this is
-- an orientation guide: getting there, hubs, campaign milestones. It will
-- grow into a full step-by-step route once live data is available.

local _, S = ...
local GB = S.GuideBuilder
local MAP = 2482

local b = GB.new({ name = "55-60 Mount Hyjal", group = "SakedXP Forever", subgroup = "Zonas nuevas", map = MAP })

b:step({ map = 1452, at = { 61.4, 38.8 }, say = "Andá a |cRXP_FRIENDLY_Everlook|r (Cuna del Invierno). El maestro de vuelo de Hyjal sólo conecta con Everlook.",
    manual = "Estoy en Everlook" })
b:step({ say = "Seguí hacia el sur pasando la |cRXP_WARN_Garganta Susurroscuro|r: un túnel lleva a Monte Hyjal. Si morís en el camino aparecés en el cementerio de Everlook.",
    manual = "Entré a Monte Hyjal" })
b:step({ say = "Conseguí la ruta de vuelo (dríade |cRXP_FRIENDLY_Bluebell|r)", fp = "Mount Hyjal", npc = "Bluebell" })
b:step({ say = "En |cRXP_FRIENDLY_Elderwild|r (campamento compartido, con cementerio) hablá con el posadero para fijar tu hogar",
    manual = "Hogar fijado (Caitir Flinthew / Ortak Lomgok / Sebelia)" })
b:step({ say = "Tomá todas las misiones de Elderwild y de la aldea elfa junto al Árbol del Mundo (posada con vendedores, junto al esqueleto de Archimonde).",
    manual = "Misiones de Elderwild tomadas" })
b:step({ only = "Alliance", say = "Campaña: avanzá hasta |cRXP_WARN_To the Summit of Eternity|r", work = 91688 })
b:step({ only = "Horde", say = "Campaña: avanzá hasta |cRXP_WARN_To the Summit of Eternity|r", work = 95248 })
b:step({ say = "Zonas de misiones: |cRXP_FRIENDLY_Malorne's Retreat|r (furbolgs Deadwood), |cRXP_FRIENDLY_Shrine of Aviana|r (arpías, Druidas del Espolón), |cRXP_FRIENDLY_Mourning's Rest|r (Plaga, pegan fuerte), |cRXP_FRIENDLY_Tainted Foothills|r.",
    manual = "Entendido" })
b:step({ say = "Élites de grupo con buenas recompensas: |cRXP_WARN_Celastrus the Bitter, Ve'han's Fall, Blackthorne Blackout, Drum Up Trouble, Halt the Hail|r. Buscá grupo en Elderwild.",
    manual = "Entendido" })
b:step({ xp = 60, say = "Llegá a nivel 60. Las raids |cRXP_WARN_Hyjal Summit|r (20 jugadores) y |cRXP_WARN_Barrow Deeps|r (10) abren el 9 de diciembre." })
b:register()
