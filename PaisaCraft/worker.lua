-- ============================================================
-- PAISACRAFT
-- WORKER PRINCIPAL v6.1.5
-- ============================================================

-- ============================================================
-- RUTAS
--
-- Permite ejecutar:
--
-- /PaisaCraft/worker.lua
--
-- desde cualquier directorio.
-- ============================================================

package.path =
    package.path
    ..
    ";/PaisaCraft/?.lua"
    ..
    ";/PaisaCraft/?/init.lua"

-- ============================================================
-- MODULOS
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
-- ESTADO DE EJECUCION
-- ============================================================

local running =
    true

-- Cuando recuperamos un trabajo anterior,
-- la Central no debe considerar la turtle libre.
local recoveryMode =
    false

-- ============================================================
-- UI
-- ============================================================

local function header()

    term.clear()

    term.setCursorPos(
        1,
        1
    )

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
-- VALIDAR POSICION
-- ============================================================

local function validPosition(
    position
)

    return
        type(position)
        ==
        "table"

        and

        type(position.x)
        ==
        "number"

        and

        type(position.y)
        ==
        "number"

        and

        type(position.z)
        ==
        "number"

end

-- ============================================================
-- VALIDAR ASIGNACION
-- ============================================================

local function validateAssignment(
    assignment
)

    if
        type(assignment)
        ~=
        "table"
    then

        return false,
            "ASIGNACION_INVALIDA"

    end

    -- ========================================================
    -- CAMPOS NUMERICOS
    -- ========================================================

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
        in ipairs(
            requiredNumbers
        )
    do

        if
            type(
                assignment[key]
            )
            ~=
            "number"
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
        assignment.width
        <=
        0

        or

        assignment.depth
        <=
        0
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
    -- INDICES
    -- ========================================================

    if
        assignment.startIndex
        <
        0
    then

        return false,
            "START_INDEX_INVALIDO"

    end

    if
        assignment.startIndex
        >
        assignment.endIndex
    then

        return false,
            "INDICES_INVALIDOS"

    end

    local maximumIndex =
        (
            assignment.width
            *
            assignment.depth
        )
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
        mode
        ~=
        config.BUILD_MODES.PLACE

        and

        mode
        ~=
        config.BUILD_MODES.REPLACE

        and

        mode
        ~=
        config.BUILD_MODES.CLEAR
    then

        return false,
            "MODO_INVALIDO:"
            ..
            tostring(mode)

    end

    -- ========================================================
    -- COMBUSTIBLE
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
    --
    -- CLEAR no necesita materiales.
    -- ========================================================

    if
        mode
        ~=
        config.BUILD_MODES.CLEAR

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
    --
    -- REPLACE / CLEAR necesitan descargar
    -- los bloques retirados.
    -- ========================================================

    if
        (
            mode
            ==
            config.BUILD_MODES.REPLACE

            or

            mode
            ==
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

local function report(
    status
)

    if protocol.centralID then

        jobs.report(
            status
        )

    end

end

-- ============================================================
-- ESTADO DEL HEARTBEAT
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
-- PROCESAR MENSAJE DE CONTROL
-- ============================================================

local function processControlMessage(
    msg
)

    if
        type(msg)
        ~=
        "table"
    then

        return true

    end

    -- ========================================================
    -- PAUSE
    -- ========================================================

    if
        msg.type
        ==
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
        msg.type
        ==
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
        msg.type
        ==
        protocol.MESSAGE.RETURN_HOME
    then

        if not state.hasHome() then

            print("")
            print(
                "RETURN_HOME ignorado:"
            )

            print(
                "HOME no configurado."
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

        -- false interrumpe el trabajo actual.

        return false

    end

    return true

end

-- ============================================================
-- MENSAJES PENDIENTES
-- ============================================================

local function checkPendingMessages()

    while true do

        local id,
            msg =
            protocol.receive(
                0
            )

        if not id then

            return

        end

        if
            protocol.centralID

            and

            id
            ==
            protocol.centralID
        then

            processControlMessage(
                msg
            )

        end

    end

end

-- ============================================================
-- ESPERAR SI ESTA PAUSADA
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

        local id,
            msg =
            protocol.receiveCentral(
                2
            )

        if
            id

            and

            type(msg)
            ==
            "table"
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
--
-- jobs / stations / navigation pueden llamar
-- esta funcion durante operaciones largas.
-- ============================================================

local function controlCallback(
    msg
)

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
-- DESPUES DE PARKED
--
-- NO eliminamos assignment.
--
-- Una nueva asignacion puede reemplazar el trabajo ya
-- terminado porque state.hasActiveJob() sera false.
-- ============================================================

local function settleAfterParking()

    state.cancelReturn()

    state.resume()

    state.resetRuntime()

    state.save()

end

-- ============================================================
-- EJECUTAR REGRESO HOME
-- ============================================================

local function executeReturnHome()

    if not state.hasHome() then

        return false,
            "HOME_NO_CONFIGURADO"

    end

    recoveryMode =
        true

    state.resetRuntime()

    -- ========================================================
    -- RECUPERAR POSICION / ORIENTACION
    -- ========================================================

    local orientationOK,
        orientationError =
        movement.ensureOrientation()

    if not orientationOK then

        recoveryMode =
            false

        return false,
            orientationError

    end

    state.requestReturn()

    state.save()

    -- ========================================================
    -- REGRESAR
    -- ========================================================

    local ok,
        err =
        jobs.returnHome()

    if not ok then

        recoveryMode =
            false

        return false,
            err

    end

    settleAfterParking()

    recoveryMode =
        false

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

    recoveryMode =
        true

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

        print("")
        print(
            "Trabajo ya completado."
        )

    else

        print("")
        print(
            "Regreso HOME interrumpido."
        )

    end

    print("")
    print(
        "Reanudando regreso..."
    )

    local ok,
        err =
        executeReturnHome()

    if not ok then

        print("")
        print("==============================")
        print("    ERROR REGRESANDO HOME")
        print("==============================")

        print("")
        print(
            tostring(err)
        )

        recoveryMode =
            false

        return true

    end

    print("")
    print(
        "Regreso recuperado."
    )

    recoveryMode =
        false

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

    recoveryMode =
        true

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

    print(
        "Restantes:",
        state.assignment.endIndex
        -
        state.currentIndex
        +
        1
    )

    if state.home then

        print("")
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

        recoveryMode =
            false

        print("")
        print(
            "Reanudando trabajo..."
        )

        local ok,
            err =
            jobs.run()

        if not ok then

            print("")
            print("==============================")
            print("      TRABAJO DETENIDO")
            print("==============================")

            print("")
            print(
                tostring(err)
            )

            return true

        end

        settleAfterParking()

        return true

    end

    -- ========================================================
    -- REGRESAR HOME
    -- ========================================================

    if option == "3" then

        if not state.hasHome() then

            print("")
            print(
                "No existe HOME guardado."
            )

            recoveryMode =
                false

            return true

        end

        local ok,
            err =
            executeReturnHome()

        if not ok then

            print("")
            print(
                "Error regresando HOME:"
            )

            print(
                tostring(err)
            )

        end

        recoveryMode =
            false

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

    recoveryMode =
        false

    return false

end

-- ============================================================
-- ACEPTAR ASIGNACION
-- ============================================================

local function acceptAssignment(
    msg
)

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

        print("")
        print(
            tostring(
                validationError
            )
        )

        return false

    end

    -- ========================================================
    -- NO SOBRESCRIBIR TRABAJO ACTIVO
    -- ========================================================

    if state.hasActiveJob() then

        print("")
        print(
            "Asignacion ignorada:"
        )

        print(
            "la turtle ya tiene trabajo."
        )

        return false

    end

    -- ========================================================
    -- MODO POR DEFECTO
    -- ========================================================

    if not msg.buildMode then

        msg.buildMode =
            config.DEFAULT_BUILD_MODE

    end

    -- ========================================================
    -- GUARDAR ASIGNACION
    -- ========================================================

    state.setAssignment(
        msg
    )

    -- HOME se capturara donde la turtle
    -- reciba este trabajo.

    state.home =
        nil

    state.resetRuntime()

    state.save()

    -- ========================================================
    -- INFORMACION
    -- ========================================================

    print("")
    print("==============================")
    print("       TRABAJO RECIBIDO")
    print("==============================")

    print("")

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
        "Materiales:"
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
        "Combustible:"
    )

    print(
        msg.fuelStation.x,
        msg.fuelStation.y,
        msg.fuelStation.z
    )

    if msg.unloadStation then

        print("")
        print(
            "Descarga:"
        )

        print(
            msg.unloadStation.x,
            msg.unloadStation.y,
            msg.unloadStation.z
        )

    end

    print("")
    print(
        "Capacidad tanda:",
        config.BATCH_BLOCK_LIMIT
    )

    if
        msg.buildMode
        ==
        config.BUILD_MODES.REPLACE
    then

        print(
            "Slot reservado:",
            config.RESERVED_SLOT
        )

    end

    return true

end

-- ============================================================
-- ESPERAR ASIGNACION
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

        local id,
            msg =
            protocol.receive(
                2
            )

        if
            id

            and

            protocol.centralID

            and

            id
            ==
            protocol.centralID

            and

            type(msg)
            ==
            "table"
        then

            -- =================================================
            -- NUEVO TRABAJO
            -- =================================================

            if
                msg.type
                ==
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
-- EJECUTAR TRABAJO ACTUAL
-- ============================================================

local function runCurrentJob()

    state.resetRuntime()

    -- ========================================================
    -- POSICION / ORIENTACION
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

    local ok,
        err =
        jobs.run()

    if not ok then

        return false,
            err

    end

    -- jobs.complete() ya hizo:
    --
    -- descarga final
    -- COMPLETE
    -- regreso HOME
    --
    -- Aqui solo limpiamos flags runtime.

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
        -- REDESCUBRIR CENTRAL
        --
        -- Permite sobrevivir a un reboot de la Central.
        -- ====================================================

        local discovered =
            protocol.findCentral()

        if discovered then

            protocol.centralID =
                discovered

            -- =================================================
            -- CENTRAL NUEVA / REINICIADA
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

            protocol.sendHeartbeat(
                getHeartbeatStatus()
            )

        else

            -- No eliminamos el trabajo local.
            -- Solo dejamos de enviar mensajes.

            protocol.centralID =
                nil

        end

        sleep(
            config.HEARTBEAT_INTERVAL
        )

    end

end

-- ============================================================
-- CARGAR ESTADO
-- ============================================================

local function loadPreviousState()

    local loaded,
        loadError =
        state.load()

    if loaded then

        print(
            "Estado anterior cargado."
        )

        if state.assignment then

            print(
                "Indice:",
                state.currentIndex
                or
                "-"
            )

            print(
                "Tanda:",
                state.blocksThisBatch,
                "/",
                config.BATCH_BLOCK_LIMIT
            )

        end

        return true

    end

    if
        loadError
        ~=
        "SIN_ESTADO_GUARDADO"
    then

        print(
            "Estado no cargado:",
            tostring(loadError)
        )

    else

        print(
            "Sin estado anterior."
        )

    end

    return false

end

-- ============================================================
-- MAIN DEL WORKER
-- ============================================================

local function workerLoop()

    -- ========================================================
    -- CARGAR ESTADO
    -- ========================================================

    loadPreviousState()

    -- ========================================================
    -- CONECTAR A CENTRAL
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
    -- REGRESO INTERRUMPIDO
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

            local ok,
                err =
                runCurrentJob()

            if not ok then

                print("")
                print("==============================")
                print("      TRABAJO DETENIDO")
                print("==============================")

                print("")
                print(
                    tostring(err)
                )

                state.save()

                -- =============================================
                -- SI EL ERROR SE PRODUJO DURANTE
                -- RETURN_HOME, intentamos completar regreso.
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
                            "No pude regresar:"
                        )

                        print(
                            tostring(
                                homeError
                            )
                        )

                    end

                end

                print("")
                print(
                    "Worker continua activo."
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
