-- ============================================================
-- PAISACRAFT
-- NAVEGACION v6.1.5
-- ============================================================

local config =
    require("lib.config")

local utils =
    require("lib.utils")

local state =
    require("lib.state")

local gpslib =
    require("lib.gps")

local movement =
    require("lib.movement")

local navigation = {}

-- ============================================================
-- ¿ES UN BLOQUEO FISICO?
--
-- Solo estos errores permiten intentar rodear.
-- ============================================================

local function isPhysicalBlock(
    reason
)

    return
        reason == "BLOQUEADO"
        or
        reason == "RUTA_BLOQUEADA"

end

-- ============================================================
-- CONTROL
-- ============================================================

local function checkControl(
    callbacks
)

    if
        callbacks
        and
        callbacks.onControl
    then

        local continueNavigation =
            callbacks.onControl()

        if continueNavigation == false then

            return false,
                "INTERRUPTED"

        end

    end

    return true

end

-- ============================================================
-- SINCRONIZAR GPS
-- ============================================================

local function syncGPS()

    local ok,
        err =
        gpslib.sync()

    if not ok then

        return false,
            err

    end

    return true

end

-- ============================================================
-- DESVIO HORIZONTAL
--
-- Prueba:
--
-- 1. derecha
-- 2. izquierda
--
-- No intenta romper bloques.
-- ============================================================

function navigation.tryHorizontalDetour()

    local originalDirection =
        state.getDirection()

    if originalDirection == nil then

        return false,
            "ORIENTACION_DESCONOCIDA"

    end

    -- ========================================================
    -- DERECHA
    -- ========================================================

    local rightDirection =
        (
            originalDirection
            +
            1
        )
        %
        4

    local turnOK,
        turnError =
        movement.turnTo(
            rightDirection
        )

    if not turnOK then

        return false,
            turnError

    end

    local rightOK,
        rightReason =
        movement.forward()

    if rightOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    -- ========================================================
    -- ERROR NO FISICO
    -- ========================================================

    if
        not isPhysicalBlock(
            rightReason
        )
    then

        movement.turnTo(
            originalDirection
        )

        return false,
            rightReason

    end

    -- ========================================================
    -- VOLVER A ORIENTACION ORIGINAL
    -- ========================================================

    local restoreOK,
        restoreError =
        movement.turnTo(
            originalDirection
        )

    if not restoreOK then

        return false,
            restoreError

    end

    -- ========================================================
    -- IZQUIERDA
    -- ========================================================

    local leftDirection =
        (
            originalDirection
            +
            3
        )
        %
        4

    local leftTurnOK,
        leftTurnError =
        movement.turnTo(
            leftDirection
        )

    if not leftTurnOK then

        return false,
            leftTurnError

    end

    local leftOK,
        leftReason =
        movement.forward()

    if leftOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    -- ========================================================
    -- RESTAURAR ORIENTACION
    -- ========================================================

    movement.turnTo(
        originalDirection
    )

    if
        not isPhysicalBlock(
            leftReason
        )
    then

        return false,
            leftReason

    end

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- RODEAR OBSTACULO
--
-- Orden:
--
-- 1. lateral
-- 2. arriba
-- 3. abajo
--
-- Tras cualquier movimiento exitoso el loop principal
-- recalculara el camino hacia el destino.
-- ============================================================

function navigation.moveAroundObstacle()

    -- ========================================================
    -- LATERAL
    -- ========================================================

    local sideOK,
        sideReason =
        navigation.tryHorizontalDetour()

    if sideOK then

        return true

    end

    if
        not isPhysicalBlock(
            sideReason
        )
    then

        return false,
            sideReason

    end

    -- ========================================================
    -- ARRIBA
    -- ========================================================

    local upOK,
        upReason =
        movement.up()

    if upOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if
        not isPhysicalBlock(
            upReason
        )
    then

        return false,
            upReason

    end

    -- ========================================================
    -- ABAJO
    -- ========================================================

    local downOK,
        downReason =
        movement.down()

    if downOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if
        not isPhysicalBlock(
            downReason
        )
    then

        return false,
            downReason

    end

    return false,
        "BLOQUEADO"

end

-- ============================================================
-- MOVIMIENTO HORIZONTAL
-- ============================================================

function navigation.moveHorizontal(
    targetDirection
)

    local turnOK,
        turnError =
        movement.turnTo(
            targetDirection
        )

    if not turnOK then

        return false,
            turnError

    end

    local moved,
        reason =
        movement.forward()

    if moved then

        return true

    end

    -- ========================================================
    -- ERROR NO FISICO
    -- ========================================================

    if
        not isPhysicalBlock(
            reason
        )
    then

        return false,
            reason

    end

    print(
        "Obstaculo -> buscando desvio."
    )

    local detourOK,
        detourReason =
        navigation.moveAroundObstacle()

    if detourOK then

        return true

    end

    return false,
        detourReason
        or
        "RUTA_BLOQUEADA"

end

-- ============================================================
-- ¿ESTAMOS EN DESTINO?
-- ============================================================

function navigation.atPosition(
    targetX,
    targetY,
    targetZ
)

    if not state.hasPosition() then

        return false

    end

    return
        state.position.x == targetX
        and
        state.position.y == targetY
        and
        state.position.z == targetZ

end

-- ============================================================
-- CONFIRMAR DESTINO CON GPS
-- ============================================================

function navigation.confirmPosition(
    targetX,
    targetY,
    targetZ
)

    local ok,
        err =
        gpslib.sync()

    if not ok then

        return false,
            err

    end

    if
        navigation.atPosition(
            targetX,
            targetY,
            targetZ
        )
    then

        return true

    end

    return false,
        "POSICION_GPS_NO_COINCIDE"

end

-- ============================================================
-- PASO DIRECTO
--
-- Prioridad:
--
-- X
-- Z
-- Y
--
-- Esto mantiene el comportamiento original de PaisaCraft.
-- ============================================================

function navigation.directStep(
    targetX,
    targetY,
    targetZ
)

    if not state.hasPosition() then

        return false,
            "POSICION_DESCONOCIDA"

    end

    local position =
        state.position

    -- ========================================================
    -- X
    -- ========================================================

    if position.x < targetX then

        return navigation.moveHorizontal(
            gpslib.EAST
        )

    elseif position.x > targetX then

        return navigation.moveHorizontal(
            gpslib.WEST
        )

    end

    -- ========================================================
    -- Z
    -- ========================================================

    if position.z < targetZ then

        return navigation.moveHorizontal(
            gpslib.SOUTH
        )

    elseif position.z > targetZ then

        return navigation.moveHorizontal(
            gpslib.NORTH
        )

    end

    -- ========================================================
    -- Y
    -- ========================================================

    if position.y < targetY then

        return movement.up()

    elseif position.y > targetY then

        return movement.down()

    end

    return true

end

-- ============================================================
-- PASO DE ESCAPE
--
-- Se usa cuando la turtle empieza a visitar
-- repetidamente la misma posicion.
--
-- Orden:
--
-- arriba
-- lateral
-- abajo
-- ============================================================

function navigation.escapeStep()

    -- ========================================================
    -- ARRIBA
    -- ========================================================

    local upOK,
        upReason =
        movement.up()

    if upOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if
        not isPhysicalBlock(
            upReason
        )
    then

        return false,
            upReason

    end

    -- ========================================================
    -- LATERAL
    -- ========================================================

    local sideOK,
        sideReason =
        navigation.tryHorizontalDetour()

    if sideOK then

        return true

    end

    if
        not isPhysicalBlock(
            sideReason
        )
    then

        return false,
            sideReason

    end

    -- ========================================================
    -- ABAJO
    -- ========================================================

    local downOK,
        downReason =
        movement.down()

    if downOK then

        local gpsOK,
            gpsError =
            syncGPS()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if
        not isPhysicalBlock(
            downReason
        )
    then

        return false,
            downReason

    end

    return false,
        downReason
        or
        "BLOQUEADO"

end

-- ============================================================
-- IR A COORDENADA
-- ============================================================

function navigation.goTo(
    targetX,
    targetY,
    targetZ,
    callbacks
)

    callbacks =
        callbacks
        or
        {}

    -- ========================================================
    -- VALIDACION
    -- ========================================================

    if
        type(targetX)
        ~=
        "number"

        or

        type(targetY)
        ~=
        "number"

        or

        type(targetZ)
        ~=
        "number"
    then

        return false,
            "DESTINO_INVALIDO"

    end

    -- ========================================================
    -- POSICION + ORIENTACION
    -- ========================================================

    local navigationOK,
        navigationError =
        movement.ensureNavigationState()

    if not navigationOK then

        return false,
            navigationError

    end

    -- ========================================================
    -- CONTADORES
    -- ========================================================

    local steps =
        0

    local visited =
        {}

    -- ========================================================
    -- LOOP
    -- ========================================================

    while true do

        -- ====================================================
        -- CONTROL
        --
        -- Permite:
        --
        -- pausa
        -- resume
        -- return home
        -- interrupciones
        -- ====================================================

        local controlOK,
            controlError =
            checkControl(
                callbacks
            )

        if not controlOK then

            return false,
                controlError

        end

        -- ====================================================
        -- GPS PERIODICO
        --
        -- movement.lua incrementa el contador.
        --
        -- gpslib.periodicSync() solo hace GPS
        -- cuando realmente se alcanza el intervalo.
        -- ====================================================

        local gpsOK,
            gpsError =
            gpslib.periodicSync()

        if not gpsOK then

            return false,
                gpsError

        end

        -- ====================================================
        -- DESTINO
        -- ====================================================

        if
            navigation.atPosition(
                targetX,
                targetY,
                targetZ
            )
        then

            -- =================================================
            -- VERIFICACION GPS REAL
            -- =================================================

            local confirmed,
                confirmError =
                navigation.confirmPosition(

                    targetX,
                    targetY,
                    targetZ

                )

            if confirmed then

                return true

            end

            -- =================================================
            -- GPS DICE QUE NO ESTAMOS REALMENTE AHI
            --
            -- Como gpslib.sync() actualizo state.position,
            -- simplemente continuamos navegando desde la
            -- posicion real.
            -- =================================================

            if
                confirmError
                ~=
                "POSICION_GPS_NO_COINCIDE"
            then

                return false,
                    confirmError

            end

        end

        -- ====================================================
        -- LIMITE DE SEGURIDAD
        -- ====================================================

        steps =
            steps
            +
            1

        if
            steps
            >
            config.MAX_NAV_STEPS
        then

            return false,
                "MAX_NAV_STEPS"

        end

        -- ====================================================
        -- POSICION ACTUAL
        -- ====================================================

        if not state.hasPosition() then

            return false,
                "POSICION_PERDIDA"

        end

        local key =
            utils.positionKey(

                state.position.x,
                state.position.y,
                state.position.z

            )

        visited[key] =
            (
                visited[key]
                or
                0
            )
            +
            1

        local visits =
            visited[key]

        local moved =
            false

        local reason =
            nil

        -- ====================================================
        -- RUTA DIRECTA
        -- ====================================================

        if
            visits
            <
            config.MAX_POSITION_VISITS
        then

            moved,
            reason =
                navigation.directStep(

                    targetX,
                    targetY,
                    targetZ

                )

        end

        -- ====================================================
        -- ERROR NO FISICO
        --
        -- SIN_FUEL, GPS, orientación, etc.
        -- no deben provocar intentos de desvio.
        -- ====================================================

        if
            not moved
            and
            reason
            and
            not isPhysicalBlock(
                reason
            )
        then

            return false,
                reason

        end

        -- ====================================================
        -- DESVIO
        -- ====================================================

        if not moved then

            moved,
            reason =
                navigation.moveAroundObstacle()

        end

        if
            not moved
            and
            reason
            and
            not isPhysicalBlock(
                reason
            )
        then

            return false,
                reason

        end

        -- ====================================================
        -- POSICION REPETIDA
        --
        -- Si hemos estado demasiadas veces en la
        -- misma coordenada intentamos un escape.
        -- ====================================================

        if
            visits
            >=
            config.MAX_POSITION_VISITS

            and

            not moved
        then

            print(
                "Ruta repetida -> escape."
            )

            moved,
            reason =
                navigation.escapeStep()

        end

        if
            not moved
            and
            reason
            and
            not isPhysicalBlock(
                reason
            )
        then

            return false,
                reason

        end

        -- ====================================================
        -- RUTA COMPLETAMENTE BLOQUEADA
        -- ====================================================

        if not moved then

            print("")
            print("==============================")
            print("        RUTA BLOQUEADA")
            print("==============================")

            print("")

            print(
                "Actual:",
                utils.formatPosition(

                    state.position.x,
                    state.position.y,
                    state.position.z

                )
            )

            print(
                "Destino:",
                utils.formatPosition(

                    targetX,
                    targetY,
                    targetZ

                )
            )

            print("")
            print(
                "Reintentando..."
            )

            -- =================================================
            -- CONTROL DURANTE ESPERA
            -- =================================================

            local waitControlOK,
                waitControlError =
                checkControl(
                    callbacks
                )

            if not waitControlOK then

                return false,
                    waitControlError

            end

            sleep(1)

        end

    end

end

-- ============================================================
-- IR A OBJETO POSITION
-- ============================================================

function navigation.goToPosition(
    position,
    callbacks
)

    if
        not utils.isValidPosition(
            position
        )
    then

        return false,
            "POSICION_INVALIDA"

    end

    return navigation.goTo(

        position.x,
        position.y,
        position.z,

        callbacks

    )

end

-- ============================================================
-- IR A POSITION Y RESTAURAR DIRECCION
--
-- Util cuando en el futuro queramos almacenar:
--
-- {
--     x = ...,
--     y = ...,
--     z = ...,
--     direction = ...
-- }
--
-- Si direction no existe, simplemente llega a X/Y/Z.
-- ============================================================

function navigation.goToPositionAndDirection(
    position,
    callbacks
)

    local ok,
        err =
        navigation.goToPosition(

            position,

            callbacks

        )

    if not ok then

        return false,
            err

    end

    if
        position.direction
        ~=
        nil
    then

        local turnOK,
            turnError =
            movement.turnTo(
                position.direction
            )

        if not turnOK then

            return false,
                turnError

        end

    end

    return true

end

-- ============================================================
-- DISTANCIA HASTA DESTINO
-- ============================================================

function navigation.distanceTo(
    targetX,
    targetY,
    targetZ
)

    if not state.hasPosition() then

        return nil

    end

    return utils.manhattanDistance(

        state.position.x,
        state.position.y,
        state.position.z,

        targetX,
        targetY,
        targetZ

    )

end

-- ============================================================
-- DISTANCIA HASTA POSITION
-- ============================================================

function navigation.distanceToPosition(
    position
)

    if
        not utils.isValidPosition(
            position
        )
    then

        return nil

    end

    return navigation.distanceTo(

        position.x,
        position.y,
        position.z

    )

end

-- ============================================================
-- ESTADISTICAS
-- ============================================================

function navigation.getStats()

    return {

        position =
            state.getPosition(),

        direction =
            state.getDirection(),

        directionName =
            gpslib.directionName(
                state.getDirection()
            )

    }

end

return navigation
