-- ============================================================
-- PAISACRAFT
-- GPS Y ORIENTACION v6.1.5
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

gpslib.NORTH =
    0

gpslib.EAST =
    1

gpslib.SOUTH =
    2

gpslib.WEST =
    3

-- ============================================================
-- NOMBRE DE DIRECCION
-- ============================================================

function gpslib.directionName(
    direction
)

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
-- VALIDAR DIRECCION
-- ============================================================

function gpslib.isValidDirection(
    direction
)

    return
        direction == gpslib.NORTH
        or
        direction == gpslib.EAST
        or
        direction == gpslib.SOUTH
        or
        direction == gpslib.WEST

end

-- ============================================================
-- LOCALIZAR
-- ============================================================

function gpslib.locate()

    local x,
        y,
        z =
        gps.locate(
            config.GPS_TIMEOUT
        )

    if not x then

        return nil,
            "GPS_NO_DISPONIBLE"

    end

    return {

        x =
            utils.round(x),

        y =
            utils.round(y),

        z =
            utils.round(z)

    }

end

-- ============================================================
-- SINCRONIZAR ESTADO
-- ============================================================

function gpslib.sync()

    local position,
        err =
        gpslib.locate()

    if not position then

        return false,
            err

    end

    state.setPosition(

        position.x,
        position.y,
        position.z

    )

    state.resetGPSCounter()

    return true,
        position

end

-- ============================================================
-- ASEGURAR POSICION
-- ============================================================

function gpslib.ensurePosition()

    if state.hasPosition() then

        return true

    end

    return gpslib.sync()

end

-- ============================================================
-- CALCULAR DIRECCION
--
-- Calcula la direccion horizontal entre
-- dos posiciones consecutivas.
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
-- VECTOR DE DIRECCION
-- ============================================================

function gpslib.directionVector(
    direction
)

    if direction == gpslib.NORTH then

        return {
            x = 0,
            z = -1
        }

    end

    if direction == gpslib.EAST then

        return {
            x = 1,
            z = 0
        }

    end

    if direction == gpslib.SOUTH then

        return {
            x = 0,
            z = 1
        }

    end

    if direction == gpslib.WEST then

        return {
            x = -1,
            z = 0
        }

    end

    return nil

end

-- ============================================================
-- COMPROBAR SI NECESITA SINCRONIZACION
-- ============================================================

function gpslib.needsSync()

    return
        state.needsGPSSync()

end

-- ============================================================
-- SINCRONIZACION PERIODICA
-- ============================================================

function gpslib.periodicSync()

    if not gpslib.needsSync() then

        return true

    end

    local oldPosition =
        state.getPosition()

    local ok,
        newPosition =
        gpslib.sync()

    if not ok then

        return false,
            newPosition

    end

    -- ========================================================
    -- INFORMAR SI HUBO DESVIACION
    -- ========================================================

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

        print("")
        print(
            "GPS resincronizado:"
        )

        print(
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
-- ACTUALIZAR POSICION INTERNA
--
-- IMPORTANTE:
--
-- Estas funciones NO incrementan movementsSinceGPS.
--
-- movement.lua es el unico responsable de llamar:
--
-- state.movementPerformed()
--
-- despues de confirmar que el movimiento fue exitoso.
-- ============================================================

-- ============================================================
-- FORWARD INTERNO
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
            position.z
            -
            1

    elseif direction == gpslib.EAST then

        position.x =
            position.x
            +
            1

    elseif direction == gpslib.SOUTH then

        position.z =
            position.z
            +
            1

    elseif direction == gpslib.WEST then

        position.x =
            position.x
            -
            1

    else

        return false

    end

    return true

end

-- ============================================================
-- BACK INTERNO
-- ============================================================

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
            position.z
            +
            1

    elseif direction == gpslib.EAST then

        position.x =
            position.x
            -
            1

    elseif direction == gpslib.SOUTH then

        position.z =
            position.z
            -
            1

    elseif direction == gpslib.WEST then

        position.x =
            position.x
            +
            1

    else

        return false

    end

    return true

end

-- ============================================================
-- UP INTERNO
-- ============================================================

function gpslib.internalUp()

    if not state.hasPosition() then

        return false

    end

    state.position.y =
        state.position.y
        +
        1

    return true

end

-- ============================================================
-- DOWN INTERNO
-- ============================================================

function gpslib.internalDown()

    if not state.hasPosition() then

        return false

    end

    state.position.y =
        state.position.y
        -
        1

    return true

end

-- ============================================================
-- INTENTAR VOLVER AL PUNTO INICIAL
--
-- Se utiliza durante deteccion de orientacion.
-- ============================================================

local function returnAfterOrientationTest()

    -- ========================================================
    -- PRIMER INTENTO:
    -- simplemente retroceder.
    -- ========================================================

    if turtle.back() then

        return true

    end

    -- ========================================================
    -- FALLBACK:
    --
    -- girar 180 grados,
    -- avanzar al punto anterior,
    -- volver a orientacion original.
    -- ========================================================

    turtle.turnRight()
    turtle.turnRight()

    local attempts =
        0

    while
        not turtle.forward()
    do

        attempts =
            attempts
            +
            1

        if
            attempts
            >=
            config.ENTITY_RETRIES
        then

            turtle.turnRight()
            turtle.turnRight()

            return false,
                "NO_PUDE_VOLVER_TRAS_DETECTAR_ORIENTACION"

        end

        sleep(
            config.ENTITY_WAIT
        )

    end

    turtle.turnRight()
    turtle.turnRight()

    return true

end

-- ============================================================
-- DETECTAR ORIENTACION
--
-- Metodo:
--
-- 1. GPS posicion inicial.
-- 2. Intentar avanzar.
-- 3. GPS posicion nueva.
-- 4. Comparar X/Z.
-- 5. Volver al punto inicial.
--
-- Si delante esta bloqueado:
-- gira a la derecha y prueba otra direccion.
-- ============================================================

function gpslib.detectOrientation(
    ensureFuelCallback
)

    -- ========================================================
    -- COMBUSTIBLE
    -- ========================================================

    if ensureFuelCallback then

        if
            not ensureFuelCallback()
        then

            return false,
                "SIN_FUEL_PARA_ORIENTACION"

        end

    end

    print("")
    print(
        "Detectando orientacion..."
    )

    -- ========================================================
    -- POSICION INICIAL
    -- ========================================================

    local startPosition,
        startError =
        gpslib.locate()

    if not startPosition then

        return false,
            startError

    end

    -- ========================================================
    -- PROBAR HASTA LAS 4 DIRECCIONES
    -- ========================================================

    for attempt =
        1,
        4
    do

        -- ====================================================
        -- INTENTAR AVANZAR
        -- ====================================================

        if turtle.forward() then

            -- =================================================
            -- GPS SEGUNDO PUNTO
            -- =================================================

            local nextPosition,
                nextError =
                gpslib.locate()

            if not nextPosition then

                returnAfterOrientationTest()

                return false,
                    nextError

            end

            -- =================================================
            -- CALCULAR ORIENTACION
            -- =================================================

            local detectedDirection =
                gpslib.calculateDirection(

                    startPosition.x,
                    startPosition.z,

                    nextPosition.x,
                    nextPosition.z

                )

            if detectedDirection == nil then

                returnAfterOrientationTest()

                return false,
                    "NO_PUDE_CALCULAR_ORIENTACION"

            end

            -- =================================================
            -- VOLVER AL PUNTO ORIGINAL
            -- =================================================

            local returnOK,
                returnError =
                returnAfterOrientationTest()

            if not returnOK then

                return false,
                    returnError

            end

            -- =================================================
            -- GUARDAR DIRECCION
            -- =================================================

            state.setDirection(
                detectedDirection
            )

            -- =================================================
            -- GUARDAR POSICION ORIGINAL
            --
            -- Aunque hicimos movimientos fisicos durante
            -- la deteccion, terminamos exactamente donde
            -- empezamos.
            -- =================================================

            state.setPosition(

                startPosition.x,
                startPosition.y,
                startPosition.z

            )

            state.resetGPSCounter()

            print(
                "Orientacion:",
                gpslib.directionName(
                    detectedDirection
                )
            )

            return true,
                detectedDirection

        end

        -- ====================================================
        -- BLOQUEADO:
        -- probar siguiente direccion.
        -- ====================================================

        turtle.turnRight()

    end

    -- Tras cuatro giros estamos otra vez
    -- orientados como al comenzar.

    return false,
        "LAS_4_DIRECCIONES_BLOQUEADAS"

end

-- ============================================================
-- GIRO LOGICO
--
-- Devuelve:
--
-- 0 = no girar
-- 1 = derecha
-- 2 = 180 grados
-- 3 = izquierda
-- ============================================================

function gpslib.turnDifference(
    currentDirection,
    targetDirection
)

    if
        not gpslib.isValidDirection(
            currentDirection
        )
    then

        return nil

    end

    if
        not gpslib.isValidDirection(
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
        %
        4

end

-- ============================================================
-- DIRECCION ENTRE DOS POSICIONES
-- ============================================================

function gpslib.directionBetween(
    from,
    to
)

    if
        not from
        or
        not to
    then

        return nil

    end

    return gpslib.calculateDirection(

        from.x,
        from.z,

        to.x,
        to.z

    )

end

-- ============================================================
-- ESTADISTICAS
-- ============================================================

function gpslib.getStats()

    return {

        position =
            state.getPosition(),

        direction =
            state.getDirection(),

        directionName =
            gpslib.directionName(
                state.getDirection()
            ),

        movementsSinceSync =
            state.movementsSinceGPS,

        needsSync =
            gpslib.needsSync()

    }

end

return gpslib
