-- ============================================================
-- PAISACRAFT
-- PROTOCOLO REDNET v6.1.3
-- ============================================================

local config =
    require("lib.config")

local protocol = {}

-- ============================================================
-- ESTADO
-- ============================================================

protocol.centralID = nil
protocol.modemSide = nil

-- ============================================================
-- MENSAJES
-- ============================================================

protocol.MESSAGE = {

    -- =========================
    -- CONEXIÓN
    -- =========================

    HELLO = "HELLO",

    HEARTBEAT = "HEARTBEAT",

    -- =========================
    -- TRABAJO
    -- =========================

    ASSIGN = "ASSIGN",

    PROGRESS = "PROGRESS",

    COMPLETE = "COMPLETE",

    PARKED = "PARKED",

    -- =========================
    -- CONTROL
    -- =========================

    PAUSE = "PAUSE",

    RESUME = "RESUME",

    RETURN_HOME = "RETURN_HOME",

    -- =========================
    -- MATERIAL
    -- =========================

    MATERIAL_REQUEST =
        "MATERIAL_REQUEST",

    MATERIAL_GRANTED =
        "MATERIAL_GRANTED",

    MATERIAL_WAIT =
        "MATERIAL_WAIT",

    MATERIAL_DONE =
        "MATERIAL_DONE",

    -- =========================
    -- FUEL
    -- =========================

    FUEL_REQUEST =
        "FUEL_REQUEST",

    FUEL_GRANTED =
        "FUEL_GRANTED",

    FUEL_WAIT =
        "FUEL_WAIT",

    FUEL_DONE =
        "FUEL_DONE",

    -- =========================
    -- DESCARGA
    -- =========================

    UNLOAD_REQUEST =
        "UNLOAD_REQUEST",

    UNLOAD_GRANTED =
        "UNLOAD_GRANTED",

    UNLOAD_WAIT =
        "UNLOAD_WAIT",

    UNLOAD_DONE =
        "UNLOAD_DONE",

    -- =========================
    -- RESERVAS
    -- =========================

    CANCEL_RESERVATIONS =
        "CANCEL_RESERVATIONS",

    -- =========================
    -- MONITOR
    -- =========================

    MONITOR_HELLO =
        "MONITOR_HELLO",

    MONITOR_REQUEST =
        "MONITOR_REQUEST",

    MONITOR_STATE =
        "MONITOR_STATE"

}

-- ============================================================
-- ENCONTRAR MÓDEM
-- ============================================================

function protocol.findModem()

    for _, name
        in ipairs(
            peripheral.getNames()
        )
    do

        if
            peripheral.getType(name)
            == "modem"
        then

            return name

        end

    end

    return nil

end

-- ============================================================
-- ABRIR REDNET
-- ============================================================

function protocol.open()

    if
        protocol.modemSide
        and
        rednet.isOpen(
            protocol.modemSide
        )
    then

        return true

    end

    protocol.modemSide =
        protocol.findModem()

    if not protocol.modemSide then

        return false,
            "MODEM_NO_ENCONTRADO"

    end

    rednet.open(
        protocol.modemSide
    )

    return true

end

-- ============================================================
-- BUSCAR CENTRAL
-- ============================================================

function protocol.findCentral()

    protocol.centralID =
        rednet.lookup(

            config.PROTOCOL,

            config.CENTRAL_HOSTNAME

        )

    return protocol.centralID

end

-- ============================================================
-- ENVIAR
-- ============================================================

function protocol.send(message)

    if not protocol.centralID then
        return false
    end

    rednet.send(

        protocol.centralID,

        message,

        config.PROTOCOL

    )

    return true

end

-- ============================================================
-- HELLO
-- ============================================================

function protocol.sendHello()

    return protocol.send({

        type =
            protocol.MESSAGE.HELLO,

        id =
            os.getComputerID(),

        version =
            config.VERSION

    })

end

-- ============================================================
-- HEARTBEAT
-- ============================================================

function protocol.sendHeartbeat(
    status
)

    return protocol.send({

        type =
            protocol.MESSAGE.HEARTBEAT,

        id =
            os.getComputerID(),

        status =
            status,

        version =
            config.VERSION

    })

end

-- ============================================================
-- CONECTAR
-- ============================================================

function protocol.connect()

    local modemOK,
        modemError =
        protocol.open()

    if not modemOK then

        return false,
            modemError

    end

    print("")
    print(
        "Buscando central..."
    )

    while true do

        protocol.findCentral()

        if protocol.centralID then

            protocol.sendHello()

            print(
                "Central:",
                protocol.centralID
            )

            return true

        end

        sleep(2)

    end

end

-- ============================================================
-- RECIBIR
-- ============================================================

function protocol.receive(timeout)

    return rednet.receive(

        config.PROTOCOL,

        timeout

    )

end

-- ============================================================
-- RECIBIR SOLO CENTRAL
-- ============================================================

function protocol.receiveCentral(
    timeout
)

    while true do

        local id, msg =
            protocol.receive(
                timeout
            )

        if not id then

            return nil,
                nil

        end

        if
            id ==
            protocol.centralID
        then

            return id,
                msg

        end

    end

end

-- ============================================================
-- ESPERAR TIPO
-- ============================================================

function protocol.wait(
    typeName
)

    while true do

        local id, msg =
            protocol.receiveCentral()

        if
            id
            and
            type(msg) == "table"
            and
            msg.type == typeName
        then

            return msg

        end

    end

end

return protocol