-- ============================================================
-- PAISACRAFT
-- NAVEGACIÓN v6.1.1
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
-- ¿ES UN BLOQUEO FÍSICO?
--
-- Solo los errores BLOQUEADO deben provocar desvíos.
-- ============================================================

local function isPhysicalBlock(reason)

    return
        reason == "BLOQUEADO"
        or
        reason == "RUTA_BLOQUEADA"

end

-- ============================================================
-- DESVÍO HORIZONTAL
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

    local turnOK,
        turnError =
        movement.turnTo(
            (originalDirection + 1) % 4
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
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    -- Si no es un obstáculo físico,
    -- no tiene sentido seguir intentando desvíos.

    if not isPhysicalBlock(
        rightReason
    )
    then

        return false,
            rightReason

    end

    movement.turnTo(
        originalDirection
    )

    -- ========================================================
    -- IZQUIERDA
    -- ========================================================

    local leftTurnOK,
        leftTurnError =
        movement.turnTo(
            (originalDirection + 3) % 4
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
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    movement.turnTo(
        originalDirection
    )

    if not isPhysicalBlock(
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
-- RODEAR OBSTÁCULO
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

    if not isPhysicalBlock(
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
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if not isPhysicalBlock(
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
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if not isPhysicalBlock(
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
    -- ERROR QUE NO ES OBSTÁCULO
    -- ========================================================

    if not isPhysicalBlock(reason) then

        return false,
            reason

    end

    print(
        "Obstáculo -> buscando desvío."
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
-- ¿ESTAMOS EN EL DESTINO?
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
-- CONFIRMAR DESTINO
-- ============================================================

function navigation.confirmPosition(
    targetX,
    targetY,
    targetZ
)

    local ok, err =
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
-- ============================================================

function navigation.directStep(
    targetX,
    targetY,
    targetZ
)

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
-- ESCAPE
-- ============================================================

function navigation.escapeStep()

    local upOK,
        upReason =
        movement.up()

    if upOK then

        local gpsOK,
            gpsError =
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

    end

    if not isPhysicalBlock(
        upReason
    )
    then

        return false,
            upReason

    end

    local sideOK,
        sideReason =
        navigation.tryHorizontalDetour()

    if sideOK then
        return true
    end

    if not isPhysicalBlock(
        sideReason
    )
    then

        return false,
            sideReason

    end

    local downOK,
        downReason =
        movement.down()

    if downOK then

        local gpsOK,
            gpsError =
            gpslib.sync()

        if not gpsOK then

            return false,
                gpsError

        end

        return true

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
        callbacks or {}

    -- ========================================================
    -- POSICIÓN
    -- ========================================================

    local positionOK,
        positionError =
        gpslib.ensurePosition()

    if not positionOK then

        return false,
            positionError

    end

    -- ========================================================
    -- ORIENTACIÓN
    -- ========================================================

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        return false,
            orientationError

    end

    local steps = 0

    local visited = {}

    while true do

        -- ====================================================
        -- CONTROL
        -- ====================================================

        if callbacks.onControl then

            local continueNavigation =
                callbacks.onControl()

            if continueNavigation == false then

                return false,
                    "INTERRUPTED"

            end

        end

        -- ====================================================
        -- GPS PERIÓDICO
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

        if navigation.atPosition(
            targetX,
            targetY,
            targetZ
        )
        then

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

            -- Si GPS funciona pero simplemente había
            -- una discrepancia, seguimos navegando.

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
        -- LÍMITE
        -- ====================================================

        steps =
            steps + 1

        if
            steps
            >
            config.MAX_NAV_STEPS
        then

            return false,
                "MAX_NAV_STEPS"

        end

        -- ====================================================
        -- VISITAS
        -- ====================================================

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

        local moved = false
        local reason = nil

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
        -- ERROR NO FÍSICO
        -- ====================================================

        if
            not moved
            and
            reason
            and
            not isPhysicalBlock(reason)
        then

            return false,
                reason

        end

        -- ====================================================
        -- DESVÍO
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
            not isPhysicalBlock(reason)
        then

            return false,
                reason

        end

        -- ====================================================
        -- POSICIÓN REPETIDA
        -- ====================================================

        if
            visits
            >=
            config.MAX_POSITION_VISITS
            and
            not moved
        then

            moved,
            reason =
                navigation.escapeStep()

        end

        if
            not moved
            and
            reason
            and
            not isPhysicalBlock(reason)
        then

            return false,
                reason

        end

        -- ====================================================
        -- RUTA BLOQUEADA
        -- ====================================================

        if not moved then

            print("")
            print("==============================")
            print("        RUTA BLOQUEADA")
            print("==============================")

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

            sleep(1)

        end

    end

end

-- ============================================================
-- IR A POSITION
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
-- DISTANCIA
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

return navigation