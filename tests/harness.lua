-- Loads the addon's pure-Lua modules (and data files) outside the game, the way the client does:
-- every file gets ("SakedMap", ns) as its varargs.
local H = {}

local ROOT = (arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]+$")) or "."

function H.root() return ROOT end

function H.run(path, ns)
    local chunk = assert(loadfile(ROOT .. "/" .. path))
    return chunk("SakedMap", ns)
end

function H.load(ns)
    ns = ns or {}
    H.run("SakedMap/Grid.lua", ns)
    H.run("SakedMap/Filter.lua", ns)
    return ns
end

function H.loadData(ns, mapID)
    H.run("SakedMap/Data/M" .. mapID .. ".lua", ns)
    return ns.data[mapID]
end

return H
