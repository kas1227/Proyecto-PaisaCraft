-- ============================================================
-- PAISACRAFT
-- GPS Y ORIENTACIÓN
-- ============================================================

local config =
    require("lib.config")

local utils =
    require("lib.utils")

local state =
    require("lib.state")

local gpslib = {}

-- ============================================================
-- DIRECCIONES
--
-- 0 = NORTH  -Z
-- 1 = EAST   +X
-- 2 = SOUTH  +Z
-- 3 = WEST   -X
-- ============================================================

gpslib.NORTH = 0
gpslib.EAST = 1
gpslib.SOUTH = 2
gpslib.WEST = 3

-- ============================================================
-- NOMBRE DE DIRECCIÓN
-- ============================================================

function gpslib.directionName(direction)

    if direction == gpslib.NORTH then
        return "NORTH"
    end

    if direction == gpslib.EAST then
        return "EAST"
    end

    if direction == gpslib.SOUTH then
        return "SOUTH"
    end

    if direction == gpslib.WEST then
        return "WEST"
    end

    return "UNKNOWN"

end

-- ============================================================
-- LOCALIZAR
-- ============================================================

function gpslib.locate()

    local x, y, z =
        gps.locate(
            config.GPS_TIMEOUT
        )

    if not x then

        return nil,
            "GPS no disponible."

    end

    return {

        x = utils.round(x),
        y = utils.round(y),
        z = utils.round(z)

    }

end

-- ============================================================
-- SINCRONIZAR ESTADO
-- ============================================================

function gpslib.sync()

    local position, err =
        gpslib.locate()

    if not position then
        return false, err
    end

    state.setPosition(
        position.x,
        position.y,
        position.z
    )

    state.resetGPSCounter()

    return true, position

end

-- ============================================================
-- ASEGURAR POSICIÓN
-- ============================================================

function gpslib.ensurePosition()

    if state.hasPosition() then
        return true
    end

    return gpslib.sync()

end

-- ============================================================
-- CALCULAR DIRECCIÓN
-- ============================================================

function gpslib.calculateDirection(
    x1,
    z1,
    x2,
    z2
)

    if x2 > x1 then
        return gpslib.EAST
    end

    if x2 < x1 then
        return gpslib.WEST
    end

    if z2 > z1 then
        return gpslib.SOUTH
    end

    if z2 < z1 then
        return gpslib.NORTH
    end

    return nil

end

-- ============================================================
-- COMPROBAR SI NECESITA SINCRONIZACIÓN
-- ============================================================

function gpslib.needsSync()

    return state.needsGPSSync()

end

-- ============================================================
-- SINCRONIZACIÓN PERIÓDICA
-- ============================================================

function gpslib.periodicSync()

    if not gpslib.needsSync() then
        return true
    end

    local oldPosition =
        state.getPosition()

    local ok, newPosition =
        gpslib.sync()

    if not ok then
        return false, newPosition
    end

    if
        oldPosition
        and
        (
            oldPosition.x ~= newPosition.x
            or
            oldPosition.y ~= newPosition.y
            or
            oldPosition.z ~= newPosition.z
        )
    then

        print(
            "GPS resincronizado:",
            utils.formatPosition(
                newPosition.x,
                newPosition.y,
                newPosition.z
            )
        )

    end

    return true

end

-- ============================================================
-- ACTUALIZAR POSICIÓN INTERNA
-- ============================================================

function gpslib.internalForward()

    if not state.hasPosition() then
        return false
    end

    local direction =
        state.getDirection()

    if direction == nil then
        return false
    end

    local position =
        state.position

    if direction == gpslib.NORTH then

        position.z =
            position.z - 1

    elseif direction == gpslib.EAST then

        position.x =
            position.x + 1

    elseif direction == gpslib.SOUTH then

        position.z =
            position.z + 1

    elseif direction == gpslib.WEST then

        position.x =
            position.x - 1

    else

        return false

    end

    state.movementPerformed()

    return true

end


function gpslib.internalBack()

    if not state.hasPosition() then
        return false
    end

    local direction =
        state.getDirection()

    if direction == nil then
        return false
    end

    local position =
        state.position

    if direction == gpslib.NORTH then

        position.z =
            position.z + 1

    elseif direction == gpslib.EAST then

        position.x =
            position.x - 1

    elseif direction == gpslib.SOUTH then

        position.z =
            position.z - 1

    elseif direction == gpslib.WEST then

        position.x =
            position.x + 1

    else

        return false

    end

    state.movementPerformed()

    return true

end


function gpslib.internalUp()

    if not state.hasPosition() then
        return false
    end

    state.position.y =
        state.position.y + 1

    state.movementPerformed()

    return true

end


function gpslib.internalDown()

    if not state.hasPosition() then
        return false
    end

    state.position.y =
        state.position.y - 1

    state.movementPerformed()

    return true

end

-- ============================================================
-- DETECTAR ORIENTACIÓN
-- ============================================================

function gpslib.detectOrientation(
    ensureFuelCallback
)

    if ensureFuelCallback then

        if not ensureFuelCallback() then

            return false,
                "Sin combustible para detectar orientación."

        end

    end

    print("")
    print("Detectando orientación...")

    local startPosition, err =
        gpslib.locate()

    if not startPosition then
        return false, err
    end

    for attempt = 1, 4 do

        if turtle.forward() then

            local nextPosition, nextErr =
                gpslib.locate()

            if not nextPosition then

                turtle.back()

                return false, nextErr

            end

            local detectedDirection =
                gpslib.calculateDirection(

                    startPosition.x,
                    startPosition.z,

                    nextPosition.x,
                    nextPosition.z

                )

            if detectedDirection == nil then

                turtle.back()

                return false,
                    "No pude calcular la orientación."

            end

            -- Volver al punto inicial.

            if not turtle.back() then

                turtle.turnRight()
                turtle.turnRight()

                while not turtle.forward() do
                    sleep(0.25)
                end

                turtle.turnRight()
                turtle.turnRight()

            end

            state.setDirection(
                detectedDirection
            )

            state.setPosition(

                startPosition.x,
                startPosition.y,
                startPosition.z

            )

            state.resetGPSCounter()

            print(
                "Orientación:",
                gpslib.directionName(
                    detectedDirection
                )
            )

            return true,
                detectedDirection

        end

        turtle.turnRight()

    end

    return false,
        "Las 4 direcciones están bloqueadas."

end

-- ============================================================
-- GIRO LÓGICO
--
-- Esta función solo calcula cómo debe girar.
-- movement.lua será quien realmente mueva la turtle.
-- ============================================================

function gpslib.turnDifference(
    currentDirection,
    targetDirection
)

    if
        not utils.isValidDirection(
            currentDirection
        )
    then

        return nil

    end

    if
        not utils.isValidDirection(
            targetDirection
        )
    then

        return nil

    end

    return
        (
            targetDirection
            -
            currentDirection
        )
        % 4

end

return gpslib