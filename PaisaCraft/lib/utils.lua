-- ============================================================
-- PAISACRAFT
-- UTILIDADES GENERALES
-- ============================================================

local utils = {}

-- ============================================================
-- ARCHIVOS Y DIRECTORIOS
-- ============================================================

function utils.ensureDirectory(path)

    if not path or path == "" then
        return false
    end

    if fs.exists(path) then
        return fs.isDir(path)
    end

    fs.makeDir(path)

    return fs.exists(path)
end


function utils.ensureParentDirectory(filename)

    local dir = fs.getDir(filename)

    if dir and dir ~= "" then
        return utils.ensureDirectory(dir)
    end

    return true
end


function utils.fileExists(filename)

    return fs.exists(filename)
end


function utils.deleteFile(filename)

    if fs.exists(filename) then
        fs.delete(filename)
    end
end


function utils.saveTable(filename, data)

    utils.ensureParentDirectory(filename)

    local file = fs.open(filename, "w")

    if not file then
        return false, "No puedo abrir " .. tostring(filename)
    end

    file.write(
        textutils.serialize(data)
    )

    file.close()

    return true
end


function utils.loadTable(filename)

    if not fs.exists(filename) then
        return nil
    end

    local file = fs.open(filename, "r")

    if not file then
        return nil
    end

    local content = file.readAll()

    file.close()

    if not content or content == "" then
        return nil
    end

    return textutils.unserialize(content)
end

-- ============================================================
-- TABLAS
-- ============================================================

function utils.copyTable(tbl)

    if type(tbl) ~= "table" then
        return tbl
    end

    local result = {}

    for key, value in pairs(tbl) do

        if type(value) == "table" then
            result[key] = utils.copyTable(value)
        else
            result[key] = value
        end
    end

    return result
end


function utils.tableContains(tbl, value)

    if type(tbl) ~= "table" then
        return false
    end

    for _, current in pairs(tbl) do

        if current == value then
            return true
        end
    end

    return false
end


function utils.tableSize(tbl)

    if type(tbl) ~= "table" then
        return 0
    end

    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

-- ============================================================
-- NÚMEROS
-- ============================================================

function utils.round(value)

    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end


function utils.clamp(value, minimum, maximum)

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end


function utils.sign(value)

    if value > 0 then
        return 1
    elseif value < 0 then
        return -1
    end

    return 0
end

-- ============================================================
-- DISTANCIAS
-- ============================================================

function utils.manhattanDistance(
    x1,
    y1,
    z1,
    x2,
    y2,
    z2
)

    return
        math.abs(x2 - x1)
        +
        math.abs(y2 - y1)
        +
        math.abs(z2 - z1)
end


function utils.horizontalDistance(
    x1,
    z1,
    x2,
    z2
)

    return
        math.abs(x2 - x1)
        +
        math.abs(z2 - z1)
end

-- ============================================================
-- POSICIONES
-- ============================================================

function utils.positionKey(x, y, z)

    return
        tostring(x)
        .. ","
        .. tostring(y)
        .. ","
        .. tostring(z)
end


function utils.samePosition(a, b)

    if not a or not b then
        return false
    end

    return
        a.x == b.x
        and
        a.y == b.y
        and
        a.z == b.z
end


function utils.copyPosition(position)

    if not position then
        return nil
    end

    return {
        x = position.x,
        y = position.y,
        z = position.z
    }
end

-- ============================================================
-- VALIDACIÓN
-- ============================================================

function utils.isValidPosition(position)

    if type(position) ~= "table" then
        return false
    end

    return
        type(position.x) == "number"
        and
        type(position.y) == "number"
        and
        type(position.z) == "number"
end


function utils.isValidDirection(direction)

    return
        type(direction) == "number"
        and
        direction >= 0
        and
        direction <= 3
end


function utils.isValidBuildMode(mode)

    return
        mode == "PLACE"
        or
        mode == "REPLACE"
        or
        mode == "CLEAR"
end

-- ============================================================
-- STRINGS
-- ============================================================

function utils.safeToString(value)

    if value == nil then
        return "nil"
    end

    return tostring(value)
end


function utils.formatPosition(x, y, z)

    return
        tostring(x)
        .. ", "
        .. tostring(y)
        .. ", "
        .. tostring(z)
end

-- ============================================================
-- LOG
-- ============================================================

function utils.log(...)

    print(...)
end


function utils.debug(enabled, ...)

    if enabled then
        print("[DEBUG]", ...)
    end
end

return utils