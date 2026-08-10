-- ============================================================
-- PAISACRAFT
-- ESTADO DEL WORKER v6.1.5
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

-- Cantidad de bloques realmente procesados
-- desde el ultimo ciclo de servicio.
state.blocksThisBatch = 0

-- ============================================================
-- DATOS TEMPORALES
--
-- No se guardan en disco porque se reconstruyen
-- mediante GPS/orientacion al arrancar.
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
-- POSICION
-- ============================================================

function state.hasPosition()

    return
        state.position.x ~= nil
        and
        state.position.y ~= nil
        and
        state.position.z ~= nil

end


function state.setPosition(
    x,
    y,
    z
)

    state.position.x = x
    state.position.y = y
    state.position.z = z

end


function state.getPosition()

    if not state.hasPosition() then

        return nil

    end

    return {

        x =
            state.position.x,

        y =
            state.position.y,

        z =
            state.position.z

    }

end


function state.clearPosition()

    state.position.x = nil
    state.position.y = nil
    state.position.z = nil

end

-- ============================================================
-- DIRECCION
-- ============================================================

function state.setDirection(
    direction
)

    if
        direction ~= nil
        and
        not utils.isValidDirection(
            direction
        )
    then

        error(
            "Direccion invalida: "
            ..
            tostring(direction)
        )

    end

    state.direction =
        direction

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

        direction =
            direction

    }

end


function state.getHome()

    return state.home

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
-- ASIGNACION
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

        state.currentIndex =
            nil

    end

    state.completed = 0

    state.initialRestockDone =
        false

    state.blocksThisBatch =
        0

    state.paused =
        false

    state.returnRequested =
        false

    state.buildingSlot =
        nil

    state.blocksSinceSave =
        0

end


function state.getAssignment()

    return state.assignment

end


function state.hasAssignment()

    return
        state.assignment
        ~=
        nil

end

-- ============================================================
-- TRABAJO ACTIVO
-- ============================================================

function state.hasActiveJob()

    if not state.assignment then

        return false

    end

    if state.currentIndex == nil then

        return false

    end

    if
        state.assignment.endIndex
        ==
        nil
    then

        return false

    end

    return
        state.currentIndex
        <=
        state.assignment.endIndex

end

-- ============================================================
-- TRABAJO TERMINADO
-- ============================================================

function state.isJobFinished()

    if not state.assignment then

        return false

    end

    if state.currentIndex == nil then

        return false

    end

    if
        state.assignment.endIndex
        ==
        nil
    then

        return false

    end

    return
        state.currentIndex
        >
        state.assignment.endIndex

end

-- ============================================================
-- RETORNO PENDIENTE
--
-- Permite recuperar el caso:
--
-- termina trabajo
-- -> solicita HOME
-- -> servidor/turtle reinicia
-- -> worker vuelve a arrancar
-- -> sigue sabiendo que debe regresar HOME
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
-- PROGRESO
-- ============================================================

function state.incrementCompleted()

    state.completed =
        state.completed
        +
        1

end


function state.advanceIndex()

    if state.currentIndex == nil then

        return false

    end

    state.currentIndex =
        state.currentIndex
        +
        1

    return true

end

-- ============================================================
-- TANDA
-- ============================================================

function state.resetBatchCounter()

    state.blocksThisBatch =
        0

end


function state.incrementBatchCounter()

    state.blocksThisBatch =
        state.blocksThisBatch
        +
        1

end


function state.getBatchCount()

    return
        state.blocksThisBatch
        or
        0

end


function state.getBatchRemaining()

    return math.max(

        0,

        config.BATCH_BLOCK_LIMIT
        -
        state.getBatchCount()

    )

end


function state.batchLimitReached()

    return
        state.getBatchCount()
        >=
        config.BATCH_BLOCK_LIMIT

end

-- ============================================================
-- PAUSA
-- ============================================================

function state.pause()

    state.paused =
        true

end


function state.resume()

    state.paused =
        false

end


function state.isPaused()

    return
        state.paused
        ==
        true

end

-- ============================================================
-- RETORNO
-- ============================================================

function state.requestReturn()

    state.returnRequested =
        true

end


function state.cancelReturn()

    state.returnRequested =
        false

end


function state.isReturnRequested()

    return
        state.returnRequested
        ==
        true

end

-- ============================================================
-- SLOT DE CONSTRUCCION
-- ============================================================

function state.setBuildingSlot(
    slot
)

    if
        slot ~= nil
        and
        (
            slot
            <
            config.BUILD_SLOT_FIRST

            or

            slot
            >
            config.BUILD_SLOT_LAST
        )
    then

        return false

    end

    state.buildingSlot =
        slot

    return true

end


function state.getBuildingSlot()

    return
        state.buildingSlot

end


function state.clearBuildingSlot()

    state.buildingSlot =
        nil

end

-- ============================================================
-- GPS
-- ============================================================

function state.movementPerformed()

    state.movementsSinceGPS =
        state.movementsSinceGPS
        +
        1

end


function state.resetGPSCounter()

    state.movementsSinceGPS =
        0

end


function state.needsGPSSync()

    return
        state.movementsSinceGPS
        >=
        config.GPS_SYNC_INTERVAL

end

-- ============================================================
-- GUARDADO PERIODICO
-- ============================================================

function state.blockProcessed()

    state.blocksSinceSave =
        state.blocksSinceSave
        +
        1

end

-- ============================================================
-- VALIDAR ASIGNACION
-- ============================================================

local function validAssignment(
    assignment
)

    if assignment == nil then

        return true

    end

    if
        type(assignment)
        ~=
        "table"
    then

        return false

    end

    if
        type(assignment.startIndex)
        ~=
        "number"
    then

        return false

    end

    if
        type(assignment.endIndex)
        ~=
        "number"
    then

        return false

    end

    if
        assignment.endIndex
        <
        assignment.startIndex
    then

        return false

    end

    return true

end

-- ============================================================
-- NORMALIZAR DATOS CARGADOS
-- ============================================================

local function normalizeLoadedState()

    if
        state.completed
        <
        0
    then

        state.completed =
            0

    end

    if
        state.blocksThisBatch
        <
        0
    then

        state.blocksThisBatch =
            0

    end

    if
        state.blocksThisBatch
        >
        config.BATCH_BLOCK_LIMIT
    then

        -- Si la turtle se apago justo despues
        -- de completar una tanda, conservamos
        -- como maximo el limite.
        state.blocksThisBatch =
            config.BATCH_BLOCK_LIMIT

    end

    if state.assignment then

        if
            state.currentIndex
            ==
            nil
        then

            state.currentIndex =
                state.assignment.startIndex

        end

        if
            state.currentIndex
            <
            state.assignment.startIndex
        then

            state.currentIndex =
                state.assignment.startIndex

        end

    end

end

-- ============================================================
-- SERIALIZAR
--
-- Solo guardamos datos que deben sobrevivir
-- a un reboot.
-- ============================================================

function state.toTable()

    return {

        version =
            config.VERSION,

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

function state.fromTable(
    data
)

    if
        type(data)
        ~=
        "table"
    then

        return false,
            "STATE_INVALIDO"

    end

    if
        not validAssignment(
            data.assignment
        )
    then

        return false,
            "ASIGNACION_GUARDADA_INVALIDA"

    end

    state.assignment =
        data.assignment

    state.currentIndex =
        data.currentIndex

    state.completed =
        tonumber(
            data.completed
        )
        or
        0

    state.home =
        data.home

    state.paused =
        data.paused
        ==
        true

    state.returnRequested =
        data.returnRequested
        ==
        true

    state.initialRestockDone =
        data.initialRestockDone
        ==
        true

    state.blocksThisBatch =
        tonumber(
            data.blocksThisBatch
        )
        or
        0

    -- ========================================================
    -- DATOS TEMPORALES
    --
    -- Siempre se reconstruyen tras reboot.
    -- ========================================================

    state.direction =
        nil

    state.clearPosition()

    state.buildingSlot =
        nil

    state.movementsSinceGPS =
        0

    state.blocksSinceSave =
        0

    normalizeLoadedState()

    return true

end

-- ============================================================
-- GUARDAR
-- ============================================================

function state.save()

    local ok,
        err =
        utils.saveTable(

            config.WORKER_STATE_FILE,

            state.toTable()

        )

    if not ok then

        print(
            "ERROR guardando estado:",
            tostring(err)
        )

        return false,
            err

    end

    state.blocksSinceSave =
        0

    return true

end

-- ============================================================
-- GUARDAR SI CORRESPONDE
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

        return false,
            "SIN_ESTADO_GUARDADO"

    end

    local ok,
        err =
        state.fromTable(
            data
        )

    if not ok then

        print("")
        print(
            "Estado guardado invalido:"
        )

        print(
            tostring(err)
        )

        return false,
            err

    end

    return true

end

-- ============================================================
-- LIMPIAR TRABAJO
--
-- Elimina completamente la asignacion actual.
-- ============================================================

function state.clearJob()

    state.assignment =
        nil

    state.currentIndex =
        nil

    state.completed =
        0

    state.home =
        nil

    state.paused =
        false

    state.returnRequested =
        false

    state.initialRestockDone =
        false

    state.direction =
        nil

    state.clearPosition()

    state.buildingSlot =
        nil

    state.movementsSinceGPS =
        0

    state.blocksSinceSave =
        0

    state.blocksThisBatch =
        0

    return state.save()

end

-- ============================================================
-- REINICIAR ESTADO TEMPORAL
--
-- Se utiliza al arrancar despues de un reboot.
--
-- NO toca:
--
-- assignment
-- currentIndex
-- completed
-- home
-- blocksThisBatch
-- initialRestockDone
-- returnRequested
-- ============================================================

function state.resetRuntime()

    state.direction =
        nil

    state.clearPosition()

    state.buildingSlot =
        nil

    state.movementsSinceGPS =
        0

    state.blocksSinceSave =
        0

end

-- ============================================================
-- ESTADISTICAS
-- ============================================================

function state.getStats()

    local remaining = 0

    if
        state.assignment
        and
        state.currentIndex
        and
        state.assignment.endIndex
    then

        remaining =
            math.max(

                0,

                state.assignment.endIndex
                -
                state.currentIndex
                +
                1

            )

    end

    return {

        hasAssignment =
            state.hasAssignment(),

        activeJob =
            state.hasActiveJob(),

        finishedJob =
            state.isJobFinished(),

        currentIndex =
            state.currentIndex,

        completed =
            state.completed,

        remaining =
            remaining,

        blocksThisBatch =
            state.blocksThisBatch,

        batchRemaining =
            state.getBatchRemaining(),

        paused =
            state.paused,

        returnRequested =
            state.returnRequested,

        initialRestockDone =
            state.initialRestockDone,

        home =
            state.home,

        position =
            state.getPosition(),

        direction =
            state.direction

    }

end

return state
