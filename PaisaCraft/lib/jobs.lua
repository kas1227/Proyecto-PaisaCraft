-- ============================================================
-- PAISACRAFT
-- GESTION DE TRABAJOS v6.1.5
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local protocol =
    require("lib.protocol")

local navigation =
    require("lib.navigation")

local movement =
    require("lib.movement")

local gpslib =
    require("lib.gps")

local builder =
    require("lib.builder")

local stations =
    require("lib.stations")

local fuel =
    require("lib.fuel")

local jobs = {}

-- ============================================================
-- CALLBACK DE CONTROL
-- ============================================================

local controlCallback = nil


function jobs.setControlCallback(
    callback
)

    controlCallback =
        callback

    stations.setControlCallback(
        callback
    )

end


local function checkControl()

    if controlCallback then

        return controlCallback()

    end

    return true

end

-- ============================================================
-- MODO ACTUAL
-- ============================================================

local function getBuildMode()

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
-- INDICE -> COORDENADA
-- ============================================================

function jobs.indexToPosition(
    index
)

    local assignment =
        state.assignment

    if not assignment then

        return nil,
            nil,
            nil

    end

    local width =
        assignment.width

    if
        not width
        or
        width <= 0
    then

        return nil,
            nil,
            nil

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

    local z =
        assignment.minZ
        +
        row

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

    return
        x,
        z,
        row

end

-- ============================================================
-- RESTANTES
-- ============================================================

function jobs.getRemainingBlocks()

    if
        not state.assignment
        or
        state.currentIndex
        ==
        nil
        or
        state.assignment.endIndex
        ==
        nil
    then

        return 0

    end

    return math.max(

        0,

        state.assignment.endIndex
        -
        state.currentIndex
        +
        1

    )

end


function jobs.getRemainingBatch()

    return math.max(

        0,

        config.BATCH_BLOCK_LIMIT
        -
        (
            state.blocksThisBatch
            or
            0
        )

    )

end

-- ============================================================
-- FUEL OBJETIVO
-- ============================================================

function jobs.getFuelTarget()

    return fuel.calculateTarget(
        state.getPosition()
    )

end

-- ============================================================
-- CAPTURAR HOME
-- ============================================================

function jobs.captureHome()

    local ok,
        err =
        gpslib.sync()

    if not ok then

        return false,
            err

    end

    state.setHome(

        state.position.x,
        state.position.y,
        state.position.z,

        state.getDirection()

    )

    state.save()

    print("")
    print("==============================")
    print("         HOME GUARDADO")
    print("==============================")

    print(
        state.home.x,
        state.home.y,
        state.home.z
    )

    return true

end

-- ============================================================
-- REGRESAR HOME
-- ============================================================

function jobs.returnHome()

    if not state.hasHome() then

        return false,
            "HOME_NO_CONFIGURADO"

    end

    protocol.send({

        type =
            protocol.MESSAGE.CANCEL_RESERVATIONS

    })

    state.requestReturn()

    state.save()

    print("")
    print("==============================")
    print("       REGRESANDO HOME")
    print("==============================")

    print(
        "Destino:",
        state.home.x,
        state.home.y,
        state.home.z
    )

    local gpsOK,
        gpsError =
        gpslib.sync()

    if not gpsOK then

        return false,
            gpsError

    end

    local navigationOK,
        navigationError =
        navigation.goToPosition(

            state.home,

            {

                onControl =
                    function()

                        if controlCallback then

                            controlCallback()

                        end

                        -- RETURN_HOME ya esta activo.
                        -- No cancelamos esta navegacion.

                        return true

                    end

            }

        )

    if not navigationOK then

        return false,
            navigationError

    end

    if
        state.home.direction
        ~=
        nil
    then

        movement.turnTo(
            state.home.direction
        )

    end

    gpslib.sync()

    jobs.report(
        "PARKED"
    )

    protocol.send({

        type =
            protocol.MESSAGE.PARKED

    })

    print("")
    print("==============================")
    print("           PARKED")
    print("==============================")

    state.save()

    return true

end

-- ============================================================
-- RESULTADO CONSUME MATERIAL / TANDA
-- ============================================================

local function resultConsumesBatch(
    result
)

    return
        result == "PLACED"
        or
        result == "REPLACED"
        or
        result == "CLEARED"

end

-- ============================================================
-- AVANZAR PROGRESO
-- ============================================================

function jobs.advanceProgress(
    result
)

    state.completed =
        state.completed
        +
        1

    state.currentIndex =
        state.currentIndex
        +
        1

    state.blocksSinceSave =
        state.blocksSinceSave
        +
        1

    if resultConsumesBatch(
        result
    )
    then

        state.blocksThisBatch =
            state.blocksThisBatch
            +
            1

    end

    -- ========================================================
    -- REPLACE / CLEAR
    --
    -- Son operaciones destructivas.
    -- Guardamos inmediatamente.
    -- ========================================================

    local mode =
        getBuildMode()

    if
        mode ==
        config.BUILD_MODES.REPLACE

        or

        mode ==
        config.BUILD_MODES.CLEAR
    then

        return state.save()

    end

    return state.saveIfNeeded()

end

-- ============================================================
-- REPORTAR
-- ============================================================

function jobs.report(
    status
)

    local currentFuel =
        turtle.getFuelLevel()

    local fuelTarget =
        0

    if state.assignment then

        fuelTarget =
            jobs.getFuelTarget()

    end

    local safeReturn =
        0

    if state.hasPosition() then

        safeReturn =
            fuel.safeReturnRequirement(
                state.getPosition()
            )

    end

    protocol.send({

        type =
            protocol.MESSAGE.PROGRESS,

        status =
            status,

        completed =
            state.completed,

        currentIndex =
            state.currentIndex,

        remainingBlocks =
            jobs.getRemainingBlocks(),

        blocksThisBatch =
            state.blocksThisBatch,

        batchRemaining =
            jobs.getRemainingBatch(),

        batchLimit =
            config.BATCH_BLOCK_LIMIT,

        fuel =
            currentFuel,

        fuelTarget =
            fuelTarget,

        fuelSafeReturn =
            safeReturn,

        buildMode =
            getBuildMode(),

        position =
            state.getPosition()

    })

end

-- ============================================================
-- RESTOCK INICIAL
-- ============================================================

function jobs.initialRestock()

    if state.initialRestockDone then

        return true

    end

    print("")
    print("==============================")
    print("       RESTOCK INICIAL")
    print("==============================")

    jobs.report(
        "RESTOCK"
    )

    local ok,
        err =
        stations.fullRestock(
            false
        )

    if not ok then

        return false,
            err

    end

    state.initialRestockDone =
        true

    state.resetBatchCounter()

    state.save()

    return true

end

-- ============================================================
-- ASEGURAR RESERVA DE FUEL
--
-- Se ejecuta mientras todavia sabemos que
-- podemos regresar a servicio.
-- ============================================================

function jobs.ensureFuelReserve()

    if not state.hasPosition() then

        return true

    end

    if
        not fuel.needsService(
            state.getPosition()
        )
    then

        return true

    end

    print("")
    print("==============================")
    print("       FUEL DE RESERVA")
    print("==============================")

    print(
        "Fuel actual:",
        fuel.getLevel()
    )

    print(
        "Reserva necesaria:",
        fuel.safeReturnRequirement(
            state.getPosition()
        )
    )

    print(
        "Regresando a servicio..."
    )

    jobs.report(
        "LOW_FUEL"
    )

    local ok,
        err =
        stations.fullRestock(
            true
        )

    if not ok then

        return false,
            err

    end

    state.save()

    jobs.report(
        "BUILDING"
    )

    return true

end

-- ============================================================
-- ¿TANDA COMPLETA?
--
-- Slots 1-15:
-- 15 * 64 = 960 operaciones maximas por tanda.
-- ============================================================

function jobs.needsBatchService()

    return
        (
            state.blocksThisBatch
            or
            0
        )
        >=
        config.BATCH_BLOCK_LIMIT

end

-- ============================================================
-- SERVICIO DE TANDA
--
-- stations.fullRestock(true) realiza:
--
-- REPLACE:
--   descarga
--   combustible
--   materiales
--   regreso
--
-- CLEAR:
--   descarga
--   combustible
--   regreso
--
-- PLACE:
--   combustible
--   materiales
--   regreso
-- ============================================================

function jobs.batchService()

    if not jobs.needsBatchService() then

        return true

    end

    print("")
    print("==============================")
    print("       TANDA COMPLETA")
    print("==============================")

    print("")
    print(
        "Bloques procesados:",
        state.blocksThisBatch
    )

    print(
        "Limite:",
        config.BATCH_BLOCK_LIMIT
    )

    jobs.report(
        "RESTOCK"
    )

    local ok,
        err =
        stations.fullRestock(
            true
        )

    if not ok then

        return false,
            err

    end

    -- stations.fullRestock()
    -- reinicia blocksThisBatch cuando termina
    -- correctamente.

    state.save()

    jobs.report(
        "BUILDING"
    )

    return true

end

-- ============================================================
-- PREPARAR
-- ============================================================

function jobs.prepare()

    if not state.assignment then

        return false,
            "SIN_ASIGNACION"

    end

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        return false,
            orientationError

    end

    if not state.hasHome() then

        local homeOK,
            homeError =
            jobs.captureHome()

        if not homeOK then

            return false,
                homeError

        end

    end

    if
        state.currentIndex
        ==
        nil
    then

        state.currentIndex =
            state.assignment.startIndex

    end

    return true

end

-- ============================================================
-- NAVEGAR AL BLOQUE
-- ============================================================

function jobs.goToCurrentBlock()

    local x,
        z,
        row =
        jobs.indexToPosition(
            state.currentIndex
        )

    if not x then

        return false,
            "INDICE_INVALIDO"

    end

    local y =
        state.assignment.floorY
        +
        1

    print("")
    print(
        "Progreso:",
        state.completed,
        "/",
        state.assignment.count
    )

    print(
        "Restantes:",
        jobs.getRemainingBlocks()
    )

    print(
        "Tanda:",
        state.blocksThisBatch,
        "/",
        config.BATCH_BLOCK_LIMIT
    )

    print(
        "Objetivo:",
        x,
        y,
        z
    )

    jobs.report(
        "MOVING"
    )

    local ok,
        err =
        navigation.goTo(

            x,
            y,
            z,

            {

                onControl =
                    function()

                        return checkControl()

                    end

            }

        )

    if not ok then

        return false,
            err

    end

    -- ========================================================
    -- ORIENTACION SERPIENTE
    -- ========================================================

    if
        row % 2
        ==
        0
    then

        movement.turnTo(
            gpslib.EAST
        )

    else

        movement.turnTo(
            gpslib.WEST
        )

    end

    return true

end

-- ============================================================
-- PROCESAR BLOQUE
-- ============================================================

function jobs.processCurrentBlock()

    local ok,
        result =
        builder.processCurrentBlock()

    if not ok then

        return false,
            result

    end

    local saveOK =
        jobs.advanceProgress(
            result
        )

    if saveOK == false then

        return false,
            "ERROR_GUARDANDO_PROGRESO"

    end

    jobs.report(
        "BUILDING"
    )

    print(
        "Resultado:",
        result
    )

    return true,
        result

end

-- ============================================================
-- DESCARGA FINAL
--
-- Al acabar REPLACE o CLEAR pueden quedar
-- items retirados en el slot 16.
-- ============================================================

function jobs.finalUnload()

    local mode =
        getBuildMode()

    if
        mode
        ~=
        config.BUILD_MODES.REPLACE

        and

        mode
        ~=
        config.BUILD_MODES.CLEAR
    then

        return true

    end

    if
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        ==
        0
    then

        return true

    end

    print("")
    print("==============================")
    print("       DESCARGA FINAL")
    print("==============================")

    print("")
    print(
        "Items pendientes:",
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
    )

    jobs.report(
        "RESTOCK"
    )

    -- false:
    -- ya termino el trabajo,
    -- no necesitamos volver al ultimo bloque.

    local ok,
        err =
        stations.unloadOnly(
            false
        )

    if not ok then

        return false,
            err

    end

    -- ========================================================
    -- VERIFICACION
    -- ========================================================

    if
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        ~=
        0
    then

        return false,
            "DESCARGA_FINAL_INCOMPLETA"

    end

    print("")
    print(
        "Descarga final completa."
    )

    return true

end

-- ============================================================
-- COMPLETAR
-- ============================================================

function jobs.complete()

    state.save()

    -- ========================================================
    -- DESCARGAR MATERIAL RETIRADO
    -- ========================================================

    local unloadOK,
        unloadError =
        jobs.finalUnload()

    if not unloadOK then

        return false,
            unloadError

    end

    -- ========================================================
    -- MARCAR COMPLETADO
    -- ========================================================

    print("")
    print("==============================")
    print("     TRABAJO COMPLETADO")
    print("==============================")

    jobs.report(
        "COMPLETE"
    )

    protocol.send({

        type =
            protocol.MESSAGE.COMPLETE

    })

    -- ========================================================
    -- REGRESAR HOME
    -- ========================================================

    state.requestReturn()

    state.save()

    return jobs.returnHome()

end

-- ============================================================
-- GESTIONAR RETORNO SOLICITADO
-- ============================================================

local function handleReturnRequest()

    state.save()

    jobs.returnHome()

    return false,
        "RETURN_REQUESTED"

end

-- ============================================================
-- EJECUTAR
-- ============================================================

function jobs.run()

    -- ========================================================
    -- PREPARAR
    -- ========================================================

    local prepareOK,
        prepareError =
        jobs.prepare()

    if not prepareOK then

        return false,
            prepareError

    end

    -- ========================================================
    -- RESTOCK INICIAL
    -- ========================================================

    local restockOK,
        restockError =
        jobs.initialRestock()

    if not restockOK then

        if state.returnRequested then

            jobs.returnHome()

        end

        return false,
            restockError

    end

    jobs.report(
        "BUILDING"
    )

    -- ========================================================
    -- LOOP PRINCIPAL
    -- ========================================================

    while
        state.currentIndex
        <=
        state.assignment.endIndex
    do

        -- ====================================================
        -- CONTROL
        -- ====================================================

        if not checkControl() then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            return handleReturnRequest()

        end

        -- ====================================================
        -- SERVICIO DE TANDA
        --
        -- Se comprueba antes de ir al siguiente bloque.
        --
        -- Si acabamos de procesar el bloque numero 960,
        -- currentIndex ya apunta al siguiente.
        --
        -- fullRestock(true) guarda la posicion actual,
        -- realiza servicio y vuelve.
        -- ====================================================

        if jobs.needsBatchService() then

            local serviceOK,
                serviceError =
                jobs.batchService()

            if not serviceOK then

                if state.returnRequested then

                    return handleReturnRequest()

                end

                return false,
                    serviceError

            end

        end

        -- ====================================================
        -- RESERVA DE FUEL
        --
        -- Puede provocar servicio incluso antes
        -- de completar una tanda.
        -- ====================================================

        local fuelOK,
            fuelError =
            jobs.ensureFuelReserve()

        if not fuelOK then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                fuelError

        end

        -- ====================================================
        -- CONTROL DESPUES DEL SERVICIO
        -- ====================================================

        if not checkControl() then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            return handleReturnRequest()

        end

        -- ====================================================
        -- NAVEGAR
        -- ====================================================

        local navigateOK,
            navigateError =
            jobs.goToCurrentBlock()

        if not navigateOK then

            if
                navigateError
                ==
                "INTERRUPTED"

                and

                state.returnRequested
            then

                return handleReturnRequest()

            end

            return false,
                navigateError

        end

        -- ====================================================
        -- CONTROL ANTES DE MODIFICAR EL MUNDO
        -- ====================================================

        if not checkControl() then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            return handleReturnRequest()

        end

        -- ====================================================
        -- SEGUNDA COMPROBACION DE FUEL
        --
        -- El trayecto al objetivo puede haber consumido
        -- mas de lo esperado por obstaculos.
        -- ====================================================

        local reserveOK,
            reserveError =
            jobs.ensureFuelReserve()

        if not reserveOK then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                reserveError

        end

        -- ====================================================
        -- IMPORTANTE
        --
        -- ensureFuelReserve() puede haber hecho:
        --
        -- servicio
        -- -> regreso al punto guardado
        --
        -- Seguimos estando en el bloque que corresponde
        -- al currentIndex actual.
        -- ====================================================

        if not checkControl() then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                "INTERRUPTED"

        end

        -- ====================================================
        -- TRABAJAR
        -- ====================================================

        local blockOK,
            blockResult =
            jobs.processCurrentBlock()

        if not blockOK then

            if state.returnRequested then

                return handleReturnRequest()

            end

            return false,
                blockResult

        end

        -- ====================================================
        -- DESPUES DE PROCESAR
        --
        -- jobs.advanceProgress() ya incremento:
        --
        -- currentIndex
        -- completed
        -- blocksThisBatch
        --
        -- La tanda se atendera al inicio
        -- de la siguiente iteracion.
        -- ====================================================

    end

    -- ========================================================
    -- FIN DEL TRABAJO
    -- ========================================================

    return jobs.complete()

end

return jobs
