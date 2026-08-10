-- ============================================================
-- PAISACRAFT
-- GESTIÓN INTELIGENTE DE COMBUSTIBLE v6.1.2
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
-- DISTANCIA
-- ============================================================

function fuel.distance(a, b)

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
-- ÍNDICE -> POSICIÓN
-- ============================================================

function fuel.indexPosition(index)

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
            index / width
        )

    local column =
        index % width

    local x

    if row % 2 == 0 then

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

        x = x,

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
-- POSICIONES QUE QUEDAN EN EL TRABAJO
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
-- HORIZONTE DE UNA SALIDA
--
-- Aunque la tanda de materiales use hasta 960 bloques,
-- para la estimación de movimiento consideramos como máximo
-- 960 posiciones antes de volver a comprobar la autonomía.
-- ============================================================

function fuel.getWorkHorizon()

    return math.min(

        config.BATCH_BLOCK_LIMIT,

        fuel.remainingJobPositions()

    )

end

-- ============================================================
-- ESTACIÓN A LA QUE DEBEMOS PODER REGRESAR
-- ============================================================

function fuel.getReturnStation()

    local assignment =
        state.assignment

    if not assignment then
        return state.home
    end

    -- Si generamos drops, descarga es el primer
    -- punto lógico de servicio.

    if
        assignment.unloadStation
    then

        return
            assignment.unloadStation

    end

    if assignment.fuelStation then

        return
            assignment.fuelStation

    end

    if assignment.materialStation then

        return
            assignment.materialStation

    end

    return state.home

end

-- ============================================================
-- RESERVA MÍNIMA DESDE UNA POSICIÓN
--
-- Esta es la protección anti-turtle-varada.
-- ============================================================

function fuel.safeReturnRequirement(
    position
)

    if not position then
        return config.MIN_FUEL
    end

    local station =
        fuel.getReturnStation()

    if not station then
        return config.MIN_FUEL
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
        math.ceil(required)
    )

end

-- ============================================================
-- ¿DEBEMOS VOLVER A REPOSTAR?
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
-- ESTIMAR OBJETIVO DE UNA NUEVA SALIDA
--
-- Se usa DESPUÉS de volver a servicio.
--
-- startPosition:
-- normalmente fuelStation.
--
-- workPosition:
-- punto donde reanudará.
--
-- includeMaterialTrip:
-- fuel -> materiales -> trabajo.
-- ============================================================

function fuel.estimateRequired(
    startPosition,
    workPosition,
    includeMaterialTrip
)

    if not state.assignment then
        return config.TARGET_FUEL
    end

    local required = 0

    local current =
        startPosition

    -- ========================================================
    -- FUEL -> MATERIALES
    -- ========================================================

    if
        includeMaterialTrip
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

    -- ========================================================
    -- ESTACIÓN -> TRABAJO
    -- ========================================================

    if workPosition then

        required =
            required
            +
            fuel.distance(
                current,
                workPosition
            )

    end

    -- ========================================================
    -- HORIZONTE DE TRABAJO
    --
    -- N movimientos para recorrer la tanda.
    -- ========================================================

    local horizon =
        fuel.getWorkHorizon()

    required =
        required
        +
        horizon

    -- ========================================================
    -- GARANTÍA DE REGRESO
    --
    -- Tras N movimientos, la turtle podría encontrarse
    -- hasta N bloques más lejos de la estación.
    --
    -- Por eso:
    --
    -- distancia inicial trabajo -> servicio
    -- +
    -- N movimientos adicionales
    --
    -- Es una cota conservadora.
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
    -- MARGEN
    -- ========================================================

    required =
        required
        +
        config.FUEL_SAFETY_MARGIN

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
-- OBJETIVO PARA RESTOCK
--
-- IMPORTANTE:
-- Siempre calcula como una NUEVA tanda.
-- No resta blocksThisBatch de la tanda anterior.
-- ============================================================

function fuel.calculateTarget(
    returnPosition
)

    local assignment =
        state.assignment

    if not assignment then
        return config.TARGET_FUEL
    end

    local startPosition =
        assignment.fuelStation

    if not startPosition then

        startPosition =
            state.getPosition()

    end

    local workPosition =
        returnPosition

    if not workPosition then

        workPosition =
            fuel.indexPosition(
                state.currentIndex
            )

    end

    local includeMaterialTrip =
        assignment.materialStation
        ~= nil
        and
        assignment.buildMode
        ~=
        config.BUILD_MODES.CLEAR

    return fuel.estimateRequired(

        startPosition,
        workPosition,
        includeMaterialTrip

    )

end

return fuel