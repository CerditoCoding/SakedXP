-- SakedXP · Riverglades (36-45), new WoW Forever zone. Map 2548.
-- Quest IDs/NPCs: Wowhead Forever via BindOnForever & ForeverChanges (Nov 2026).
-- Coordinates only where verified (Forever Dungeon Journal); other NPCs use
-- .target so you can find them with a macro / nameplates.
-- BETA: routes will be refined as live data settles.

local _, S = ...
local GB = S.GuideBuilder
local MAP = 2548

local FARHOLDE = { 66.6, 81.0 }
local BRANT    = { 66.6, 79.9 }
local ALPHONSE = { 64.4, 82.0 }
local RIFTAN   = { 30.6, 49.0 }
local KROMROSH = { 59.4, 45.5 }
local KREZA    = { 59.8, 46.0 }
local TRANGUL  = { 59.4, 44.0 }
local DAGROSH  = { 33.4, 38.0 }
local CRAGROG  = { 27.4, 37.0 }
local CLUGFIST = { 64.4, 14.8 }
local KROLDOK  = { 37.5, 37.3 }

local WORK = "Completá los objetivos (el progreso se actualiza solo)"

---------------------------------------------------------------------------
-- Neutral: Powderfuse Port (both factions)
---------------------------------------------------------------------------
local function powderfuse(b, faction)
    b:step({ say = "Andá a |cRXP_FRIENDLY_Puerto Powderfuse|r (costa sur). También llegás en barco desde Puerto Steamwheedle (Tanaris)." ,
        manual = "Llegué a Puerto Powderfuse" })
    b:talk("Friz Frazzlespark", "Puerto Powderfuse", nil, { accept = { faction == "Alliance" and 95059 or 95062, 95295 } })
    b:talk("Fimbo Greasemitz", "Puerto Powderfuse", nil, { accept = { 95121 } })
    b:talk("Wharfmaster Whizzbuzz", "Puerto Powderfuse", nil, { accept = { 95118 } })
    b:talk("Argo Brinewhistle", "Puerto Powderfuse", nil, { accept = { 95267 } })
    b:work(95121, "Recolectá lo que pide |cRXP_FRIENDLY_Fimbo|r en la costa")
    b:work(95118, "Matá a los |cRXP_ENEMY_Saltwater|r de la costa")
    b:work(95267, "Buscá al monstruo marino para |cRXP_FRIENDLY_Argo|r")
    b:talk("Fimbo Greasemitz", "Puerto Powderfuse", nil, { turnin = { 95121 } })
    b:talk("Wharfmaster Whizzbuzz", "Puerto Powderfuse", nil, { turnin = { 95118 }, accept = { { 95119, 95118 } } })
    b:work(95119, WORK)
    b:talk("Wharfmaster Whizzbuzz", "Puerto Powderfuse", nil, { turnin = { 95119 }, accept = { { 95165, 95119 }, { 95122, 95119 }, { 95123, 95119 } } })
    b:work(95122, WORK)
    b:work(95123, WORK)
    b:work(95165, "Expulsá a los piratas (|cRXP_WARN_puede requerir grupo|r)")
    b:talk("Wharfmaster Whizzbuzz", "Puerto Powderfuse", nil, { turnin = { 95122, 95123, 95165 }, accept = { { 95124, 95165 } } })
    b:work(95124, "Derrotá a |cRXP_ENEMY_Admiral Lamora|r (|cRXP_WARN_élite: buscá grupo|r)")
    b:talk("Wharfmaster Whizzbuzz", "Puerto Powderfuse", nil, { turnin = { 95124 } })
    b:talk("Argo Brinewhistle", "Puerto Powderfuse", nil, { turnin = { 95267 } })
end

---------------------------------------------------------------------------
-- ALLIANCE
---------------------------------------------------------------------------
do
    local b = GB.new({ name = "36-40 Riverglades", group = "SakedXP Forever (A)", subgroup = "Zonas nuevas",
        faction = "Alliance", map = MAP, next = "40-45 Riverglades" })

    b:step({ at = FARHOLDE, say = "Viajá a |cRXP_FRIENDLY_Bastión Farholde|r: desde Villa del Lago (Crestagrana) seguí el camino al norte. Hay vuelo Farholde - Villa del Lago.",
        fp = "Farholde Keep", npc = "Gretchen Mayberry" })
    b:step({ at = FARHOLDE, say = "Hablá con |cRXP_FRIENDLY_Barracks Master Harlan|r", home = "Bastión Farholde", npc = "Barracks Master Harlan" })
    b:talk("Demar Brant", "Bastión Farholde", BRANT, { accept = { 94613, 95329 } })
    b:talk("Ashe Amberhall", "Bastión Farholde", FARHOLDE, { accept = { 94881 } })
    b:talk("Cedric Dalton", "Capitán de la guardia", nil, { accept = { 95148, 94678 } })
    b:talk("Ember Bladewhisper", "Instructora de armas", nil, { accept = { 95156 } })
    b:talk("Robbie Holmsby", nil, nil, { accept = { 94999 } })
    b:talk("Scout Bolain", nil, nil, { accept = { 95147 } })
    b:step({ say = "Las misiones de 290 XP (|cRXP_WARN_My Kingdom for a Horse, Out in the Field, The Lost Scout, Southern Watch Gnoll Report|r) son de traslado: llevan a nuevos hubs",
        manual = "Entendido" })

    b:talk("Benjy Wheeler", "Meadowsbrook", nil, { accept = { 94617, 94615, 94614, 94618 } })
    b:talk("Lost Horse", nil, nil, { accept = { 94992 } })
    b:talk("Cassandra Wheeler", "Meadowsbrook", nil, { accept = { 95330 } })
    b:talk("Halligan Turner", nil, nil, { accept = { 94843, 94931, 94842 } })
    b:talk("Tessa Dawnbright", nil, nil, { accept = { 95561, 95913, 95961 } })
    b:talk("Bertrand Ironbrow", "Capataz", nil, { accept = { 95943, 96009 } })
    b:talk("Sister Rowland", nil, nil, { accept = { 95603, 95615, 95613 } })

    for _, id in ipairs({ 94617, 94615, 94614, 94618, 94992, 94843, 94931, 94842, 95561, 95913, 95943, 96009, 95603, 95615, 95613, 94678, 95156, 94999, 94881 }) do
        b:work(id, WORK)
    end

    b:talk("Benjy Wheeler", "Meadowsbrook", nil, { turnin = { 94617, 94615, 94614, 94618, 94992 } })
    b:talk("Halligan Turner", nil, nil, { turnin = { 94843, 94931, 94842 }, accept = { 94861 } })
    b:talk("Curly", nil, nil, { accept = { 94857 } })
    b:work(94861, WORK)
    b:work(94857, WORK)
    b:talk("Halligan Turner", nil, nil, { turnin = { 94861, 94857 } })
    b:talk("Tessa Dawnbright", nil, nil, { turnin = { 95561, 95913 } })
    b:talk("Bertrand Ironbrow", "Capataz", nil, { turnin = { 95943, 96009 } })
    b:talk("Sister Rowland", nil, nil, { turnin = { 95603, 95615, 95613 } })
    b:talk("Cedric Dalton", "Capitán de la guardia", nil, { turnin = { 94678 } })
    b:talk("Ember Bladewhisper", nil, nil, { turnin = { 95156 }, accept = { { 95184, 95156 } } })
    b:work(95184, WORK)
    b:talk("Ember Bladewhisper", nil, nil, { turnin = { 95184 } })
    b:talk("Robbie Holmsby", nil, nil, { turnin = { 94999 }, accept = { 94923 } })
    b:work(94923, WORK)
    b:talk("Robbie Holmsby", nil, nil, { turnin = { 94923 } })
    b:talk("Ashe Amberhall", "Bastión Farholde", FARHOLDE, { turnin = { 94881 } })

    b:talk("Watcher Cornelius", nil, nil, { accept = { 94928, 94925, 94924, 95064, 95426, 95984, 95066 } })
    for _, id in ipairs({ 94925, 94924, 95064, 95984 }) do b:work(id, WORK) end
    b:talk("Watcher Cornelius", nil, nil, { turnin = { 94925, 94924, 95064, 95984 } })
    b:step({ xp = 40, say = "Llegá a nivel 40 antes de seguir (matá bichos de la zona si te falta poco)" })
    b:register()
end

do
    local b = GB.new({ name = "40-45 Riverglades", group = "SakedXP Forever (A)", subgroup = "Zonas nuevas",
        faction = "Alliance", map = MAP })

    b:talk("Demar Brant", "Bastión Farholde", BRANT, { accept = { 94877 } })
    b:talk("Ashe Amberhall", "Bastión Farholde", FARHOLDE, { accept = { 94879 } })
    b:talk("Farmer Elbrim", nil, nil, { accept = { 94858, 94829 } })
    b:talk("Apprentice Claire", nil, nil, { accept = { 95642, 95643 } })
    b:talk("Brother Lowley", nil, nil, { accept = { 96083, 96082, 96081 } })
    b:talk("Sister Rowland", nil, nil, { accept = { 96084 } })
    for _, id in ipairs({ 94877, 94879, 94858, 94829, 95642, 95643, 96083, 96082, 96081, 96084 }) do b:work(id, WORK) end
    b:talk("Farmer Elbrim", nil, nil, { turnin = { 94858, 94829 } })
    b:talk("Apprentice Claire", nil, nil, { turnin = { 95642, 95643 }, accept = { 94884, { 95562, 95643 } } })
    b:work(94884, WORK)
    b:work(95562, "Cortá las cabezas (|cRXP_WARN_élite: buscá grupo o saltá con la cadena|r)")
    b:talk("Apprentice Claire", nil, nil, { turnin = { 94884, 95562 } })
    b:talk("Brother Lowley", nil, nil, { turnin = { 96083, 96082, 96081 } })
    b:talk("Sister Rowland", nil, nil, { turnin = { 96084 }, accept = { { 96085, 96084 } } })
    b:work(96085, "Contaminación río arriba (|cRXP_WARN_élite|r)")
    b:talk("Sister Rowland", nil, nil, { turnin = { 96085 } })
    b:talk("Ashe Amberhall", "Bastión Farholde", FARHOLDE, { turnin = { 94879 }, accept = { { 94907, 94879 } } })
    b:work(94907, "Invocá un |cRXP_ENEMY_Twilight's Thrall|r en un conducto del Twilight's Shroud y capturalo con la Piedra de alma de Amberhall")
    b:talk("Ashe Amberhall", "Bastión Farholde", FARHOLDE, { turnin = { 94907 } })
    b:talk("Demar Brant", "Bastión Farholde", BRANT, { turnin = { 94877 } })

    b:talk("Gray Dawnbright", nil, nil, { accept = { 95975 } })
    b:work(95975, WORK)
    b:talk("Gray Dawnbright", nil, nil, { turnin = { 95975 } })
    b:talk("Watcher Cornelius", nil, nil, { accept = { 95986, 96125 } })
    b:work(95986, "Rey de las Llanuras Salvajes (|cRXP_WARN_élite|r)")
    b:talk("Watcher Cornelius", nil, nil, { turnin = { 95986 } })

    powderfuse(b, "Alliance")

    -- Twilight's Shroud campaign
    b:talk("Demar Brant", "Bastión Farholde", BRANT, { accept = { 94886 } })
    b:talk("Sergeant Riftan", "Puestos de vigilancia de Farholde", RIFTAN, { turnin = { 94886 }, accept = { 96015, 94888, 94889 } })
    for _, id in ipairs({ 96015, 94888, 94889 }) do b:work(id, WORK) end
    b:talk("Sergeant Riftan", nil, RIFTAN, { turnin = { 96015, 94888, 94889 }, accept = { { 94890, 94889 } } })
    b:work(94890, "Derrotá a |cRXP_ENEMY_Overlord Kilgar|r en el Twilight's Shroud y traé su cabeza (|cRXP_WARN_élite: grupo|r)")
    b:talk("Sergeant Riftan", nil, RIFTAN, { turnin = { 94890 }, accept = { { 94891, 94890 }, { 94983, 94890 } } })
    b:talk("Dunston Willis", nil, nil, { accept = { 96126, 94927 } })
    b:work(96126, WORK)
    b:work(94927, WORK)
    b:talk("Dunston Willis", nil, nil, { turnin = { 96126, 94927 } })
    b:talk("Demar Brant", "Bastión Farholde", BRANT, { turnin = { 94891 }, accept = { 94894, 94893, 94887 } })
    b:step({ at = KROLDOK, say = "Opcional: |cRXP_FRIENDLY_Fortaleza Krol'dok|r (40-45). La entrada es la cueva a la izquierda de la piedra de reunión, no las puertas grandes. Llevá |cRXP_WARN_Eye of Mugg|r (Demar Brant) y |cRXP_WARN_Twilight Mementos|r (Riftan).",
        manual = "Hecha o saltada" })
    b:work(94894, WORK)
    b:work(94887, WORK)
    b:talk("Marshal Ryan", nil, nil, { accept = { 94892 } })
    b:work(94892, WORK)
    b:talk("Demar Brant", "Bastión Farholde", BRANT, { turnin = { 94894, 94893, 94887, 94892 } })
    b:talk("Alphonse Dumas", "Herrero, Bastión Farholde", ALPHONSE, { manual = "Si tenés un Molde de Krol'dok (Tunk), entregáselo a Alphonse" })
    b:register()
end

---------------------------------------------------------------------------
-- HORDE
---------------------------------------------------------------------------
do
    local b = GB.new({ name = "36-40 Riverglades", group = "SakedXP Forever (H)", subgroup = "Zonas nuevas",
        faction = "Horde", map = MAP, next = "40-45 Riverglades" })

    b:step({ at = KROMROSH, say = "Viajá a |cRXP_FRIENDLY_Rog'mar|r en Riverglades (desde el Pantano de las Penas / Crestagrana por el camino norte).",
        fp = "Rog'mar", npc = "Grakna" })
    b:step({ at = KROMROSH, say = "Hablá con |cRXP_FRIENDLY_Innkeeper Toka|r", home = "Rog'mar", npc = "Innkeeper Toka" })
    b:talk("Krom'rosh", "Rog'mar", KROMROSH, { accept = { 94480, 93786, 93787 } })
    b:talk("Kreza Darkthorn", "Rog'mar", KREZA, { accept = { 93976, 93788, 94535 } })
    b:talk("Gorg", "Rog'mar", nil, { accept = { 94481 } })
    b:talk("Tan'jani", "Rog'mar", nil, { accept = { 95951 } })
    b:talk("Neza Bloodsnout", "Rog'mar", nil, { accept = { 94532, 96104 } })
    b:step({ say = "|cRXP_WARN_A Gift From Our Enemies|r y |cRXP_WARN_The Goblin Trader|r son de traslado (pocas XP): te llevan a otro NPC", manual = "Entendido" })

    for _, id in ipairs({ 93786, 93787, 93788, 94535, 94481, 95951, 94532, 96104 }) do b:work(id, WORK) end

    b:talk("Krom'rosh", "Rog'mar", KROMROSH, { turnin = { 93786, 93787 }, accept = { 94483 } })
    b:talk("Kreza Darkthorn", "Rog'mar", KREZA, { turnin = { 93788, 94535 } })
    b:talk("Gorg", "Rog'mar", nil, { turnin = { 94481 } })
    b:talk("Tan'jani", "Rog'mar", nil, { turnin = { 95951 }, accept = { { 95955, 95951 } } })
    b:talk("Neza Bloodsnout", "Rog'mar", nil, { turnin = { 94532, 96104 }, accept = { 96109, 96107, 96108 } })
    b:talk("Picked Carcass", nil, nil, { accept = { 96103 } })
    for _, id in ipairs({ 94483, 95955, 96109, 96107, 96108, 96103 }) do b:work(id, WORK) end
    b:talk("Krom'rosh", "Rog'mar", KROMROSH, { turnin = { 94483 } })
    b:talk("Tan'jani", "Rog'mar", nil, { turnin = { 95955 } })
    b:talk("Neza Bloodsnout", "Rog'mar", nil, { turnin = { 96109, 96107, 96108 } })
    b:step({ xp = 40, say = "Llegá a nivel 40 antes de seguir" })
    b:register()
end

do
    local b = GB.new({ name = "40-45 Riverglades", group = "SakedXP Forever (H)", subgroup = "Zonas nuevas",
        faction = "Horde", map = MAP })

    b:talk("Tran'gul", "Rog'mar", TRANGUL, { accept = { 94727, 95420, 94672, 94680 } })
    b:talk("Na'zok", nil, nil, { accept = { 95163, 95162 } })
    b:talk("Mirelle Tremayne", nil, nil, { accept = { 97884 } })
    b:talk("Neza Bloodsnout", "Rog'mar", nil, { accept = { 94533, 96105 } })
    for _, id in ipairs({ 94672, 94680, 95163, 95162, 97884 }) do b:work(id, WORK) end
    b:talk("Tran'gul", "Rog'mar", TRANGUL, { turnin = { 94672, 94680 } })
    b:talk("Na'zok", nil, nil, { turnin = { 95163, 95162 } })
    b:talk("Mirelle Tremayne", nil, nil, { turnin = { 97884 } })

    b:talk("Clubtoe", nil, nil, { accept = { 95602, 95418, 95417 } })
    b:work(95602, WORK)
    b:work(95417, WORK)
    b:talk("Clubtoe", nil, nil, { turnin = { 95602, 95417 }, accept = { { 95427, 95417 } } })
    b:work(95427, "¡Basta de Crepusculares! (|cRXP_WARN_élite|r)")
    b:talk("Clubtoe", nil, nil, { turnin = { 95427 } })
    b:talk("Gobam", nil, nil, { accept = { 94734, 94737 } })
    b:work(94734, WORK)
    b:talk("Gobam", nil, nil, { turnin = { 94734 } })

    b:talk("Clugfist", nil, CLUGFIST, { accept = { 95428, 95424, 94668 } })
    b:work(95424, WORK)
    b:talk("Clugfist", nil, CLUGFIST, { turnin = { 95424 }, accept = { { 95425, 95424 } } })
    b:work(95425, WORK)
    b:talk("Clugfist", nil, CLUGFIST, { turnin = { 95425 } })
    b:talk("Jezap Jinglesprocket", "Promotor de peleas", nil, { turnin = { 94668 }, accept = { 94669, 94733, 94670 } })
    b:work(94670, "Anillo de Bloodmaster (|cRXP_WARN_élite: la cadena sigue hasta nivel 45|r)")
    b:talk("Jezap Jinglesprocket", nil, nil, { turnin = { 94670 }, accept = { { 94739, 94670 } } })
    b:talk("Gorgegut", nil, nil, { accept = { 95183 } })
    b:work(95183, WORK)
    b:talk("Hamur", nil, nil, { turnin = { 95183 }, accept = { { 96026, 95183 } } })
    b:work(96026, WORK)
    b:talk("Hamur", nil, nil, { turnin = { 96026 } })
    b:talk("Jom-jom", nil, nil, { accept = { 94556 } })
    b:work(94556, "Escoltá a |cRXP_FRIENDLY_Jom-jom|r (|cRXP_WARN_élite|r)")
    b:work(94533, "Hocico de Snargl (|cRXP_WARN_élite|r)")
    b:work(96105, "Rey de las Llanuras Salvajes (|cRXP_WARN_élite|r)")
    b:talk("Neza Bloodsnout", "Rog'mar", nil, { turnin = { 94533, 96105 } })

    powderfuse(b, "Horde")

    -- Twilight's Hammer campaign
    b:talk("Krom'rosh", "Rog'mar", KROMROSH, { accept = { { 94744, 95428 } } })
    b:talk("Da'grosh", "Twilight's Shroud", DAGROSH, { turnin = { 94744 }, accept = { 95431, 94748, 94745 } })
    b:talk("Crag'rog", nil, CRAGROG, { accept = { 95432 } })
    for _, id in ipairs({ 94748, 94745, 95432 }) do b:work(id, WORK) end
    b:talk("Crag'rog", nil, CRAGROG, { turnin = { 95432 }, accept = { 95433 } })
    b:talk("Da'grosh", "Twilight's Shroud", DAGROSH, { turnin = { 94748, 94745 }, accept = { { 94768, 94745 }, 95278 } })
    b:work(94768, "Derrotá a |cRXP_ENEMY_Overlord Kilgar|r y traé su cabeza (|cRXP_WARN_élite: grupo|r)")
    b:work(95433, "Muerte al Verdugo (|cRXP_WARN_élite|r)")
    b:talk("Da'grosh", "Twilight's Shroud", DAGROSH, { turnin = { 94768 } })
    b:talk("Crag'rog", nil, CRAGROG, { turnin = { 95433 } })
    b:talk("Krom'rosh", "Rog'mar", KROMROSH, { turnin = { 95278 } })
    b:step({ at = KROLDOK, say = "Opcional: |cRXP_FRIENDLY_Fortaleza Krol'dok|r (40-45). Cueva a la izquierda de la piedra de reunión. Llevá |cRXP_WARN_Eye of Mugg|r (Krom'rosh), |cRXP_WARN_Tome of Twilight|r (Tran'gul) y |cRXP_WARN_A Token of Vengeance|r (Da'grosh).",
        manual = "Hecha o saltada" })
    b:talk("Kreza Darkthorn", "Rog'mar", KREZA, { manual = "Si tenés un Molde de Krol'dok (Tunk), entregáselo a Kreza" })
    b:register()
end
