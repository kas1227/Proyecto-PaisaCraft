-- ============================================================
-- PAISACRAFT
-- WORKER PRINCIPAL v6.1.3
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local protocol =
    require("lib.protocol")

local movement =
    require("lib.movement")

local jobs =
    require("lib.jobs")

-- ============================================================
-- ESTADO DE EJECUCIÓN
-- ============================================================

local running = true

-- Durante la pantalla de recuperación de un trabajo anterior
-- queremos que la central NO considere la turtle disponible.
local recoveryMode = false

-- ============================================================
-- UI
-- ============================================================

local function header()

    term.clear()
    term.setCursorPos(1, 1)

    print("==============================")
    print("       PAISACRAFT WORKER")
    print("==============================")

    print("")

    print(
        "Version:",
        config.VERSION
    )

    print(
        "Turtle ID:",
        os.getComputerID()
    )

    print("")

end

-- ============================================================
-- VALIDAR POSICIÓN
-- ============================================================

local function validPosition(position)

    return
        type(position) == "table"
        and
        type(position.x) == "number"
        and
        type(position.y) == "number"
        and
        type(position.z) == "number"

end

-- ============================================================
-- VALIDAR ASIGNACIÓN
-- ============================================================

local function validateAssignment(
    assignment
)

    if type(assignment) ~= "table" then

        return false,
            "ASIGNACION_INVALIDA"

    end

    local requiredNumbers = {

        "minX",
        "maxX",

        "minZ",
        "maxZ",

        "floorY",

        "width",
        "depth",

        "startIndex",
        "endIndex",

        "count"

    }

    for _, key
        in ipairs(requiredNumbers)
    do

        if
            type(
                assignment[key]
            )
            ~= "number"
        then

            return false,
                "FALTA_CAMPO:"
                ..
                key

        end

    end

    -- ========================================================
    -- DIMENSIONES
    -- ========================================================

    if
        assignment.width <= 0
        or
        assignment.depth <= 0
    then

        return false,
            "DIMENSION_INVALIDA"

    end

    if
        assignment.minX
        >
        assignment.maxX
        or
        assignment.minZ
        >
        assignment.maxZ
    then

        return false,
            "AREA_INVALIDA"

    end

    -- ========================================================
    -- ÍNDICES
    -- ========================================================

    if
        assignment.startIndex
        >
        assignment.endIndex
    then

        return false,
            "INDICES_INVALIDOS"

    end

    if assignment.startIndex < 0 then

        return false,
            "START_INDEX_INVALIDO"

    end

    local maximumIndex =
        assignment.width
        *
        assignment.depth
        -
        1

    if
        assignment.endIndex
        >
        maximumIndex
    then

        return false,
            "END_INDEX_FUERA_AREA"

    end

    local expectedCount =
        assignment.endIndex
        -
        assignment.startIndex
        +
        1

    if
        assignment.count
        ~=
        expectedCount
    then

        return false,
            "COUNT_INCONSISTENTE"

    end

    -- ========================================================
    -- MODO
    -- ========================================================

    local mode =
        assignment.buildMode
        or
        config.DEFAULT_BUILD_MODE

    if
        mode ~= config.BUILD_MODES.PLACE
        and
        mode ~= config.BUILD_MODES.REPLACE
        and
        mode ~= config.BUILD_MODES.CLEAR
    then

        return false,
            "MODO_INVALIDO:"
            ..
            tostring(mode)

    end

    -- ========================================================
    -- FUEL
    -- ========================================================

    if
        not validPosition(
            assignment.fuelStation
        )
    then

        return false,
            "FUEL_STATION_INVALIDA"

    end

    -- ========================================================
    -- MATERIALES
    -- ========================================================

    if
        mode ~= config.BUILD_MODES.CLEAR
        and
        not validPosition(
            assignment.materialStation
        )
    then

        return false,
            "MATERIAL_STATION_INVALIDA"

    end

    -- ========================================================
    -- DESCARGA
    -- ========================================================

    if
        (
            mode ==
            config.BUILD_MODES.REPLACE

            or

            mode ==
            config.BUILD_MODES.CLEAR
        )
        and
        not validPosition(
            assignment.unloadStation
        )
    then

        return false,
            "UNLOAD_STATION_INVALIDA"

    end

    return true

end

-- ============================================================
-- REPORTAR
-- ============================================================

local function report(status)

    if protocol.centralID then

        jobs.report(
            status
        )

    end

end

-- ============================================================
-- ESTADO PARA HEARTBEAT
--
-- Este estado es deliberadamente conservador.
--
-- La prioridad es que tras reiniciar la central
-- una turtle ocupada NO aparezca como disponible.
-- ============================================================

local function getHeartbeatStatus()

    if recoveryMode then
        return "RECOVERY"
    end

    if state.returnRequested then
        return "RETURNING_HOME"
    end

    if state.paused then
        return "PAUSED"
    end

    if state.hasActiveJob() then
        return "BUILDING"
    end

    return "IDLE"

end

-- ============================================================
-- PROCESAR CONTROL
-- ============================================================

local function processControlMessage(msg)

    if type(msg) ~= "table" then
        return true
    end

    -- ========================================================
    -- PAUSE
    -- ========================================================

    if
        msg.type ==
        protocol.MESSAGE.PAUSE
    then

        state.pause()

        state.save()

        print("")
        print(
            "PAUSA solicitada."
        )

        return true

    end

    -- ========================================================
    -- RESUME
    -- ========================================================

    if
        msg.type ==
        protocol.MESSAGE.RESUME
    then

        state.resume()

        state.save()

        print("")
        print(
            "Trabajo reanudado."
        )

        return true

    end

    -- ========================================================
    -- RETURN HOME
    -- ========================================================

    if
        msg.type ==
        protocol.MESSAGE.RETURN_HOME
    then

        -- Si no existe HOME todavía no podemos ejecutar
        -- realmente un regreso.
        if not state.hasHome() then

            print("")
            print(
                "RETURN_HOME ignorado:"
            )

            print(
                "HOME todavía no existe."
            )

            return true

        end

        state.requestReturn()

        state.pause()

        state.save()

        print("")
        print(
            "Regreso HOME solicitado."
        )

        return false

    end

    return true

end

-- ============================================================
-- MENSAJES PENDIENTES
-- ============================================================

local function checkPendingMessages()

    while true do

        local id, msg =
            protocol.receive(0)

        if not id then
            return
        end

        if
            protocol.centralID
            and
            id ==
            protocol.centralID
        then

            processControlMessage(
                msg
            )

        end

    end

end

-- ============================================================
-- PAUSA
-- ============================================================

local function waitIfPaused()

    if not state.paused then
        return true
    end

    if state.returnRequested then
        return false
    end

    report(
        "PAUSED"
    )

    print("")
    print("==============================")
    print("           PAUSADO")
    print("==============================")

    while
        state.paused
        and
        not state.returnRequested
    do

        local id, msg =
            protocol.receiveCentral(
                2
            )

        if
            id
            and
            type(msg) == "table"
        then

            processControlMessage(
                msg
            )

        end

        report(
            "PAUSED"
        )

    end

    if state.returnRequested then
        return false
    end

    report(
        "BUILDING"
    )

    return true

end

-- ============================================================
-- CALLBACK DE CONTROL
-- ============================================================

local function controlCallback(msg)

    if msg then

        processControlMessage(
            msg
        )

    else

        checkPendingMessages()

    end

    if state.returnRequested then
        return false
    end

    if state.paused then

        return waitIfPaused()

    end

    return true

end

-- ============================================================
-- REGISTRAR CALLBACK
-- ============================================================

jobs.setControlCallback(
    controlCallback
)

-- ============================================================
-- DESPUÉS DE PARKED
-- ============================================================

local function settleAfterParking()

    state.cancelReturn()

    state.resume()

    state.resetRuntime()

    state.save()

end

-- ============================================================
-- REGRESAR HOME
-- ============================================================

local function executeReturnHome()

    if not state.hasHome() then

        return false,
            "HOME_NO_CONFIGURADO"

    end

    recoveryMode = true

    state.resetRuntime()

    -- ========================================================
    -- ORIENTACIÓN
    -- ========================================================

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        recoveryMode = false

        return false,
            orientationError

    end

    state.requestReturn()

    state.save()

    -- ========================================================
    -- REGRESAR
    -- ========================================================

    local ok, err =
        jobs.returnHome()

    if not ok then

        recoveryMode = false

        return false,
            err

    end

    settleAfterParking()

    recoveryMode = false

    return true

end

-- ============================================================
-- RECUPERAR REGRESO INTERRUMPIDO
-- ============================================================

local function recoverPendingReturn()

    if
        not state.hasPendingReturn()
    then

        return false

    end

    recoveryMode = true

    print("")
    print("==============================")
    print("  REGRESO PENDIENTE DETECTADO")
    print("==============================")

    if
        state.currentIndex
        and
        state.assignment
        and
        state.assignment.endIndex
        and
        state.currentIndex
        >
        state.assignment.endIndex
    then

        print(
            "Trabajo ya completado."
        )

    else

        print(
            "Regreso HOME interrumpido."
        )

    end

    print("")
    print(
        "Reanudando regreso..."
    )

    local ok, err =
        executeReturnHome()

    if not ok then

        print("")
        print("==============================")
        print("    ERROR REGRESANDO HOME")
        print("==============================")

        print(
            tostring(err)
        )

        recoveryMode = false

        return true

    end

    print("")
    print(
        "Regreso recuperado."
    )

    recoveryMode = false

    return true

end

-- ============================================================
-- TRABAJO ANTERIOR
-- ============================================================

local function handlePreviousJob()

    if
        not state.hasActiveJob()
    then

        return false

    end

    recoveryMode = true

    print("")
    print("==============================")
    print("   TRABAJO ANTERIOR ENCONTRADO")
    print("==============================")

    print("")

    print(
        "Progreso:",
        state.completed,
        "/",
        state.assignment.count
    )

    print(
        "Indice:",
        state.currentIndex,
        "/",
        state.assignment.endIndex
    )

    print(
        "Tanda:",
        state.blocksThisBatch,
        "/",
        config.BATCH_BLOCK_LIMIT
    )

    if state.home then

        print(
            "HOME:",
            state.home.x,
            state.home.y,
            state.home.z
        )

    end

    print("")
    print("1. Continuar")
    print("2. Descartar")
    print("3. Regresar HOME")
    print("")

    write("> ")

    local option =
        read()

    -- ========================================================
    -- CONTINUAR
    -- ========================================================

    if option == "1" then

        state.resetRuntime()

        state.resume()

        state.cancelReturn()

        state.save()

        recoveryMode = false

        print("")
        print(
            "Reanudando trabajo..."
        )

        local ok, err =
            jobs.run()

        if not ok then

            print("")
            print("==============================")
            print("      TRABAJO DETENIDO")
            print("==============================")

            print(
                tostring(err)
            )

            return true

        end

        settleAfterParking()

        return true

    end

    -- ========================================================
    -- HOME
    -- ========================================================

    if option == "3" then

        if not state.hasHome() then

            print("")
            print(
                "No existe HOME guardado."
            )

            recoveryMode = false

            return true

        end

        local ok, err =
            executeReturnHome()

        if not ok then

            print("")
            print(
                "Error regresando HOME:",
                tostring(err)
            )

        end

        recoveryMode = false

        return true

    end

    -- ========================================================
    -- DESCARTAR
    -- ========================================================

    print("")
    print(
        "Descartando trabajo anterior..."
    )

    state.clearJob()

    recoveryMode = false

    return false

end

-- ============================================================
-- ACEPTAR ASIGNACIÓN
-- ============================================================

local function acceptAssignment(msg)

    local valid,
        validationError =
        validateAssignment(
            msg
        )

    if not valid then

        print("")
        print("==============================")
        print("     ASIGNACION RECHAZADA")
        print("==============================")

        print(
            tostring(
                validationError
            )
        )

        return false

    end

    -- ========================================================
    -- PROTECCIÓN ADICIONAL
    --
    -- Nunca sobrescribimos un trabajo activo.
    -- ========================================================

    if state.hasActiveJob() then

        print("")
        print(
            "Asignación ignorada:"
        )

        print(
            "la turtle ya tiene trabajo."
        )

        return false

    end

    if not msg.buildMode then

        msg.buildMode =
            config.DEFAULT_BUILD_MODE

    end

    -- ========================================================
    -- GUARDAR
    -- ========================================================

    state.setAssignment(
        msg
    )

    -- HOME de cada trabajo =
    -- posición donde recibió esa asignación.
    state.home = nil

    state.resetRuntime()

    state.save()

    print("")
    print("==============================")
    print("       TRABAJO RECIBIDO")
    print("==============================")

    print(
        "Bloques:",
        msg.count
    )

    print(
        "Indices:",
        msg.startIndex,
        "->",
        msg.endIndex
    )

    print(
        "Modo:",
        msg.buildMode
    )

    print("")
    print(
        "Material station:"
    )

    if msg.materialStation then

        print(
            msg.materialStation.x,
            msg.materialStation.y,
            msg.materialStation.z
        )

    else

        print(
            "No requerida"
        )

    end

    print("")
    print(
        "Fuel station:"
    )

    print(
        msg.fuelStation.x,
        msg.fuelStation.y,
        msg.fuelStation.z
    )

    if msg.unloadStation then

        print("")
        print(
            "Unload station:"
        )

        print(
            msg.unloadStation.x,
            msg.unloadStation.y,
            msg.unloadStation.z
        )

    end

    return true

end

-- ============================================================
-- ESPERAR ASIGNACIÓN
-- ============================================================

local function waitForAssignment()

    print("")
    print("==============================")
    print("      ESPERANDO TRABAJO")
    print("==============================")

    report(
        "IDLE"
    )

    while running do

        local id, msg =
            protocol.receive(
                2
            )

        if
            id
            and
            protocol.centralID
            and
            id ==
            protocol.centralID
            and
            type(msg) == "table"
        then

            if
                msg.type ==
                protocol.MESSAGE.ASSIGN
            then

                if
                    acceptAssignment(
                        msg
                    )
                then

                    return true

                end

            else

                processControlMessage(
                    msg
                )

            end

        end

    end

    return false

end

-- ============================================================
-- EJECUTAR TRABAJO
-- ============================================================

local function runCurrentJob()

    state.resetRuntime()

    -- ========================================================
    -- ORIENTACIÓN
    -- ========================================================

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        return false,
            "ORIENTACION:"
            ..
            tostring(
                orientationError
            )

    end

    -- ========================================================
    -- HOME
    -- ========================================================

    if not state.hasHome() then

        local homeOK,
            homeError =
            jobs.captureHome()

        if not homeOK then

            return false,
                "HOME:"
                ..
                tostring(
                    homeError
                )

        end

    end

    -- ========================================================
    -- EJECUTAR
    -- ========================================================

    local ok, err =
        jobs.run()

    if not ok then

        return false,
            err

    end

    settleAfterParking()

    return true

end

-- ============================================================
-- HEARTBEAT
-- ============================================================

local function heartbeatLoop()

    while running do

        local previousCentral =
            protocol.centralID

        -- ====================================================
        -- DESCUBRIR CENTRAL DE NUEVO
        --
        -- Esto permite:
        --
        -- - central reiniciada
        -- - central sustituida
        -- - cambio de computer ID
        -- ====================================================

        local discovered =
            protocol.findCentral()

        if discovered then

            protocol.centralID =
                discovered

            -- =================================================
            -- CENTRAL NUEVA / CAMBIADA
            -- =================================================

            if
                previousCentral
                ~=
                discovered
            then

                print("")
                print(
                    "Central detectada:",
                    discovered
                )

                protocol.sendHello()

            end

            -- =================================================
            -- HEARTBEAT
            --
            -- El estado evita que una central recién
            -- reiniciada considere libre una turtle ocupada.
            -- =================================================

            protocol.sendHeartbeat(
                getHeartbeatStatus()
            )

        else

            -- No descartamos inmediatamente el trabajo.
            -- Simplemente dejamos de enviar hasta
            -- reencontrar una central.

            protocol.centralID =
                nil

        end

        sleep(
            config.HEARTBEAT_INTERVAL
        )

    end

end

-- ============================================================
-- MAIN DEL WORKER
-- ============================================================

local function workerLoop()

    -- ========================================================
    -- CARGAR
    -- ========================================================

    if state.load() then

        print(
            "Estado anterior cargado."
        )

    else

        print(
            "Sin estado anterior."
        )

    end

    -- ========================================================
    -- CONECTAR
    -- ========================================================

    local connected,
        connectionError =
        protocol.connect()

    if not connected then

        error(
            tostring(
                connectionError
            )
        )

    end

    -- ========================================================
    -- RETURN INTERRUMPIDO
    -- ========================================================

    recoverPendingReturn()

    -- ========================================================
    -- TRABAJO INTERRUMPIDO
    -- ========================================================

    handlePreviousJob()

    -- ========================================================
    -- CICLO PERMANENTE
    -- ========================================================

    while running do

        local assigned =
            waitForAssignment()

        if assigned then

            local ok, err =
                runCurrentJob()

            if not ok then

                print("")
                print("==============================")
                print("      TRABAJO DETENIDO")
                print("==============================")

                print(
                    tostring(err)
                )

                state.save()

                -- =============================================
                -- REGRESO DE SEGURIDAD
                -- =============================================

                if
                    state.returnRequested
                    and
                    state.hasHome()
                then

                    print("")
                    print(
                        "Intentando regresar HOME..."
                    )

                    local homeOK,
                        homeError =
                        executeReturnHome()

                    if not homeOK then

                        print(
                            "No pude regresar:",
                            tostring(
                                homeError
                            )
                        )

                    end

                end

                print("")
                print(
                    "Worker continúa activo."
                )

            end

        end

    end

end

-- ============================================================
-- MAIN
-- ============================================================

header()

parallel.waitForAny(

    workerLoop,

    heartbeatLoop

)