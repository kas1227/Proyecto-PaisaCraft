-- ============================================================
-- PAISACRAFT
-- GESTION INTELIGENTE DE COMBUSTIBLE v6.1.5
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local utils =
    require("lib.utils")

local fuel = {}

-- ============================================================
-- NIVEL ACTUAL
-- ============================================================

function fuel.getLevel()

    local level =
        turtle.getFuelLevel()

    if level == "unlimited" then

        return math.huge

    end

    return level

end

-- ============================================================
-- ¿COMBUSTIBLE ILIMITADO?
-- ============================================================

function fuel.isUnlimited()

    return
        fuel.getLevel()
        ==
        math.huge

end

-- ============================================================
-- DISTANCIA MANHATTAN
-- ============================================================

function fuel.distance(
    a,
    b
)

    if
        not a
        or
        not b
    then

        return 0

    end

    return utils.manhattanDistance(

        a.x,
        a.y,
        a.z,

        b.x,
        b.y,
        b.z

    )

end

-- ============================================================
-- INDICE -> POSICION
--
-- Debe utilizar exactamente el mismo recorrido serpiente
-- que jobs.lua.
-- ============================================================

function fuel.indexPosition(
    index
)

    local assignment =
        state.assignment

    if
        not assignment
        or
        index == nil
    then

        return nil

    end

    local width =
        assignment.width

    if
        not width
        or
        width <= 0
    then

        return nil

    end

    local row =
        math.floor(
            index
            /
            width
        )

    local column =
        index
        %
        width

    local x

    if
        row % 2
        ==
        0
    then

        x =
            assignment.minX
            +
            column

    else

        x =
            assignment.maxX
            -
            column

    end

    return {

        x =
            x,

        y =
            assignment.floorY
            +
            1,

        z =
            assignment.minZ
            +
            row

    }

end

-- ============================================================
-- POSICIONES RESTANTES DEL TRABAJO
-- ============================================================

function fuel.remainingJobPositions()

    if
        not state.assignment
        or
        state.currentIndex == nil
        or
        state.assignment.endIndex == nil
    then

        return 0

    end

    local remaining =
        state.assignment.endIndex
        -
        state.currentIndex
        +
        1

    return math.max(
        0,
        remaining
    )

end

-- ============================================================
-- HORIZONTE DE TRABAJO
--
-- Una salida nunca necesita calcular mas trabajo
-- que una tanda completa.
--
-- Actualmente:
--
-- 15 slots x 64 = 960
--
-- Si quedan menos bloques que eso, usamos los restantes.
-- ============================================================

function fuel.getWorkHorizon()

    return math.min(

        config.BATCH_BLOCK_LIMIT,

        fuel.remainingJobPositions()

    )

end

-- ============================================================
-- MODO ACTUAL
-- ============================================================

function fuel.getBuildMode()

    if
        state.assignment
        and
        state.assignment.buildMode
    then

        return
            state.assignment.buildMode

    end

    return
        config.DEFAULT_BUILD_MODE

end

-- ============================================================
-- ESTACION DE REGRESO
--
-- Esta es la estacion que la turtle debe poder alcanzar
-- desde cualquier punto del trabajo.
--
-- PLACE:
--     fuelStation
--
-- REPLACE:
--     unloadStation
--
-- CLEAR:
--     unloadStation
--
-- Si alguna estacion no existe utilizamos los siguientes
-- fallbacks disponibles.
-- ============================================================

function fuel.getReturnStation()

    local assignment =
        state.assignment

    if not assignment then

        return state.home

    end

    local mode =
        fuel.getBuildMode()

    -- ========================================================
    -- REPLACE / CLEAR
    --
    -- La descarga es el primer paso del ciclo.
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.REPLACE

        or

        mode ==
        config.BUILD_MODES.CLEAR
    then

        if assignment.unloadStation then

            return
                assignment.unloadStation

        end

    end

    -- ========================================================
    -- PLACE
    --
    -- O fallback para cualquier modo.
    -- ========================================================

    if assignment.fuelStation then

        return
            assignment.fuelStation

    end

    if assignment.materialStation then

        return
            assignment.materialStation

    end

    if assignment.unloadStation then

        return
            assignment.unloadStation

    end

    return state.home

end

-- ============================================================
-- RESERVA MINIMA PARA PODER VOLVER
--
-- Evita que la turtle continue trabajando cuando
-- ya no podria alcanzar la estacion de servicio.
-- ============================================================

function fuel.safeReturnRequirement(
    position
)

    if fuel.isUnlimited() then

        return 0

    end

    if not position then

        return
            config.MIN_FUEL

    end

    local station =
        fuel.getReturnStation()

    if not station then

        return
            config.MIN_FUEL

    end

    local required =
        fuel.distance(
            position,
            station
        )
        +
        config.FUEL_SAFETY_MARGIN

    return math.max(

        config.MIN_FUEL,

        math.ceil(
            required
        )

    )

end

-- ============================================================
-- ¿DEBEMOS VOLVER A SERVICIO?
-- ============================================================

function fuel.needsService(
    position
)

    local level =
        fuel.getLevel()

    if level == math.huge then

        return false

    end

    local required =
        fuel.safeReturnRequirement(
            position
        )

    return
        level <= required

end

-- ============================================================
-- DISTANCIA DEL CICLO POST-FUEL
--
-- Calcula:
--
-- PLACE / REPLACE:
--
-- fuel
--   -> materiales
--   -> trabajo
--
-- CLEAR:
--
-- fuel
--   -> trabajo
-- ============================================================

function fuel.serviceToWorkDistance(
    fuelPosition,
    workPosition,
    includeMaterialTrip
)

    local required = 0

    local current =
        fuelPosition

    if
        includeMaterialTrip
        and
        state.assignment
        and
        state.assignment.materialStation
    then

        required =
            required
            +
            fuel.distance(

                current,

                state.assignment.materialStation

            )

        current =
            state.assignment.materialStation

    end

    if
        current
        and
        workPosition
    then

        required =
            required
            +
            fuel.distance(
                current,
                workPosition
            )

    end

    return required

end

-- ============================================================
-- ESTIMAR COMBUSTIBLE DE UNA NUEVA SALIDA
--
-- La turtle acaba de repostar.
--
-- Calculamos combustible suficiente para:
--
-- 1. salir de fuelStation
-- 2. pasar por materiales si corresponde
-- 3. regresar al trabajo
-- 4. procesar como maximo una tanda
-- 5. conservar capacidad de volver a la primera estacion
--    del siguiente servicio
-- 6. margen de seguridad
-- ============================================================

function fuel.estimateRequired(
    startPosition,
    workPosition,
    includeMaterialTrip
)

    if fuel.isUnlimited() then

        return 0

    end

    if not state.assignment then

        return
            config.TARGET_FUEL

    end

    local required = 0

    -- ========================================================
    -- SALIR DEL SERVICIO Y REGRESAR AL TRABAJO
    -- ========================================================

    required =
        required
        +
        fuel.serviceToWorkDistance(

            startPosition,

            workPosition,

            includeMaterialTrip

        )

    -- ========================================================
    -- HORIZONTE
    --
    -- Estimacion conservadora:
    -- un movimiento por posicion del trabajo.
    -- ========================================================

    local horizon =
        fuel.getWorkHorizon()

    required =
        required
        +
        horizon

    -- ========================================================
    -- GARANTIA DE REGRESO
    --
    -- El punto de trabajo puede estar lejos de la estacion
    -- y ademas la turtle puede avanzar durante la tanda.
    --
    -- Sumamos:
    --
    -- trabajo -> primera estacion de servicio
    -- +
    -- horizonte adicional
    --
    -- Esto es deliberadamente conservador.
    -- ========================================================

    local returnStation =
        fuel.getReturnStation()

    if
        workPosition
        and
        returnStation
    then

        required =
            required
            +
            fuel.distance(
                workPosition,
                returnStation
            )
            +
            horizon

    end

    -- ========================================================
    -- MARGEN DE SEGURIDAD
    -- ========================================================

    required =
        required
        +
        config.FUEL_SAFETY_MARGIN

    -- ========================================================
    -- MINIMO GLOBAL
    -- ========================================================

    required =
        math.max(
            required,
            config.MIN_FUEL
        )

    return math.ceil(
        required
    )

end

-- ============================================================
-- OBJETIVO DE COMBUSTIBLE PARA RESTOCK
--
-- stations.fullRestock():
--
-- REPLACE:
-- descarga -> fuel -> materiales -> trabajo
--
-- CLEAR:
-- descarga -> fuel -> trabajo
--
-- PLACE:
-- fuel -> materiales -> trabajo
--
-- calculateTarget() se llama cuando la turtle va a repostar.
-- Por eso el inicio del calculo es fuelStation.
-- ============================================================

function fuel.calculateTarget(
    returnPosition
)

    if fuel.isUnlimited() then

        return 0

    end

    local assignment =
        state.assignment

    if not assignment then

        return
            config.TARGET_FUEL

    end

    -- ========================================================
    -- PUNTO DESDE EL QUE SALDRA TRAS REPOSTAR
    -- ========================================================

    local startPosition =
        assignment.fuelStation

    if not startPosition then

        startPosition =
            state.getPosition()

    end

    -- ========================================================
    -- PUNTO DE TRABAJO
    --
    -- Si fullRestock(true) guardo la posicion,
    -- utilizamos esa.
    --
    -- En restock inicial calculamos la posicion
    -- correspondiente al currentIndex.
    -- ========================================================

    local workPosition =
        returnPosition

    if not workPosition then

        workPosition =
            fuel.indexPosition(
                state.currentIndex
            )

    end

    -- ========================================================
    -- ¿HAY VIAJE A MATERIALES?
    --
    -- PLACE    -> si
    -- REPLACE  -> si
    -- CLEAR    -> no
    -- ========================================================

    local includeMaterialTrip =
        assignment.materialStation
        ~= nil
        and
        fuel.getBuildMode()
        ~=
        config.BUILD_MODES.CLEAR

    local calculated =
        fuel.estimateRequired(

            startPosition,

            workPosition,

            includeMaterialTrip

        )

    -- ========================================================
    -- TARGET_FUEL COMO PISO RECOMENDADO
    --
    -- Si la estimacion pide mas, usamos la estimacion.
    --
    -- Si pide menos, mantenemos TARGET_FUEL para evitar
    -- viajes excesivamente frecuentes a combustible.
    -- ========================================================

    return math.max(

        calculated,

        config.TARGET_FUEL

    )

end

-- ============================================================
-- INFORMACION DE AUTONOMIA
--
-- Util para worker / monitor.
-- ============================================================

function fuel.getStats()

    local level =
        fuel.getLevel()

    local position =
        state.getPosition()

    local safeReturn =
        fuel.safeReturnRequirement(
            position
        )

    local target =
        0

    if state.assignment then

        target =
            fuel.calculateTarget(
                position
            )

    end

    local available = math.huge

    if level ~= math.huge then

        available =
            math.max(
                0,
                level
                -
                safeReturn
            )

    end

    return {

        level =
            level,

        target =
            target,

        safeReturn =
            safeReturn,

        available =
            available,

        needsService =
            fuel.needsService(
                position
            ),

        returnStation =
            fuel.getReturnStation(),

        horizon =
            fuel.getWorkHorizon()

    }

end

return fuel
