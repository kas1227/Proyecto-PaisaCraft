-- ============================================================
-- PAISACRAFT
-- CENTRAL v6.1.4
--
-- - 3 estaciones con cola exclusiva
-- - Heartbeat / workers offline
-- - Timeout de reservas
-- - Solo workers disponibles reciben trabajo
-- - División por filas completas
-- - Asignación por proximidad
-- ============================================================

local config =
    require("lib.config")

local protocol =
    require("lib.protocol")

-- ============================================================
-- ESTADO
-- ============================================================

local workers = {}

local running = true

local materialQueue = {}
local fuelQueue = {}
local unloadQueue = {}

local materialOwner = nil
local fuelOwner = nil
local unloadOwner = nil

-- ============================================================
-- TIEMPO
-- ============================================================

local function now()

    return
        os.epoch("utc")
        /
        1000

end

-- ============================================================
-- MODEM
-- ============================================================

local function openModem()

    for _, name
        in ipairs(
            peripheral.getNames()
        )
    do

        if
            peripheral.getType(name)
            == "modem"
        then

            if not rednet.isOpen(name) then

                rednet.open(name)

            end

            return name

        end

    end

    error(
        "No encuentro modem."
    )

end

-- ============================================================
-- HOST
-- ============================================================

local function hostNetwork()

    pcall(
        rednet.unhost,
        config.PROTOCOL
    )

    rednet.host(

        config.PROTOCOL,

        config.CENTRAL_HOSTNAME

    )

end

-- ============================================================
-- SEND
-- ============================================================

local function send(
    id,
    message
)

    rednet.send(

        id,

        message,

        config.PROTOCOL

    )

end

-- ============================================================
-- WORKERS
-- ============================================================

local function sortedWorkerIDs(
    predicate
)

    local ids = {}

    for id, worker
        in pairs(workers)
    do

        if
            not predicate
            or
            predicate(worker)
        then

            table.insert(
                ids,
                id
            )

        end

    end

    table.sort(ids)

    return ids

end


local function countWorkers()

    local total = 0

    for _ in pairs(workers) do
        total = total + 1
    end

    return total

end

-- ============================================================
-- ONLINE
-- ============================================================

local function isWorkerOnline(
    worker
)

    if not worker then
        return false
    end

    return
        (
            now()
            -
            worker.lastSeen
        )
        <=
        config.WORKER_TIMEOUT

end

-- ============================================================
-- DISPONIBLE
-- ============================================================

local function isWorkerAvailable(
    worker
)

    if not isWorkerOnline(worker) then
        return false
    end

    return
        worker.status == "CONNECTED"
        or
        worker.status == "IDLE"
        or
        worker.status == "PARKED"

end

-- ============================================================
-- WORKERS DISPONIBLES
-- ============================================================

local function availableWorkerIDs()

    return sortedWorkerIDs(

        function(worker)

            return
                isWorkerAvailable(
                    worker
                )

        end

    )

end

-- ============================================================
-- DISTANCIA
-- ============================================================

local function distance(
    position,
    target
)

    if
        not position
        or
        not target
    then

        return math.huge

    end

    return

        math.abs(
            position.x
            -
            target.x
        )

        +

        math.abs(
            position.y
            -
            target.y
        )

        +

        math.abs(
            position.z
            -
            target.z
        )

end

-- ============================================================
-- COLAS
-- ============================================================

local function queueContains(
    queue,
    id
)

    for _, value
        in ipairs(queue)
    do

        if value == id then
            return true
        end

    end

    return false

end


local function removeFromQueue(
    queue,
    id
)

    for index =
        #queue,
        1,
        -1
    do

        if queue[index] == id then

            table.remove(
                queue,
                index
            )

        end

    end

end


local function queuePosition(
    queue,
    id
)

    for index, value
        in ipairs(queue)
    do

        if value == id then
            return index
        end

    end

    return nil

end

-- ============================================================
-- MATERIAL
-- ============================================================

local function grantMaterial()

    if materialOwner then
        return
    end

    while #materialQueue > 0 do

        local id =
            table.remove(
                materialQueue,
                1
            )

        if
            workers[id]
            and
            isWorkerOnline(
                workers[id]
            )
        then

            materialOwner = id

            send(
                id,
                {
                    type =
                        protocol.MESSAGE.MATERIAL_GRANTED
                }
            )

            return

        end

    end

end


local function requestMaterial(id)

    if materialOwner == id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.MATERIAL_GRANTED
            }
        )

        return

    end

    if
        not queueContains(
            materialQueue,
            id
        )
    then

        table.insert(
            materialQueue,
            id
        )

    end

    grantMaterial()

    if materialOwner ~= id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.MATERIAL_WAIT,

                position =
                    queuePosition(
                        materialQueue,
                        id
                    )
            }
        )

    end

end


local function finishMaterial(id)

    if materialOwner == id then
        materialOwner = nil
    end

    removeFromQueue(
        materialQueue,
        id
    )

    grantMaterial()

end

-- ============================================================
-- FUEL
-- ============================================================

local function grantFuel()

    if fuelOwner then
        return
    end

    while #fuelQueue > 0 do

        local id =
            table.remove(
                fuelQueue,
                1
            )

        if
            workers[id]
            and
            isWorkerOnline(
                workers[id]
            )
        then

            fuelOwner = id

            send(
                id,
                {
                    type =
                        protocol.MESSAGE.FUEL_GRANTED
                }
            )

            return

        end

    end

end


local function requestFuel(id)

    if fuelOwner == id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.FUEL_GRANTED
            }
        )

        return

    end

    if
        not queueContains(
            fuelQueue,
            id
        )
    then

        table.insert(
            fuelQueue,
            id
        )

    end

    grantFuel()

    if fuelOwner ~= id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.FUEL_WAIT,

                position =
                    queuePosition(
                        fuelQueue,
                        id
                    )
            }
        )

    end

end


local function finishFuel(id)

    if fuelOwner == id then
        fuelOwner = nil
    end

    removeFromQueue(
        fuelQueue,
        id
    )

    grantFuel()

end

-- ============================================================
-- DESCARGA
-- ============================================================

local function grantUnload()

    if unloadOwner then
        return
    end

    while #unloadQueue > 0 do

        local id =
            table.remove(
                unloadQueue,
                1
            )

        if
            workers[id]
            and
            isWorkerOnline(
                workers[id]
            )
        then

            unloadOwner = id

            send(
                id,
                {
                    type =
                        protocol.MESSAGE.UNLOAD_GRANTED
                }
            )

            return

        end

    end

end


local function requestUnload(id)

    if unloadOwner == id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.UNLOAD_GRANTED
            }
        )

        return

    end

    if
        not queueContains(
            unloadQueue,
            id
        )
    then

        table.insert(
            unloadQueue,
            id
        )

    end

    grantUnload()

    if unloadOwner ~= id then

        send(
            id,
            {
                type =
                    protocol.MESSAGE.UNLOAD_WAIT,

                position =
                    queuePosition(
                        unloadQueue,
                        id
                    )
            }
        )

    end

end


local function finishUnload(id)

    if unloadOwner == id then
        unloadOwner = nil
    end

    removeFromQueue(
        unloadQueue,
        id
    )

    grantUnload()

end

-- ============================================================
-- CANCELAR TODAS LAS RESERVAS
-- ============================================================

local function cancelReservations(id)

    finishMaterial(id)
    finishFuel(id)
    finishUnload(id)

end

-- ============================================================
-- CREAR WORKER
-- ============================================================

local function createWorker(
    id,
    msg
)

    return {

        id = id,

        version =
            msg.version
            or
            "?",

        status =
            "CONNECTED",

        completed = 0,

        currentIndex = nil,

        remainingBlocks = 0,

        blocksThisBatch = 0,

        batchRemaining = 0,

        batchLimit =
            config.BATCH_BLOCK_LIMIT,

        fuel = 0,

        fuelTarget = 0,

        fuelSafeReturn = 0,

        buildMode =
            config.DEFAULT_BUILD_MODE,

        position = nil,

        assignment = nil,

        lastSeen =
            now()

    }

end

-- ============================================================
-- REGISTRAR
-- ============================================================

local function registerWorker(
    id,
    msg
)

    if not workers[id] then

        workers[id] =
            createWorker(
                id,
                msg
            )

        print(
            "Worker conectado:",
            id
        )

    else

        workers[id].lastSeen =
            now()

        workers[id].version =
            msg.version
            or
            workers[id].version

        if
            workers[id].status
            ==
            "OFFLINE"
        then

            workers[id].status =
                "CONNECTED"

        end

    end

end

-- ============================================================
-- PROGRESO
-- ============================================================

local function updateProgress(
    id,
    msg
)

    local worker =
        workers[id]

    if not worker then
        return
    end

    worker.lastSeen =
        now()

    local fields = {

        "status",

        "completed",

        "currentIndex",

        "remainingBlocks",

        "blocksThisBatch",

        "batchRemaining",

        "batchLimit",

        "fuel",

        "fuelTarget",

        "fuelSafeReturn",

        "buildMode"

    }

    for _, field
        in ipairs(fields)
    do

        if msg[field] ~= nil then

            worker[field] =
                msg[field]

        end

    end

    if
        type(msg.position)
        ==
        "table"
    then

        worker.position = {

            x =
                msg.position.x,

            y =
                msg.position.y,

            z =
                msg.position.z

        }

    end

end

-- ============================================================
-- HEARTBEAT
-- ============================================================

local function processHeartbeat(
    id,
    msg
)

    if not workers[id] then

        registerWorker(
            id,
            msg
        )

    end

    local worker =
        workers[id]

    worker.lastSeen =
        now()

    worker.version =
        msg.version
        or
        worker.version

    if msg.status then

        worker.status =
            msg.status

    elseif worker.status == "OFFLINE" then

        worker.status =
            "CONNECTED"

    end

end

-- ============================================================
-- TIMEOUTS
-- ============================================================

local function cleanupTimeouts()

    local current =
        now()

    for id, worker
        in pairs(workers)
    do

        local age =
            current
            -
            worker.lastSeen

        if
            age
            >
            config.WORKER_TIMEOUT
        then

            if
                worker.status
                ~=
                "OFFLINE"
            then

                print(
                    "Worker",
                    id,
                    "OFFLINE"
                )

            end

            worker.status =
                "OFFLINE"

        end

        if
            age
            >
            config.RESERVATION_TIMEOUT
        then

            cancelReservations(
                id
            )

        end

    end

end

-- ============================================================
-- MENSAJES
-- ============================================================

local function processMessage(
    id,
    msg
)

    if type(msg) ~= "table" then
        return
    end

    if
        msg.type ==
        protocol.MESSAGE.HELLO
    then

        registerWorker(
            id,
            msg
        )

        return

    end

    if
        msg.type ==
        protocol.MESSAGE.HEARTBEAT
    then

        processHeartbeat(
            id,
            msg
        )

        return

    end

    if not workers[id] then
        return
    end

    workers[id].lastSeen =
        now()

    if
        msg.type ==
        protocol.MESSAGE.PROGRESS
    then

        updateProgress(
            id,
            msg
        )

    elseif
        msg.type ==
        protocol.MESSAGE.MATERIAL_REQUEST
    then

        requestMaterial(id)

    elseif
        msg.type ==
        protocol.MESSAGE.MATERIAL_DONE
    then

        finishMaterial(id)

    elseif
        msg.type ==
        protocol.MESSAGE.FUEL_REQUEST
    then

        requestFuel(id)

    elseif
        msg.type ==
        protocol.MESSAGE.FUEL_DONE
    then

        finishFuel(id)

    elseif
        msg.type ==
        protocol.MESSAGE.UNLOAD_REQUEST
    then

        requestUnload(id)

    elseif
        msg.type ==
        protocol.MESSAGE.UNLOAD_DONE
    then

        finishUnload(id)

    elseif
        msg.type ==
        protocol.MESSAGE.CANCEL_RESERVATIONS
    then

        cancelReservations(id)

    elseif
        msg.type ==
        protocol.MESSAGE.COMPLETE
    then

        workers[id].status =
            "COMPLETE"

    elseif
        msg.type ==
        protocol.MESSAGE.PARKED
    then

        workers[id].status =
            "PARKED"

        cancelReservations(id)

    end

end

-- ============================================================
-- INPUT NÚMERO
-- ============================================================

local function askNumber(text)

    while true do

        write(text)

        local value =
            tonumber(
                read()
            )

        if value then

            return
                math.floor(
                    value
                )

        end

        print(
            "Número inválido."
        )

    end

end

-- ============================================================
-- POSICIÓN OBLIGATORIA
-- ============================================================

local function askRequiredPosition(
    title
)

    print("")
    print(title)

    return {

        x =
            askNumber("X: "),

        y =
            askNumber("Y: "),

        z =
            askNumber("Z: ")

    }

end

-- ============================================================
-- MODO
-- ============================================================

local function askBuildMode()

    print("")
    print("==============================")
    print("       MODO DE TRABAJO")
    print("==============================")

    print("")
    print("1. Colocar")
    print("2. Reemplazar")
    print("3. Limpiar")

    print("")
    write("> ")

    local value =
        read()

    if value == "2" then

        return
            config.BUILD_MODES.REPLACE

    elseif value == "3" then

        return
            config.BUILD_MODES.CLEAR

    end

    return
        config.BUILD_MODES.PLACE

end

-- ============================================================
-- FILTRO
-- ============================================================

local function askReplaceFilter(
    mode
)

    if
        mode
        ~=
        config.BUILD_MODES.REPLACE
    then

        return nil

    end

    print("")
    print(
        "¿Reemplazar cualquier bloque? (s/n)"
    )

    write("> ")

    if
        string.lower(
            read()
        )
        ==
        "s"
    then

        return nil

    end

    local result = {}

    print("")
    print(
        "IDs a reemplazar."
    )

    print(
        "ENTER vacío para terminar."
    )

    while true do

        write("> ")

        local block =
            read()

        if block == "" then
            break
        end

        result[block] =
            true

    end

    return result

end

-- ============================================================
-- PRIMER BLOQUE DE UNA FILA
-- ============================================================

local function rowFirstPosition(
    job,
    row
)

    local x

    if row % 2 == 0 then

        x =
            job.minX

    else

        x =
            job.maxX

    end

    return {

        x = x,

        y =
            job.floorY
            +
            1,

        z =
            job.minZ
            +
            row

    }

end

-- ============================================================
-- CREAR BANDAS DE FILAS
--
-- Nunca divide una fila entre dos turtles.
-- ============================================================

local function createRowBands(
    job,
    workerCount
)

    local bandCount =
        math.min(
            workerCount,
            job.depth
        )

    local baseRows =
        math.floor(
            job.depth
            /
            bandCount
        )

    local remainder =
        job.depth
        %
        bandCount

    local bands = {}

    local nextRow = 0

    for bandNumber =
        1,
        bandCount
    do

        local rows =
            baseRows

        if
            bandNumber
            <=
            remainder
        then

            rows =
                rows + 1

        end

        local rowStart =
            nextRow

        local rowEnd =
            rowStart
            +
            rows
            -
            1

        local startIndex =
            rowStart
            *
            job.width

        local endIndex =
            (
                rowEnd
                +
                1
            )
            *
            job.width
            -
            1

        table.insert(
            bands,
            {

                rowStart =
                    rowStart,

                rowEnd =
                    rowEnd,

                rows =
                    rows,

                startIndex =
                    startIndex,

                endIndex =
                    endIndex,

                count =
                    rows
                    *
                    job.width,

                firstPosition =
                    rowFirstPosition(
                        job,
                        rowStart
                    )

            }
        )

        nextRow =
            rowEnd
            +
            1

    end

    return bands

end

-- ============================================================
-- BUSCAR WORKER MÁS CERCANO
-- ============================================================

local function takeNearestWorker(
    availableIDs,
    target
)

    if #availableIDs == 0 then
        return nil
    end

    local bestIndex = 1
    local bestDistance =
        math.huge

    for index, id
        in ipairs(
            availableIDs
        )
    do

        local worker =
            workers[id]

        local currentDistance =
            distance(
                worker.position,
                target
            )

        -- Si ninguno tiene posición conocida,
        -- conservará simplemente el orden de IDs.

        if
            currentDistance
            <
            bestDistance
        then

            bestDistance =
                currentDistance

            bestIndex =
                index

        end

    end

    local id =
        availableIDs[
            bestIndex
        ]

    table.remove(
        availableIDs,
        bestIndex
    )

    return id

end

-- ============================================================
-- CREAR ASSIGNMENT
-- ============================================================

local function buildAssignment(
    job,
    band
)

    return {

        type =
            protocol.MESSAGE.ASSIGN,

        -- =========================
        -- ÁREA GLOBAL
        -- =========================

        minX =
            job.minX,

        maxX =
            job.maxX,

        minZ =
            job.minZ,

        maxZ =
            job.maxZ,

        floorY =
            job.floorY,

        width =
            job.width,

        depth =
            job.depth,

        -- =========================
        -- BANDA DEL WORKER
        -- =========================

        rowStart =
            band.rowStart,

        rowEnd =
            band.rowEnd,

        startIndex =
            band.startIndex,

        endIndex =
            band.endIndex,

        count =
            band.count,

        -- =========================
        -- TRABAJO
        -- =========================

        buildMode =
            job.buildMode,

        replaceFilter =
            job.replaceFilter,

        -- =========================
        -- ESTACIONES
        -- =========================

        materialStation =
            job.materialStation,

        fuelStation =
            job.fuelStation,

        unloadStation =
            job.unloadStation

    }

end

-- ============================================================
-- DIVIDIR TRABAJO
-- ============================================================

local function divideJob(
    job,
    workerIDs
)

    if #workerIDs == 0 then

        return false,
            "SIN_WORKERS"

    end

    -- ========================================================
    -- CREAR BANDAS
    -- ========================================================

    local bands =
        createRowBands(
            job,
            #workerIDs
        )

    -- Copia para ir sacando workers.

    local remainingWorkers = {}

    for _, id
        in ipairs(workerIDs)
    do

        table.insert(
            remainingWorkers,
            id
        )

    end

    print("")
    print("==============================")
    print("      DISTRIBUCION AREA")
    print("==============================")

    -- ========================================================
    -- ENTREGAR CADA BANDA AL WORKER MÁS CERCANO
    -- ========================================================

    for _, band
        in ipairs(bands)
    do

        local id =
            takeNearestWorker(

                remainingWorkers,

                band.firstPosition

            )

        if not id then
            break
        end

        local assignment =
            buildAssignment(
                job,
                band
            )

        local worker =
            workers[id]

        worker.assignment =
            assignment

        worker.status =
            "ASSIGNED"

        worker.completed = 0

        worker.remainingBlocks =
            assignment.count

        worker.blocksThisBatch =
            0

        worker.batchRemaining =
            config.BATCH_BLOCK_LIMIT

        worker.batchLimit =
            config.BATCH_BLOCK_LIMIT

        worker.buildMode =
            job.buildMode

        send(
            id,
            assignment
        )

        print("")
        print(
            "Worker #"
            ..
            tostring(id)
        )

        print(
            "  Filas:",
            band.rowStart,
            "->",
            band.rowEnd
        )

        print(
            "  Z:",
            job.minZ
            +
            band.rowStart,
            "->",
            job.minZ
            +
            band.rowEnd
        )

        print(
            "  Indices:",
            band.startIndex,
            "->",
            band.endIndex
        )

        print(
            "  Bloques:",
            band.count
        )

    end

    return true

end

-- ============================================================
-- CREAR TRABAJO
-- ============================================================

local function createJob()

    local workerIDs =
        availableWorkerIDs()

    if #workerIDs == 0 then

        print("")
        print(
            "No hay workers disponibles."
        )

        sleep(2)

        return

    end

    print("")
    print("==============================")
    print("       NUEVO TRABAJO")
    print("==============================")

    local x1 =
        askNumber(
            "X esquina 1: "
        )

    local z1 =
        askNumber(
            "Z esquina 1: "
        )

    local x2 =
        askNumber(
            "X esquina 2: "
        )

    local z2 =
        askNumber(
            "Z esquina 2: "
        )

    local floorY =
        askNumber(
            "Y del suelo: "
        )

    local minX =
        math.min(
            x1,
            x2
        )

    local maxX =
        math.max(
            x1,
            x2
        )

    local minZ =
        math.min(
            z1,
            z2
        )

    local maxZ =
        math.max(
            z1,
            z2
        )

    local width =
        maxX
        -
        minX
        +
        1

    local depth =
        maxZ
        -
        minZ
        +
        1

    local mode =
        askBuildMode()

    local replaceFilter =
        askReplaceFilter(
            mode
        )

    -- ========================================================
    -- ESTACIONES
    -- ========================================================

    local materialStation =
        nil

    if
        mode
        ~=
        config.BUILD_MODES.CLEAR
    then

        materialStation =
            askRequiredPosition(
                "ESTACION MATERIALES"
            )

    end

    local fuelStation =
        askRequiredPosition(
            "ESTACION COMBUSTIBLE"
        )

    local unloadStation =
        nil

    if
        mode ==
        config.BUILD_MODES.REPLACE
        or
        mode ==
        config.BUILD_MODES.CLEAR
    then

        unloadStation =
            askRequiredPosition(
                "ESTACION DESCARGA"
            )

    end

    local job = {

        minX = minX,
        maxX = maxX,

        minZ = minZ,
        maxZ = maxZ,

        floorY =
            floorY,

        width =
            width,

        depth =
            depth,

        count =
            width
            *
            depth,

        buildMode =
            mode,

        replaceFilter =
            replaceFilter,

        materialStation =
            materialStation,

        fuelStation =
            fuelStation,

        unloadStation =
            unloadStation

    }

    -- ========================================================
    -- RESUMEN
    -- ========================================================

    print("")
    print("==============================")
    print("            RESUMEN")
    print("==============================")

    print(
        "X:",
        minX,
        "->",
        maxX
    )

    print(
        "Z:",
        minZ,
        "->",
        maxZ
    )

    print(
        "Y:",
        floorY
    )

    print(
        "Area:",
        width,
        "x",
        depth
    )

    print(
        "Bloques:",
        job.count
    )

    print(
        "Modo:",
        mode
    )

    local usableWorkers =
        math.min(
            #workerIDs,
            depth
        )

    print(
        "Workers disponibles:",
        #workerIDs
    )

    print(
        "Workers usados:",
        usableWorkers
    )

    if
        #workerIDs
        >
        depth
    then

        print("")
        print(
            "Nota:"
        )

        print(
            "Hay mas turtles que filas."
        )

        print(
            "Solo se usaran "
            ..
            usableWorkers
            ..
            "."
        )

    end

    print("")
    print(
        "¿Iniciar? (s/n)"
    )

    write("> ")

    if
        string.lower(
            read()
        )
        ~=
        "s"
    then

        return

    end

    local ok, err =
        divideJob(
            job,
            workerIDs
        )

    if not ok then

        print(
            "Error:",
            tostring(err)
        )

    end

end

-- ============================================================
-- BROADCAST
-- ============================================================

local function broadcastOnline(
    message
)

    for id, worker
        in pairs(workers)
    do

        if
            isWorkerOnline(
                worker
            )
        then

            send(
                id,
                message
            )

        end

    end

end

-- ============================================================
-- MOSTRAR WORKERS
-- ============================================================

local function showWorkers()

    term.clear()
    term.setCursorPos(
        1,
        1
    )

    print("==============================")
    print("       PAISACRAFT CENTRAL")
    print("==============================")

    print("")
    print(
        "Version:",
        config.VERSION
    )

    print(
        "Workers:",
        countWorkers()
    )

    print(
        "Disponibles:",
        #availableWorkerIDs()
    )

    print("")

    for _, id
        in ipairs(
            sortedWorkerIDs()
        )
    do

        local worker =
            workers[id]

        print(
            "#"
            ..
            tostring(id)
            ..
            " "
            ..
            tostring(
                worker.status
            )
        )

        print(
            "  Modo:",
            worker.buildMode
        )

        print(
            "  Hechos:",
            worker.completed
        )

        print(
            "  Restantes:",
            worker.remainingBlocks
        )

        print(
            "  Tanda:",
            worker.blocksThisBatch,
            "/",
            worker.batchLimit
        )

        print(
            "  Fuel:",
            worker.fuel,
            "/",
            worker.fuelTarget
        )

        if worker.position then

            print(
                "  Pos:",
                worker.position.x,
                worker.position.y,
                worker.position.z
            )

        end

        print("")

    end

    print("------------------------------")

    print(
        "Material:",
        materialOwner
        or
        "LIBRE"
    )

    print(
        "Fuel:",
        fuelOwner
        or
        "LIBRE"
    )

    print(
        "Descarga:",
        unloadOwner
        or
        "LIBRE"
    )

end

-- ============================================================
-- RED
-- ============================================================

local function networkLoop()

    while running do

        local id, msg =
            rednet.receive(
                config.PROTOCOL,
                1
            )

        if id then

            processMessage(
                id,
                msg
            )

        end

        cleanupTimeouts()

    end

end

-- ============================================================
-- MENU
-- ============================================================

local function menuLoop()

    while running do

        showWorkers()

        print("")
        print("1. Nuevo trabajo")
        print("2. Pausar todos")
        print("3. Reanudar todos")
        print("4. Regresar todos HOME")
        print("5. Actualizar")
        print("6. Salir")

        print("")
        write("> ")

        local option =
            read()

        if option == "1" then

            createJob()

        elseif option == "2" then

            broadcastOnline({

                type =
                    protocol.MESSAGE.PAUSE

            })

        elseif option == "3" then

            broadcastOnline({

                type =
                    protocol.MESSAGE.RESUME

            })

        elseif option == "4" then

            print("")
            print(
                "¿Regresar todas? (s/n)"
            )

            write("> ")

            if
                string.lower(
                    read()
                )
                ==
                "s"
            then

                broadcastOnline({

                    type =
                        protocol.MESSAGE.RETURN_HOME

                })

            end

        elseif option == "6" then

            running = false

        end

    end

end

-- ============================================================
-- MAIN
-- ============================================================

term.clear()
term.setCursorPos(
    1,
    1
)

print("==============================")
print("       PAISACRAFT CENTRAL")
print("==============================")

print("")
print(
    "Version:",
    config.VERSION
)

print(
    "ID:",
    os.getComputerID()
)

openModem()

hostNetwork()

print("")
print(
    "Esperando workers..."
)

parallel.waitForAny(

    networkLoop,

    menuLoop

)

pcall(
    rednet.unhost,
    config.PROTOCOL
)

print("")
print(
    "Central detenida."
)