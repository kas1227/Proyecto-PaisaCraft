-- ============================================================
-- PAISACRAFT
-- MOVIMIENTO DE LA TURTLE v6.1.5
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local gpslib =
    require("lib.gps")

local movement = {}

-- ============================================================
-- COMBUSTIBLE
-- ============================================================

function movement.getFuelLevel()

    local fuel =
        turtle.getFuelLevel()

    if fuel == "unlimited" then

        return math.huge

    end

    return fuel

end

-- ============================================================
-- COMBUSTIBLE DE EMERGENCIA
--
-- Solo utiliza slots 1-15.
-- Slot 16 queda reservado para bloques retirados.
-- ============================================================

function movement.tryInventoryFuel()

    if movement.getFuelLevel() > 0 then

        return true

    end

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if
            turtle.getItemCount(slot)
            >
            0
        then

            turtle.select(slot)

            if turtle.refuel(0) then

                if turtle.refuel(1) then

                    print(
                        "Fuel emergencia:",
                        movement.getFuelLevel()
                    )

                    state.clearBuildingSlot()

                    return true

                end

            end

        end

    end

    return false

end

-- ============================================================
-- ASEGURAR COMBUSTIBLE
-- ============================================================

function movement.ensureFuel()

    if movement.getFuelLevel() > 0 then

        return true

    end

    return movement.tryInventoryFuel()

end

-- ============================================================
-- GPS PERIODICO
-- ============================================================

local function periodicGPS()

    if not state.needsGPSSync() then

        return true

    end

    local ok,
        err =
        gpslib.periodicSync()

    if not ok then

        return false,
            err
            or
            "GPS_SYNC_FAILED"

    end

    state.resetGPSCounter()

    return true

end

-- ============================================================
-- DESPUES DE UN MOVIMIENTO
-- ============================================================

local function afterMovement(
    internalUpdate
)

    local internalOK =
        internalUpdate()

    if not internalOK then

        return false,
            "ERROR_POSICION_INTERNA"

    end

    state.movementPerformed()

    local gpsOK,
        gpsError =
        periodicGPS()

    if not gpsOK then

        return false,
            gpsError

    end

    return true

end

-- ============================================================
-- FORWARD
-- ============================================================

function movement.forward()

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    if not movement.ensureFuel() then

        return false,
            "SIN_FUEL"

    end

    -- ========================================================
    -- MOVIMIENTO NORMAL
    -- ========================================================

    if turtle.forward() then

        return afterMovement(
            gpslib.internalForward
        )

    end

    -- ========================================================
    -- POSIBLE ENTIDAD
    --
    -- Si no hay bloque pero tampoco podemos avanzar,
    -- probablemente hay una entidad.
    -- ========================================================

    if not turtle.detect() then

        for attempt =
            1,
            config.ENTITY_RETRIES
        do

            sleep(
                config.ENTITY_WAIT
            )

            if turtle.forward() then

                return afterMovement(
                    gpslib.internalForward
                )

            end

        end

    end

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- BACK
-- ============================================================

function movement.back()

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    if not movement.ensureFuel() then

        return false,
            "SIN_FUEL"

    end

    if turtle.back() then

        return afterMovement(
            gpslib.internalBack
        )

    end

    -- turtle.back() no tiene detectBack().
    -- Si falla, simplemente consideramos
    -- que el camino esta bloqueado.

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- UP
-- ============================================================

function movement.up()

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    if not movement.ensureFuel() then

        return false,
            "SIN_FUEL"

    end

    if turtle.up() then

        return afterMovement(
            gpslib.internalUp
        )

    end

    -- ========================================================
    -- POSIBLE ENTIDAD
    -- ========================================================

    if not turtle.detectUp() then

        for attempt =
            1,
            config.ENTITY_RETRIES
        do

            sleep(
                config.ENTITY_WAIT
            )

            if turtle.up() then

                return afterMovement(
                    gpslib.internalUp
                )

            end

        end

    end

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- DOWN
-- ============================================================

function movement.down()

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    if not movement.ensureFuel() then

        return false,
            "SIN_FUEL"

    end

    if turtle.down() then

        return afterMovement(
            gpslib.internalDown
        )

    end

    -- ========================================================
    -- POSIBLE ENTIDAD
    -- ========================================================

    if not turtle.detectDown() then

        for attempt =
            1,
            config.ENTITY_RETRIES
        do

            sleep(
                config.ENTITY_WAIT
            )

            if turtle.down() then

                return afterMovement(
                    gpslib.internalDown
                )

            end

        end

    end

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- GIRO IZQUIERDA
-- ============================================================

function movement.turnLeft()

    local direction =
        state.getDirection()

    if direction == nil then

        return false,
            "ORIENTACION_DESCONOCIDA"

    end

    local ok =
        turtle.turnLeft()

    if not ok then

        return false,
            "GIRO_FALLIDO"

    end

    state.setDirection(
        (
            direction
            +
            3
        )
        %
        4
    )

    return true

end

-- ============================================================
-- GIRO DERECHA
-- ============================================================

function movement.turnRight()

    local direction =
        state.getDirection()

    if direction == nil then

        return false,
            "ORIENTACION_DESCONOCIDA"

    end

    local ok =
        turtle.turnRight()

    if not ok then

        return false,
            "GIRO_FALLIDO"

    end

    state.setDirection(
        (
            direction
            +
            1
        )
        %
        4
    )

    return true

end

-- ============================================================
-- GIRAR HACIA DIRECCION
-- ============================================================

function movement.turnTo(
    targetDirection
)

    local currentDirection =
        state.getDirection()

    if currentDirection == nil then

        return false,
            "ORIENTACION_DESCONOCIDA"

    end

    local difference =
        gpslib.turnDifference(
            currentDirection,
            targetDirection
        )

    if difference == nil then

        return false,
            "DIRECCION_INVALIDA"

    end

    if difference == 0 then

        return true

    end

    if difference == 1 then

        return movement.turnRight()

    end

    if difference == 2 then

        local firstOK,
            firstError =
            movement.turnRight()

        if not firstOK then

            return false,
                firstError

        end

        return movement.turnRight()

    end

    if difference == 3 then

        return movement.turnLeft()

    end

    return false,
        "GIRO_INVALIDO"

end

-- ============================================================
-- MOVER HACIA UNA DIRECCION
-- ============================================================

function movement.moveDirection(
    direction
)

    local turnOK,
        turnError =
        movement.turnTo(
            direction
        )

    if not turnOK then

        return false,
            turnError

    end

    return movement.forward()

end

-- ============================================================
-- ASEGURAR ORIENTACION
--
-- Tras un reboot:
--
-- state.direction = nil
--
-- Se detecta orientacion usando GPS.
-- ============================================================

function movement.ensureOrientation()

    if
        state.getDirection()
        ~=
        nil
    then

        return true

    end

    local ok,
        err =
        gpslib.detectOrientation(
            movement.ensureFuel
        )

    if not ok then

        return false,
            err
            or
            "NO_SE_PUDO_DETECTAR_ORIENTACION"

    end

    if
        state.getDirection()
        ==
        nil
    then

        return false,
            "ORIENTACION_SIGUE_DESCONOCIDA"

    end

    return true

end

-- ============================================================
-- ASEGURAR POSICION Y ORIENTACION
--
-- Util para recuperaciones tras reboot.
-- ============================================================

function movement.ensureNavigationState()

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        return false,
            orientationError

    end

    return true

end

-- ============================================================
-- ESTADISTICAS
-- ============================================================

function movement.getStats()

    return {

        fuel =
            movement.getFuelLevel(),

        position =
            state.getPosition(),

        direction =
            state.getDirection(),

        gpsMovements =
            state.movementsSinceGPS

    }

end

return movement
