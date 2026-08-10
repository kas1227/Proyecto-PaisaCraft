-- ============================================================
-- PAISACRAFT
-- MONITOR DE CONTROL v6.1.4
-- ============================================================

local config =
    require("lib.config")

local protocol =
    require("lib.protocol")

-- ============================================================
-- CONFIGURACIÓN
-- ============================================================

local REFRESH_INTERVAL = 2

local monitor = nil
local modem = nil

local centralID = nil

local workers = {}

local lastUpdate = 0

-- ============================================================
-- COLORES
-- ============================================================

local COLOR_BACKGROUND =
    colors.black

local COLOR_PRIMARY =
    colors.lime

local COLOR_SECONDARY =
    colors.green

local COLOR_WARNING =
    colors.yellow

local COLOR_DANGER =
    colors.red

local COLOR_TEXT =
    colors.white

local COLOR_MUTED =
    colors.gray

-- ============================================================
-- UTILIDADES
-- ============================================================

local function clear(
    background
)

    monitor.setBackgroundColor(
        background
        or
        COLOR_BACKGROUND
    )

    monitor.clear()

    monitor.setCursorPos(
        1,
        1
    )

end

-- ============================================================
-- ESCRIBIR
-- ============================================================

local function writeAt(
    x,
    y,
    text,
    color
)

    monitor.setCursorPos(
        x,
        y
    )

    monitor.setTextColor(
        color
        or
        COLOR_TEXT
    )

    monitor.write(
        tostring(text)
    )

end

-- ============================================================
-- TEXTO CENTRADO
-- ============================================================

local function centerText(
    y,
    text,
    color
)

    local width =
        monitor.getSize()

    text =
        tostring(text)

    local x =
        math.floor(
            (
                width
                -
                #text
            )
            /
            2
        )
        +
        1

    if x < 1 then
        x = 1
    end

    writeAt(
        x,
        y,
        text,
        color
    )

end

-- ============================================================
-- LIMITAR TEXTO
-- ============================================================

local function truncate(
    value,
    maximum
)

    local text =
        tostring(value)

    if #text <= maximum then
        return text
    end

    if maximum <= 3 then

        return
            string.sub(
                text,
                1,
                maximum
            )

    end

    return
        string.sub(
            text,
            1,
            maximum - 3
        )
        ..
        "..."

end

-- ============================================================
-- PORCENTAJE
-- ============================================================

local function percent(
    value,
    maximum
)

    value =
        tonumber(value)
        or
        0

    maximum =
        tonumber(maximum)
        or
        0

    if maximum <= 0 then
        return 0
    end

    local result =
        math.floor(
            (
                value
                /
                maximum
            )
            *
            100
            +
            0.5
        )

    if result < 0 then
        result = 0
    end

    if result > 100 then
        result = 100
    end

    return result

end

-- ============================================================
-- BARRA
-- ============================================================

local function drawBar(
    x,
    y,
    width,
    percentage,
    foreground,
    background
)

    percentage =
        math.max(
            0,
            math.min(
                100,
                percentage
            )
        )

    local filled =
        math.floor(
            width
            *
            percentage
            /
            100
        )

    monitor.setCursorPos(
        x,
        y
    )

    monitor.setBackgroundColor(
        background
        or
        colors.gray
    )

    monitor.write(
        string.rep(
            " ",
            width
        )
    )

    if filled > 0 then

        monitor.setCursorPos(
            x,
            y
        )

        monitor.setBackgroundColor(
            foreground
            or
            COLOR_PRIMARY
        )

        monitor.write(
            string.rep(
                " ",
                filled
            )
        )

    end

    monitor.setBackgroundColor(
        COLOR_BACKGROUND
    )

end

-- ============================================================
-- ESTADO EN ESPAÑOL
-- ============================================================

local function translateStatus(
    status
)

    local names = {

        CONNECTED =
            "CONECTADA",

        IDLE =
            "ESPERANDO",

        ASSIGNED =
            "ASIGNADA",

        BUILDING =
            "CONSTRUYENDO",

        MOVING =
            "MOVIENDO",

        RESTOCK =
            "ABASTECIENDO",

        LOW_FUEL =
            "REPOSTANDO",

        PAUSED =
            "PAUSADA",

        RETURNING_HOME =
            "REGRESANDO",

        COMPLETE =
            "COMPLETADO",

        PARKED =
            "EN BASE",

        RECOVERY =
            "RECUPERANDO",

        OFFLINE =
            "DESCONECTADA"

    }

    return
        names[status]
        or
        tostring(
            status
            or
            "DESCONOCIDO"
        )

end

-- ============================================================
-- MODO
-- ============================================================

local function translateMode(
    mode
)

    if mode == "PLACE" then
        return "COLOCAR"
    end

    if mode == "REPLACE" then
        return "REEMPLAZAR"
    end

    if mode == "CLEAR" then
        return "LIMPIAR"
    end

    return
        tostring(
            mode
            or
            "-"
        )

end

-- ============================================================
-- COLOR DE ESTADO
-- ============================================================

local function statusColor(
    status
)

    if
        status == "OFFLINE"
    then

        return
            COLOR_DANGER

    end

    if
        status == "LOW_FUEL"
        or
        status == "RECOVERY"
    then

        return
            COLOR_WARNING

    end

    if
        status == "PAUSED"
    then

        return
            COLOR_WARNING

    end

    return
        COLOR_PRIMARY

end

-- ============================================================
-- BUSCAR MONITOR
-- ============================================================

local function findMonitor()

    for _, name
        in ipairs(
            peripheral.getNames()
        )
    do

        if
            peripheral.getType(name)
            ==
            "monitor"
        then

            return
                peripheral.wrap(
                    name
                )

        end

    end

    return nil

end

-- ============================================================
-- BUSCAR MÓDEM
-- ============================================================

local function findModem()

    for _, name
        in ipairs(
            peripheral.getNames()
        )
    do

        if
            peripheral.getType(name)
            ==
            "modem"
        then

            return name

        end

    end

    return nil

end

-- ============================================================
-- ABRIR RED
-- ============================================================

local function openNetwork()

    modem =
        findModem()

    if not modem then

        error(
            "No encuentro modem."
        )

    end

    if
        not rednet.isOpen(
            modem
        )
    then

        rednet.open(
            modem
        )

    end

end

-- ============================================================
-- BUSCAR CENTRAL
-- ============================================================

local function findCentral()

    centralID =
        rednet.lookup(

            config.PROTOCOL,

            config.CENTRAL_HOSTNAME

        )

    return centralID

end

-- ============================================================
-- SOLICITAR ESTADO
-- ============================================================

local function requestState()

    if not centralID then

        if not findCentral() then
            return false
        end

    end

    rednet.send(

        centralID,

        {
            type =
                protocol.MESSAGE.MONITOR_REQUEST,

            id =
                os.getComputerID()
        },

        config.PROTOCOL

    )

    return true

end

-- ============================================================
-- ORDENAR WORKERS
-- ============================================================

local function sortedWorkerIDs()

    local result = {}

    for id in pairs(workers) do

        table.insert(
            result,
            id
        )

    end

    table.sort(result)

    return result

end

-- ============================================================
-- CABECERA
-- ============================================================

local function drawHeader()

    local width =
        monitor.getSize()

    monitor.setBackgroundColor(
        COLOR_SECONDARY
    )

    monitor.setTextColor(
        COLOR_BACKGROUND
    )

    monitor.setCursorPos(
        1,
        1
    )

    monitor.write(
        string.rep(
            " ",
            width
        )
    )

    centerText(
        1,
        "PAISACRAFT CONTROL SYSTEM",
        COLOR_BACKGROUND
    )

    monitor.setBackgroundColor(
        COLOR_BACKGROUND
    )

    centerText(
        2,
        "SISTEMA DE CONSTRUCCION AUTONOMA",
        COLOR_SECONDARY
    )

end

-- ============================================================
-- SIN CENTRAL
-- ============================================================

local function drawNoCentral()

    clear()

    drawHeader()

    local width, height =
        monitor.getSize()

    centerText(
        math.floor(
            height / 2
        ),
        "BUSCANDO CENTRAL...",
        COLOR_WARNING
    )

    centerText(
        math.floor(
            height / 2
        )
        +
        2,
        config.CENTRAL_HOSTNAME,
        COLOR_MUTED
    )

end

-- ============================================================
-- SIN WORKERS
-- ============================================================

local function drawNoWorkers()

    local _, height =
        monitor.getSize()

    centerText(
        math.floor(
            height / 2
        ),
        "NINGUNA TURTLE REGISTRADA",
        COLOR_WARNING
    )

end

-- ============================================================
-- WORKER COMPACTO
-- ============================================================

local function drawWorkerCompact(
    worker,
    x,
    y,
    width
)

    local status =
        translateStatus(
            worker.status
        )

    local color =
        statusColor(
            worker.status
        )

    -- ========================================================
    -- CABECERA
    -- ========================================================

    writeAt(
        x,
        y,
        "#"
        ..
        tostring(
            worker.id
        ),
        COLOR_PRIMARY
    )

    local statusText =
        truncate(
            status,
            math.max(
                1,
                width - 8
            )
        )

    writeAt(
        x + 7,
        y,
        statusText,
        color
    )

    -- ========================================================
    -- MODO
    -- ========================================================

    writeAt(
        x,
        y + 1,
        "MODO:",
        COLOR_MUTED
    )

    writeAt(
        x + 6,
        y + 1,
        translateMode(
            worker.buildMode
        ),
        COLOR_TEXT
    )

    -- ========================================================
    -- PROGRESO
    -- ========================================================

    local completed =
        tonumber(
            worker.completed
        )
        or
        0

    local remaining =
        tonumber(
            worker.remainingBlocks
        )
        or
        0

    local total =
        completed
        +
        remaining

    local progress =
        percent(
            completed,
            total
        )

    writeAt(
        x,
        y + 2,
        "PROG:",
        COLOR_MUTED
    )

    writeAt(
        x + 6,
        y + 2,
        completed
        ..
        "/"
        ..
        total
        ..
        " "
        ..
        progress
        ..
        "%",
        COLOR_TEXT
    )

    if width >= 14 then

        drawBar(

            x,
            y + 3,

            width,

            progress,

            COLOR_PRIMARY,

            colors.gray

        )

    end

    -- ========================================================
    -- FUEL
    -- ========================================================

    local currentFuel =
        tonumber(
            worker.fuel
        )
        or
        0

    local targetFuel =
        tonumber(
            worker.fuelTarget
        )
        or
        0

    local fuelPercent =
        percent(
            currentFuel,
            targetFuel
        )

    writeAt(
        x,
        y + 4,
        "FUEL:",
        COLOR_MUTED
    )

    local fuelColor =
        COLOR_PRIMARY

    if fuelPercent <= 25 then

        fuelColor =
            COLOR_DANGER

    elseif fuelPercent <= 50 then

        fuelColor =
            COLOR_WARNING

    end

    writeAt(
        x + 6,
        y + 4,

        currentFuel
        ..
        "/"
        ..
        targetFuel,

        fuelColor

    )

    -- ========================================================
    -- POSICIÓN
    -- ========================================================

    if worker.position then

        writeAt(
            x,
            y + 5,
            "XYZ:",
            COLOR_MUTED
        )

        local position =
            tostring(
                worker.position.x
            )
            ..
            ","
            ..
            tostring(
                worker.position.y
            )
            ..
            ","
            ..
            tostring(
                worker.position.z
            )

        writeAt(
            x + 5,
            y + 5,

            truncate(
                position,
                width - 5
            ),

            COLOR_TEXT

        )

    end

end

-- ============================================================
-- PANEL GENERAL
-- ============================================================

local function drawDashboard()

    clear()

    drawHeader()

    local width, height =
        monitor.getSize()

    local ids =
        sortedWorkerIDs()

    -- ========================================================
    -- RESUMEN
    -- ========================================================

    writeAt(
        1,
        4,
        "CENTRAL:",
        COLOR_MUTED
    )

    writeAt(
        10,
        4,
        centralID
        or
        "-",
        COLOR_PRIMARY
    )

    writeAt(
        1,
        5,
        "TURTLES:",
        COLOR_MUTED
    )

    writeAt(
        10,
        5,
        #ids,
        COLOR_TEXT
    )

    if #ids == 0 then

        drawNoWorkers()

        return

    end

    -- ========================================================
    -- RESPONSIVE
    -- ========================================================

    local startY = 7

    local workerHeight = 7

    -- Monitor ancho:
    -- dos columnas.

    if width >= 42 then

        local columnWidth =
            math.floor(
                (
                    width - 3
                )
                /
                2
            )

        local perColumn =
            math.floor(
                (
                    height
                    -
                    startY
                    +
                    1
                )
                /
                workerHeight
            )

        if perColumn < 1 then
            perColumn = 1
        end

        local maximum =
            perColumn
            *
            2

        for index =
            1,
            math.min(
                #ids,
                maximum
            )
        do

            local column =
                math.floor(
                    (
                        index - 1
                    )
                    /
                    perColumn
                )

            local row =
                (
                    index - 1
                )
                %
                perColumn

            local x =
                1
                +
                column
                *
                (
                    columnWidth
                    +
                    2
                )

            local y =
                startY
                +
                row
                *
                workerHeight

            local worker =
                workers[
                    ids[index]
                ]

            drawWorkerCompact(

                worker,

                x,
                y,

                columnWidth

            )

        end

    else

        -- ====================================================
        -- MONITOR ESTRECHO
        -- ====================================================

        local maximum =
            math.floor(
                (
                    height
                    -
                    startY
                    +
                    1
                )
                /
                workerHeight
            )

        for index =
            1,
            math.min(
                #ids,
                maximum
            )
        do

            local worker =
                workers[
                    ids[index]
                ]

            drawWorkerCompact(

                worker,

                1,

                startY
                +
                (
                    index - 1
                )
                *
                workerHeight,

                width

            )

        end

    end

end

-- ============================================================
-- PROCESAR SNAPSHOT
-- ============================================================

local function processState(
    message
)

    if
        type(message)
        ~=
        "table"
    then

        return

    end

    if
        type(message.workers)
        ==
        "table"
    then

        workers =
            message.workers

    end

    lastUpdate =
        os.epoch("utc")

end

-- ============================================================
-- LOOP RED
-- ============================================================

local function networkLoop()

    while true do

        local id, message =
            rednet.receive(
                config.PROTOCOL,
                2
            )

        if
            id
            and
            centralID
            and
            id == centralID
            and
            type(message)
            ==
            "table"
        then

            if
                message.type
                ==
                protocol.MESSAGE.MONITOR_STATE
            then

                processState(
                    message
                )

            end

        end

    end

end

-- ============================================================
-- LOOP PETICIONES
-- ============================================================

local function requestLoop()

    while true do

        if not findCentral() then

            centralID = nil

        else

            requestState()

        end

        sleep(
            REFRESH_INTERVAL
        )

    end

end

-- ============================================================
-- LOOP UI
-- ============================================================

local function displayLoop()

    while true do

        if centralID then

            drawDashboard()

        else

            drawNoCentral()

        end

        sleep(
            REFRESH_INTERVAL
        )

    end

end

-- ============================================================
-- MAIN
-- ============================================================

monitor =
    findMonitor()

if not monitor then

    error(
        "No encuentro monitor conectado."
    )

end

-- ============================================================
-- ESCALA
-- ============================================================

monitor.setTextScale(
    0.5
)

monitor.setBackgroundColor(
    COLOR_BACKGROUND
)

monitor.setTextColor(
    COLOR_PRIMARY
)

-- ============================================================
-- RED
-- ============================================================

openNetwork()

-- ============================================================
-- ARRANQUE
-- ============================================================

clear()

centerText(
    2,
    "PAISACRAFT",
    COLOR_PRIMARY
)

centerText(
    4,
    "INICIANDO CONTROL SYSTEM...",
    COLOR_SECONDARY
)

sleep(1)

-- ============================================================
-- LOOPS
-- ============================================================

parallel.waitForAll(

    networkLoop,

    requestLoop,

    displayLoop

)