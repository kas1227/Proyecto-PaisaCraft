-- ============================================================
-- PAISACRAFT
-- ESTADO DEL WORKER v6.1.2
-- ============================================================

local config =
    require("lib.config")

local utils =
    require("lib.utils")

local state = {}

-- ============================================================
-- DATOS PERSISTENTES
-- ============================================================

state.assignment = nil
state.currentIndex = nil
state.completed = 0

state.home = nil

state.paused = false
state.returnRequested = false

state.initialRestockDone = false

-- Cantidad de bloques que realmente han sido
-- colocados/reemplazados/eliminados desde el último servicio.
state.blocksThisBatch = 0

-- ============================================================
-- DATOS TEMPORALES
-- ============================================================

state.direction = nil

state.position = {
    x = nil,
    y = nil,
    z = nil
}

state.buildingSlot = nil

state.movementsSinceGPS = 0
state.blocksSinceSave = 0

-- ============================================================
-- POSICIÓN
-- ============================================================

function state.hasPosition()

    return
        state.position.x ~= nil
        and
        state.position.y ~= nil
        and
        state.position.z ~= nil

end


function state.setPosition(x, y, z)

    state.position.x = x
    state.position.y = y
    state.position.z = z

end


function state.getPosition()

    if not state.hasPosition() then
        return nil
    end

    return {
        x = state.position.x,
        y = state.position.y,
        z = state.position.z
    }

end


function state.clearPosition()

    state.position.x = nil
    state.position.y = nil
    state.position.z = nil

end

-- ============================================================
-- DIRECCIÓN
-- ============================================================

function state.setDirection(direction)

    if
        direction ~= nil
        and
        not utils.isValidDirection(direction)
    then

        error(
            "Dirección inválida: "
            ..
            tostring(direction)
        )

    end

    state.direction = direction

end


function state.getDirection()

    return state.direction

end

-- ============================================================
-- HOME
-- ============================================================

function state.setHome(
    x,
    y,
    z,
    direction
)

    state.home = {

        x = x,
        y = y,
        z = z,

        direction = direction

    }

end


function state.hasHome()

    return
        state.home ~= nil
        and
        utils.isValidPosition(
            state.home
        )

end

-- ============================================================
-- ASIGNACIÓN
-- ============================================================

function state.setAssignment(
    assignment
)

    state.assignment =
        assignment

    if assignment then

        state.currentIndex =
            assignment.startIndex

    else

        state.currentIndex = nil

    end

    state.completed = 0

    state.initialRestockDone = false

    state.blocksThisBatch = 0

    state.paused = false
    state.returnRequested = false

end


function state.hasAssignment()

    return
        state.assignment ~= nil

end


function state.hasActiveJob()

    if not state.assignment then
        return false
    end

    if state.currentIndex == nil then
        return false
    end

    if
        state.assignment.endIndex
        == nil
    then
        return false
    end

    return
        state.currentIndex
        <=
        state.assignment.endIndex

end

-- ============================================================
-- TRABAJO TERMINADO PERO REGRESO PENDIENTE
--
-- Esto nos servirá posteriormente en worker.lua:
-- si reinicia después de terminar pero antes de aparcar,
-- sabremos que debe volver HOME.
-- ============================================================

function state.hasPendingReturn()

    return
        state.assignment ~= nil
        and
        state.returnRequested == true
        and
        state.hasHome()

end

-- ============================================================
-- TANDA
-- ============================================================

function state.resetBatchCounter()

    state.blocksThisBatch = 0

end


function state.batchLimitReached()

    return
        state.blocksThisBatch
        >=
        config.BATCH_BLOCK_LIMIT

end

-- ============================================================
-- PAUSA
-- ============================================================

function state.pause()

    state.paused = true

end


function state.resume()

    state.paused = false

end


function state.requestReturn()

    state.returnRequested = true

end


function state.cancelReturn()

    state.returnRequested = false

end

-- ============================================================
-- SLOT DE CONSTRUCCIÓN
-- ============================================================

function state.setBuildingSlot(slot)

    state.buildingSlot = slot

end


function state.clearBuildingSlot()

    state.buildingSlot = nil

end

-- ============================================================
-- GPS
-- ============================================================

function state.movementPerformed()

    state.movementsSinceGPS =
        state.movementsSinceGPS + 1

end


function state.resetGPSCounter()

    state.movementsSinceGPS = 0

end


function state.needsGPSSync()

    return
        state.movementsSinceGPS
        >=
        config.GPS_SYNC_INTERVAL

end

-- ============================================================
-- SERIALIZAR
-- ============================================================

function state.toTable()

    return {

        assignment =
            state.assignment,

        currentIndex =
            state.currentIndex,

        completed =
            state.completed,

        home =
            state.home,

        paused =
            state.paused,

        returnRequested =
            state.returnRequested,

        initialRestockDone =
            state.initialRestockDone,

        blocksThisBatch =
            state.blocksThisBatch

    }

end

-- ============================================================
-- RESTAURAR
-- ============================================================

function state.fromTable(data)

    if type(data) ~= "table" then
        return false
    end

    state.assignment =
        data.assignment

    state.currentIndex =
        data.currentIndex

    state.completed =
        data.completed
        or
        0

    state.home =
        data.home

    state.paused =
        data.paused
        or
        false

    state.returnRequested =
        data.returnRequested
        or
        false

    state.initialRestockDone =
        data.initialRestockDone
        or
        false

    state.blocksThisBatch =
        data.blocksThisBatch
        or
        0

    state.blocksSinceSave = 0

    return true

end

-- ============================================================
-- GUARDAR
-- ============================================================

function state.save()

    local ok, err =
        utils.saveTable(

            config.WORKER_STATE_FILE,

            state.toTable()

        )

    if not ok then

        print(
            "ERROR guardando estado:",
            tostring(err)
        )

        return false

    end

    state.blocksSinceSave = 0

    return true

end

-- ============================================================
-- GUARDADO PERIÓDICO
-- ============================================================

function state.saveIfNeeded()

    if
        state.blocksSinceSave
        >=
        config.SAVE_INTERVAL
    then

        return state.save()

    end

    return true

end

-- ============================================================
-- CARGAR
-- ============================================================

function state.load()

    local data =
        utils.loadTable(
            config.WORKER_STATE_FILE
        )

    if not data then
        return false
    end

    return state.fromTable(
        data
    )

end

-- ============================================================
-- LIMPIAR TRABAJO
-- ============================================================

function state.clearJob()

    state.assignment = nil
    state.currentIndex = nil

    state.completed = 0

    state.home = nil

    state.paused = false
    state.returnRequested = false

    state.initialRestockDone = false

    state.direction = nil

    state.clearPosition()

    state.buildingSlot = nil

    state.movementsSinceGPS = 0
    state.blocksSinceSave = 0
    state.blocksThisBatch = 0

    return state.save()

end

-- ============================================================
-- REINICIAR ESTADO TEMPORAL
-- ============================================================

function state.resetRuntime()

    state.direction = nil

    state.clearPosition()

    state.buildingSlot = nil

    state.movementsSinceGPS = 0
    state.blocksSinceSave = 0

end

return state