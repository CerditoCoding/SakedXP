-- SakedXP · Profession routes (1-300)
-- Classic reference routes. WoW Forever keeps the classic profession system
-- (Aprendiz/Oficial/Experto/Artesano) and adds new trainers in Riverglades
-- and Shen'dralas. Recipes may change in Forever: treat counts as estimates.
-- step = { from, to, recipe, mats = { {item, qty}, ... }, note }

local _, S = ...

local P = {}
S.Professions = P

P.TIERS = {
    { name = "Aprendiz", max = 75, level = 5 },
    { name = "Oficial", max = 150, level = 10, from = 50 },
    { name = "Experto", max = 225, level = 20, from = 125 },
    { name = "Artesano", max = 300, level = 35, from = 200 },
}

local function prof(t) P[#P + 1] = t; return t end

prof {
    key = "alchemy", name = "Alquimia", spell = 2259, icon = "Interface\\Icons\\Trade_Alchemy", kind = "craft",
    pair = "Herboristería",
    trainers = {
        A = "Capitales: Ventormenta, Forjaz, Darnassus · Artesano: Ainethil (Darnassus)",
        H = "Capitales: Orgrimmar, Entrañas, Cima del Trueno · Artesano: Doctor Herbert Halsey (Entrañas)",
    },
    steps = {
        { 1, 60, "Poción de sanación menor", { { "Flor de paz", 1 }, { "Hojaplata", 1 }, { "Vial vacío", 1 } } },
        { 60, 110, "Poción de sanación inferior", { { "Poción de sanación menor", 1 }, { "Brezospina", 1 } } },
        { 110, 140, "Poción de sanación", { { "Hierba cardenal", 1 }, { "Brezospina", 1 }, { "Vial emplomado", 1 } } },
        { 140, 155, "Poción de maná inferior", { { "Marregal", 1 }, { "Alga estranguladora", 1 }, { "Vial vacío", 1 } } },
        { 155, 185, "Poción de sanación superior", { { "Vidarraíz", 1 }, { "Sangrerreal", 1 }, { "Vial emplomado", 1 } }, "Entrená Experto a 125 (nivel 20)." },
        { 185, 210, "Elixir de agilidad", { { "Alga estranguladora", 1 }, { "Espina de oro", 1 }, { "Vial emplomado", 1 } } },
        { 210, 215, "Elixir de defensa superior", { { "Acérita salvaje", 1 }, { "Espina de oro", 1 }, { "Vial emplomado", 1 } } },
        { 215, 230, "Poción de sanación excelente", { { "Solea", 1 }, { "Mostacho de Khadgar", 1 }, { "Vial de cristal", 1 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 230, 250, "Elixir de detectar no-muertos", { { "Lágrimas de Arthas", 1 }, { "Vial de cristal", 1 } } },
        { 250, 265, "Elixir de agilidad superior", { { "Solea", 1 }, { "Espina de oro", 1 }, { "Vial de cristal", 1 } } },
        { 265, 285, "Poción de maná excelente", { { "Solea", 2 }, { "Carolina", 2 }, { "Vial de cristal", 1 } } },
        { 285, 300, "Poción de sanación sublime", { { "Sansam dorado", 2 }, { "Salviargenta de montaña", 1 }, { "Vial de cristal", 1 } } },
    },
}

prof {
    key = "blacksmithing", name = "Herrería", spell = 2018, icon = "Interface\\Icons\\Trade_BlackSmithing", kind = "craft",
    pair = "Minería",
    trainers = {
        A = "Ventormenta, Forjaz · Riverglades: Alphonse Dumas (Farholde)",
        H = "Orgrimmar, Entrañas · Riverglades: Gur'dok (Rog'mar)",
    },
    steps = {
        { 1, 25, "Piedra de afilar basta", { { "Piedra en bruto", 1 } } },
        { 25, 45, "Piedra de moler basta", { { "Piedra en bruto", 2 } } },
        { 45, 75, "Cinturón de cadena de cobre", { { "Barra de cobre", 6 } } },
        { 75, 80, "Piedra de moler gruesa", { { "Piedra gruesa", 2 } } },
        { 80, 100, "Cinturón de cobre rúnico", { { "Barra de cobre", 10 } } },
        { 100, 105, "Vara de plata", { { "Barra de plata", 1 }, { "Piedra de moler basta", 2 } } },
        { 105, 125, "Leotardos de bronce toscos", { { "Barra de bronce", 6 } } },
        { 125, 150, "Piedra de moler pesada", { { "Piedra pesada", 3 } }, "Entrená Experto a 125 (nivel 20)." },
        { 150, 155, "Vara de oro", { { "Barra de oro", 1 }, { "Piedra de moler gruesa", 2 } } },
        { 155, 165, "Leotardos de hierro verde", { { "Barra de hierro", 8 }, { "Piedra de moler pesada", 1 }, { "Tinte verde", 1 } } },
        { 165, 185, "Brazales de hierro verde", { { "Barra de hierro", 6 }, { "Tinte verde", 1 } } },
        { 185, 200, "Brazales de escamas doradas", { { "Barra de acero", 5 }, { "Piedra de moler pesada", 2 } } },
        { 200, 210, "Piedra de moler sólida", { { "Piedra sólida", 4 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 210, 235, "Guanteletes de mitril pesado", { { "Barra de mitril", 6 }, { "Paño de tejido mágico", 4 } } },
        { 235, 250, "Cofia de mitril", { { "Barra de mitril", 10 }, { "Paño de tejido mágico", 6 } } },
        { 250, 260, "Piedra de afilar densa", { { "Piedra densa", 1 } } },
        { 260, 300, "Piezas de torio (cinturón / brazales de torio)", { { "Barra de torio", 10 } }, "Usá los planos de torio que tengas; la ruta exacta depende de las recetas de Forever." },
    },
}

prof {
    key = "enchanting", name = "Encantamiento", spell = 7411, icon = "Interface\\Icons\\Trade_Engraving", kind = "craft",
    pair = "Sastrería (para desencantar)",
    trainers = {
        A = "Ventormenta, Darnassus · Riverglades: Melanie Sable (Farholde)",
        H = "Orgrimmar, Entrañas",
    },
    steps = {
        { 1, 2, "Vara rúnica de cobre", { { "Barra de cobre", 1 }, { "Polvo extraño", 1 }, { "Esencia mágica menor", 1 } } },
        { 2, 75, "Encantar brazales: salud menor", { { "Polvo extraño", 1 } } },
        { 75, 100, "Encantar brazales: aguante menor", { { "Polvo extraño", 3 } } },
        { 100, 120, "Encantar capa: agilidad menor", { { "Esencia astral inferior", 1 } } },
        { 120, 155, "Encantar brazales: aguante inferior", { { "Polvo del alma", 2 } } },
        { 155, 165, "Vara rúnica de plata", { { "Vara de plata", 1 }, { "Polvo extraño", 6 } } },
        { 165, 200, "Encantar brazales: fuerza inferior", { { "Polvo del alma", 2 } }, "Entrená Experto a 125 (nivel 20)." },
        { 200, 220, "Encantar capa: defensa superior", { { "Polvo de visión", 3 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 220, 240, "Encantar guantes: agilidad", { { "Esencia mística inferior", 1 }, { "Polvo de visión", 1 } } },
        { 240, 260, "Encantar brazales: fuerza superior", { { "Polvo de sueño", 2 }, { "Esencia nether inferior", 1 } } },
        { 260, 290, "Encantar escudo: aguante superior", { { "Polvo de sueño", 5 } } },
        { 290, 300, "Encantar botas: agilidad superior", { { "Polvo de ilusión", 8 } } },
    },
}

prof {
    key = "engineering", name = "Ingeniería", spell = 4036, icon = "Interface\\Icons\\Trade_Engineering", kind = "craft",
    pair = "Minería",
    trainers = {
        A = "Forjaz, Ventormenta · Riverglades: Melbin Powderfuse (Puerto Powderfuse)",
        H = "Orgrimmar, Entrañas · Riverglades: Melbin Powderfuse (Puerto Powderfuse)",
    },
    steps = {
        { 1, 30, "Pólvora en bruto", { { "Piedra en bruto", 1 } } },
        { 30, 50, "Puñado de tornillos de cobre", { { "Barra de cobre", 1 } } },
        { 50, 51, "Llave de arco voltaico", { { "Barra de cobre", 6 } } },
        { 51, 65, "Tubo de cobre", { { "Barra de cobre", 2 }, { "Fundente débil", 1 } } },
        { 65, 75, "Bomba de cobre tosca", { { "Barra de cobre", 1 }, { "Puñado de tornillos de cobre", 1 }, { "Pólvora en bruto", 2 }, { "Paño de lino", 1 } } },
        { 75, 95, "Pólvora gruesa", { { "Piedra gruesa", 1 } } },
        { 95, 105, "Contacto de plata", { { "Barra de plata", 1 } } },
        { 105, 120, "Tubo de bronce", { { "Barra de bronce", 2 }, { "Fundente débil", 1 } } },
        { 120, 145, "Pólvora densa (pesada)", { { "Piedra pesada", 1 } } },
        { 145, 150, "Artilugio de bronce zumbante", { { "Barra de bronce", 2 }, { "Paño de lana", 1 } } },
        { 150, 175, "Puntal de hierro", { { "Barra de hierro", 2 } }, "Entrená Experto a 125 (nivel 20)." },
        { 175, 195, "Pólvora sólida", { { "Piedra sólida", 2 } } },
        { 195, 215, "Tubo de mitril", { { "Barra de mitril", 3 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 215, 238, "Gatillo inestable", { { "Barra de mitril", 1 }, { "Paño de tejido mágico", 1 }, { "Pólvora sólida", 1 } } },
        { 238, 250, "Carcasa de mitril", { { "Barra de mitril", 3 } } },
        { 250, 260, "Pólvora densa", { { "Piedra densa", 2 } } },
        { 260, 285, "Artilugio de torio", { { "Barra de torio", 3 }, { "Paño de tela rúnica", 1 } } },
        { 285, 300, "Tubo de torio", { { "Barra de torio", 6 } } },
    },
}

prof {
    key = "leatherworking", name = "Peletería", spell = 2108, icon = "Interface\\Icons\\INV_Misc_ArmorKit_17", kind = "craft",
    pair = "Desuello",
    trainers = {
        A = "Ventormenta, Darnassus · Shen'dralas: Jarael · Especializaciones: Peter Galen (Azshara, escamas), Sarah Tanner (Garganta de Fuego, elemental), Caryssia Moonhunter (Feralas, tribal)",
        H = "Orgrimmar, Cima del Trueno · Shen'dralas: Jarael · Especializaciones: Thorkaf Dragoneye (Tierras Inhóspitas), Brumn Winterhoof (Arathi), Se'Jib (Tuercespina)",
    },
    steps = {
        { 1, 35, "Kit de armadura ligera", { { "Cuero ligero", 1 } } },
        { 35, 55, "Pellejo ligero curtido", { { "Pellejo ligero", 1 }, { "Sal", 1 } } },
        { 55, 85, "Guantes de cuero repujado", { { "Cuero ligero", 3 }, { "Hilo basto", 2 } } },
        { 85, 100, "Cinturón de cuero fino", { { "Cuero ligero", 6 }, { "Hilo basto", 2 } } },
        { 100, 120, "Pellejo medio curtido", { { "Pellejo medio", 1 }, { "Sal", 1 } } },
        { 120, 150, "Botas de cuero oscuro", { { "Cuero medio", 4 }, { "Hilo fino", 2 }, { "Tinte gris", 1 } } },
        { 150, 180, "Kit de armadura pesada", { { "Cuero pesado", 5 }, { "Hilo basto", 1 } }, "Entrená Experto a 125 (nivel 20)." },
        { 180, 190, "Hombreras bárbaras", { { "Cuero pesado", 8 }, { "Pellejo pesado curtido", 1 }, { "Hilo fino", 2 } } },
        { 190, 200, "Guantes de guardián", { { "Cuero pesado", 4 }, { "Pellejo pesado curtido", 1 }, { "Hilo de seda", 1 } } },
        { 200, 220, "Kit de armadura gruesa", { { "Cuero grueso", 5 }, { "Hilo de seda", 1 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 220, 250, "Cinta de paisaje nocturno", { { "Cuero grueso", 5 }, { "Hilo de seda", 2 } } },
        { 250, 260, "Kit de armadura abrupta", { { "Cuero abrupto", 5 } } },
        { 260, 290, "Guanteletes de cuero malvado", { { "Cuero abrupto", 8 }, { "Tinte negro", 1 }, { "Hilo rúnico", 1 } } },
        { 290, 300, "Cinta de cuero malvado", { { "Cuero abrupto", 12 }, { "Tinte negro", 1 }, { "Hilo rúnico", 2 } } },
    },
}

prof {
    key = "tailoring", name = "Sastrería", spell = 3908, icon = "Interface\\Icons\\Trade_Tailoring", kind = "craft",
    pair = "Encantamiento",
    trainers = {
        A = "Ventormenta, Darnassus · Shen'dralas: Melanori",
        H = "Orgrimmar, Entrañas · Shen'dralas: Melanori",
    },
    steps = {
        { 1, 50, "Rollo de paño de lino", { { "Paño de lino", 2 } } },
        { 50, 70, "Bolsa de lino", { { "Rollo de paño de lino", 3 }, { "Hilo basto", 3 } } },
        { 70, 75, "Capa de lino reforzada", { { "Rollo de paño de lino", 2 }, { "Hilo basto", 3 } } },
        { 75, 105, "Rollo de paño de lana", { { "Paño de lana", 3 } } },
        { 105, 110, "Camisa de lana gris", { { "Rollo de paño de lana", 2 }, { "Hilo fino", 1 }, { "Tinte gris", 1 } } },
        { 110, 125, "Hombreras de lana de doble costura", { { "Rollo de paño de lana", 3 }, { "Hilo fino", 2 } } },
        { 125, 145, "Rollo de paño de seda", { { "Paño de seda", 4 } }, "Entrená Experto a 125 (nivel 20)." },
        { 145, 160, "Capucha de seda azur", { { "Rollo de paño de seda", 2 }, { "Tinte azul", 2 }, { "Hilo fino", 1 } } },
        { 160, 170, "Cinta de seda", { { "Rollo de paño de seda", 3 }, { "Hilo fino", 2 } } },
        { 170, 175, "Camisa blanca formal", { { "Rollo de paño de seda", 3 }, { "Lejía", 2 }, { "Hilo fino", 1 } } },
        { 175, 185, "Rollo de tejido mágico", { { "Paño de tejido mágico", 5 } } },
        { 185, 205, "Pantalones de seda carmesí", { { "Rollo de paño de seda", 4 }, { "Tinte rojo", 2 }, { "Hilo de seda", 2 } } },
        { 205, 220, "Leotardos de tejido mágico negro", { { "Rollo de tejido mágico", 2 }, { "Hilo de seda", 3 } }, "Entrená Artesano a 200 (nivel 35)." },
        { 220, 230, "Guantes de tejido mágico negro", { { "Rollo de tejido mágico", 2 }, { "Hilo de seda", 2 } } },
        { 230, 250, "Cinta de tejido mágico negro", { { "Rollo de tejido mágico", 3 }, { "Hilo de seda pesado", 2 } } },
        { 250, 260, "Rollo de tela rúnica", { { "Paño de tela rúnica", 5 } } },
        { 260, 275, "Cinturón de tela rúnica", { { "Rollo de tela rúnica", 3 }, { "Hilo rúnico", 1 } } },
        { 275, 280, "Bolsa de tela rúnica", { { "Rollo de tela rúnica", 5 }, { "Cuero abrupto", 2 }, { "Hilo rúnico", 1 } } },
        { 280, 300, "Guantes de tela rúnica", { { "Rollo de tela rúnica", 4 }, { "Cuero abrupto", 4 }, { "Hilo rúnico", 1 } } },
    },
}

prof {
    key = "mining", name = "Minería", spell = 2575, icon = "Interface\\Icons\\Trade_Mining", kind = "gather",
    trainers = {
        A = "Capitales · Riverglades: Grungle",
        H = "Capitales · Riverglades: Grungle",
    },
    steps = {
        { 1, 65, "Cobre", nil, "Zonas de inicio, Páramos de Poniente, Loch Modan, Durotar, Baldíos." },
        { 65, 125, "Estaño (y Plata)", nil, "Crestagrana, Bosque del Ocaso, Vallefresno, Sierra Espolón, Humedales, Trabalomas." },
        { 125, 175, "Hierro (y Oro desde 155)", nil, "Arathi, Desolace, Tierras Inhóspitas, Tuercespina, Mil Agujas. Entrená Experto a 125." },
        { 175, 245, "Mitril (y Veraplata desde 230)", nil, "Tierras Inhóspitas, Garganta de Fuego, Tierras del Interior, Tanaris, Feralas, Azshara. Entrená Artesano a 200." },
        { 245, 300, "Torio", nil, "Un'Goro, Estepas Ardientes, Tierras de la Peste, Cuna del Invierno, Silithus." },
    },
}

prof {
    key = "herbalism", name = "Herboristería", spell = 2366, icon = "Interface\\Icons\\Trade_Herbalism", kind = "gather",
    trainers = { A = "Capitales", H = "Capitales" },
    steps = {
        { 1, 70, "Flor de paz, Hojaplata, Raíz de tierra, Marregal", nil, "Zonas de inicio." },
        { 70, 115, "Brezospina, Alga estranguladora, Hierba cardenal", nil, "Baldíos, Páramos, Costa Oscura, Argénteos, Loch Modan." },
        { 115, 170, "Acérita salvaje, Sangrerreal, Musgo de tumba, Vidarraíz", nil, "Humedales, Trabalomas, Arathi, Sierra Espolón, Vallefresno. Entrená Experto a 125." },
        { 170, 230, "Pálida, Espina de oro, Mostacho de Khadgar, Flor de fuego", nil, "Tuercespina, Arathi, Desolace, Marjal, Riverglades. Entrená Artesano a 200." },
        { 230, 270, "Solea, Lágrimas de Arthas, Gromsanguina", nil, "Feralas, Tierras del Interior, Tanaris, Azshara, Frondavil." },
        { 270, 300, "Hojasueño, Sansam dorado, Salviargenta de montaña, Flor de peste, Setelo", nil, "Un'Goro, Frondavil, Tierras de la Peste, Cuna del Invierno." },
    },
}

prof {
    key = "skinning", name = "Desuello", spell = 8613, icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", kind = "gather",
    trainers = { A = "Capitales", H = "Capitales" },
    steps = {
        { 1, 75, "Cuero ligero", nil, "Bichos de nivel 1-17. Regla: podés despellejar hasta nivel 10 + skill/10 (o skill/5 por encima de 100)." },
        { 75, 150, "Cuero medio", nil, "Bichos de nivel 17-30: Baldíos, Humedales, Vallefresno, Trabalomas." },
        { 150, 225, "Cuero pesado y grueso", nil, "Bichos de nivel 30-45: Arathi, Tuercespina, Marjal, Riverglades. Entrená Experto a 125." },
        { 225, 300, "Cuero grueso y abrupto", nil, "Bichos de nivel 45-60: Feralas, Un'Goro, Cuna del Invierno, Tierras de la Peste. Entrená Artesano a 200." },
    },
}

prof {
    key = "firstaid", name = "Primeros auxilios", spell = 3273, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", kind = "craft", secondary = true,
    trainers = {
        A = "Capitales · Experto: libro en Stromgarde/Theramore · Artesano: Dr. Gustaf VanHowzen (Theramore)",
        H = "Capitales · Experto: libro en Hammerfall/Brackenwall · Artesano: Dr. Gregory Victor (Hammerfall, Arathi)",
    },
    steps = {
        { 1, 40, "Venda de lino", { { "Paño de lino", 1 } } },
        { 40, 80, "Venda de lino gruesa", { { "Paño de lino", 2 } } },
        { 80, 115, "Venda de lana", { { "Paño de lana", 1 } } },
        { 115, 150, "Venda de lana gruesa", { { "Paño de lana", 2 } } },
        { 150, 180, "Venda de seda", { { "Paño de seda", 1 } }, "Comprá el libro de Experto (Under Wraps) a 125." },
        { 180, 210, "Venda de seda gruesa", { { "Paño de seda", 2 } } },
        { 210, 240, "Venda de tejido mágico", { { "Paño de tejido mágico", 1 } } },
        { 240, 260, "Venda de tejido mágico gruesa", { { "Paño de tejido mágico", 2 } }, "Hacé la misión de triaje (Artesano) a 225." },
        { 260, 290, "Venda de tela rúnica", { { "Paño de tela rúnica", 1 } } },
        { 290, 300, "Venda de tela rúnica gruesa", { { "Paño de tela rúnica", 2 } } },
    },
}

prof {
    key = "cooking", name = "Cocina", spell = 2550, icon = "Interface\\Icons\\INV_Misc_Food_15", kind = "craft", secondary = true,
    trainers = {
        A = "Capitales · Riverglades: suministros con Miranda Turner",
        H = "Capitales · Riverglades: Gorg (Rog'mar)",
    },
    steps = {
        { 1, 50, "Carne de lobo especiada", { { "Carne de lobo pequeña", 1 }, { "Especias suaves", 1 } } },
        { 50, 90, "Filete de coyote / carne de jabalí", { { "Carne de coyote o jabalí", 1 } } },
        { 90, 130, "Pastel de cangrejo / pastel de hígado", { { "Carne de cangrejo o hígado", 1 } } },
        { 130, 175, "Brocheta de lobo sazonada", { { "Carne de lobo magra", 2 }, { "Especias calientes", 1 } }, "Comprá el libro de Experto a 125." },
        { 175, 225, "Raptor asado / salchicha de araña", { { "Carne de raptor o araña", 1 } } },
        { 225, 275, "Tortilla de monstruo / filete de lobo tierno", { { "Huevo gigante o carne de lobo tierna", 1 } }, "Artesano: misión de Dirge Quikcleave (Gadgetzan)." },
        { 275, 300, "Albóndigas del desierto ahumadas", { { "Carne de gusano de arena", 1 } } },
    },
}

prof {
    key = "fishing", name = "Pesca", spell = 7620, icon = "Interface\\Icons\\Trade_Fishing", kind = "gather", secondary = true,
    trainers = {
        A = "Capitales · Experto: Old Man Heming (Bahía del Botín) · Artesano: Nat Pagle (Marjal Revolcafango) · Riverglades: Krix",
        H = "Capitales · Experto: Old Man Heming (Bahía del Botín) · Artesano: Nat Pagle (Marjal Revolcafango) · Riverglades: Krix",
    },
    steps = {
        { 1, 75, "Cualquier agua de zona de inicio", nil, "Ciudades y zonas 1-10." },
        { 75, 150, "Baldíos, Páramos, Costa Oscura, Loch Modan", nil, "Comprá un sedal/caña mejor." },
        { 150, 225, "Tuercespina, Desolace, Arathi, Riverglades", nil, "Libro de Experto en Bahía del Botín a 125." },
        { 225, 300, "Feralas, Tanaris, Azshara, Un'Goro", nil, "Misiones de Nat Pagle para Artesano a 225." },
    },
}

---------------------------------------------------------------------------
-- Skill detection
---------------------------------------------------------------------------
local function spellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(id)
        return i and i.name
    end
    return GetSpellInfo and (GetSpellInfo(id))
end

-- returns { [key] = { rank = n, max = m } }
function P.Detect()
    local byName = {}
    for _, p in ipairs(P) do
        local n = spellName(p.spell)
        if n then byName[n:lower()] = p end
        byName[p.name:lower()] = p
    end
    local found = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
            if name and not isHeader then
                local p = byName[name:lower()]
                if p then found[p.key] = { rank = rank, max = max } end
            end
        end
    elseif GetProfessions then
        for _, idx in ipairs({ GetProfessions() }) do
            if idx then
                local name, _, rank, max = GetProfessionInfo(idx)
                local p = name and byName[name:lower()]
                if p then found[p.key] = { rank = rank, max = max } end
            end
        end
    end
    return found
end

function P.Get(key)
    for _, p in ipairs(P) do if p.key == key then return p end end
end

function P.CurrentStep(p, rank)
    for i, st in ipairs(p.steps) do
        if rank < st[2] then return i, st end
    end
    return #p.steps, p.steps[#p.steps]
end

function P.NextTier(rank, max)
    for _, t in ipairs(P.TIERS) do
        if max < t.max then
            return t, (t.from and rank >= t.from)
        end
    end
end

-- Remaining materials from `rank` to 300 (≈1 point per craft; +15% margin).
function P.ShoppingList(p, rank)
    local totals, order = {}, {}
    for _, st in ipairs(p.steps) do
        local from, to, _, mats = st[1], st[2], st[3], st[4]
        if mats and rank < to then
            local crafts = math.ceil((to - math.max(from, rank)) * 1.15)
            for _, m in ipairs(mats) do
                if not totals[m[1]] then order[#order + 1] = m[1] end
                totals[m[1]] = (totals[m[1]] or 0) + m[2] * crafts
            end
        end
    end
    local out = {}
    for _, name in ipairs(order) do out[#out + 1] = { name, totals[name] } end
    return out
end
