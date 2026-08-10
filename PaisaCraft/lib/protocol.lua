-- ============================================================
-- PAISACRAFT
-- PROTOCOLO REDNET v6.1.5
-- ============================================================

local config =
    require("lib.config")

local protocol = {}

-- ============================================================
-- ESTADO
-- ============================================================

protocol.centralID =
    nil

protocol.modemSide =
    nil

-- ============================================================
-- MENSAJES
-- ============================================================

protocol.MESSAGE = {

    -- ========================================================
    -- CONEXION
    -- ========================================================

    HELLO =
        "HELLO",

    HEARTBEAT =
        "HEARTBEAT",

    -- ========================================================
    -- TRABAJO
    -- ========================================================

    ASSIGN =
        "ASSIGN",

    PROGRESS =
        "PROGRESS",

    COMPLETE =
        "COMPLETE",

    PARKED =
        "PARKED",

    -- ========================================================
    -- CONTROL
    -- ========================================================

    PAUSE =
        "PAUSE",

    RESUME =
        "RESUME",

    RETURN_HOME =
        "RETURN_HOME",

    -- ========================================================
    -- MATERIAL
    -- ========================================================

    MATERIAL_REQUEST =
        "MATERIAL_REQUEST",

    MATERIAL_GRANTED =
        "MATERIAL_GRANTED",

    MATERIAL_WAIT =
        "MATERIAL_WAIT",

    MATERIAL_DONE =
        "MATERIAL_DONE",

    -- ========================================================
    -- COMBUSTIBLE
    -- ========================================================

    FUEL_REQUEST =
        "FUEL_REQUEST",

    FUEL_GRANTED =
        "FUEL_GRANTED",

    FUEL_WAIT =
        "FUEL_WAIT",

    FUEL_DONE =
        "FUEL_DONE",

    -- ========================================================
    -- DESCARGA
    -- ========================================================

    UNLOAD_REQUEST =
        "UNLOAD_REQUEST",

    UNLOAD_GRANTED =
        "UNLOAD_GRANTED",

    UNLOAD_WAIT =
        "UNLOAD_WAIT",

    UNLOAD_DONE =
        "UNLOAD_DONE",

    -- ========================================================
    -- RESERVAS
    -- ========================================================

    CANCEL_RESERVATIONS =
        "CANCEL_RESERVATIONS",

    -- ========================================================
    -- MONITOR
    -- ========================================================

    MONITOR_HELLO =
        "MONITOR_HELLO",

    MONITOR_REQUEST =
        "MONITOR_REQUEST",

    MONITOR_STATE =
        "MONITOR_STATE"

}

-- ============================================================
-- ENCONTRAR MODEM
-- ============================================================

function protocol.findModem()

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
-- ABRIR REDNET
-- ============================================================

function protocol.open()

    -- ========================================================
    -- MODEM YA CONOCIDO
    -- ========================================================

    if protocol.modemSide then

        if
            peripheral.isPresent(
                protocol.modemSide
            )
            and
            peripheral.getType(
                protocol.modemSide
            )
            ==
            "modem"
        then

            if
                not rednet.isOpen(
                    protocol.modemSide
                )
            then

                rednet.open(
                    protocol.modemSide
                )

            end

            return true

        end

        -- El modem anterior ya no existe.

        protocol.modemSide =
            nil

    end

    -- ========================================================
    -- BUSCAR MODEM
    -- ========================================================

    protocol.modemSide =
        protocol.findModem()

    if not protocol.modemSide then

        return false,
            "MODEM_NO_ENCONTRADO"

    end

    -- ========================================================
    -- ABRIR
    -- ========================================================

    if
        not rednet.isOpen(
            protocol.modemSide
        )
    then

        rednet.open(
            protocol.modemSide
        )

    end

    return true

end

-- ============================================================
-- CERRAR REDNET
-- ============================================================

function protocol.close()

    if
        protocol.modemSide
        and
        rednet.isOpen(
            protocol.modemSide
        )
    then

        rednet.close(
            protocol.modemSide
        )

    end

end

-- ============================================================
-- BUSCAR CENTRAL
-- ============================================================

function protocol.findCentral()

    local modemOK =
        protocol.open()

    if not modemOK then

        protocol.centralID =
            nil

        return nil

    end

    protocol.centralID =
        rednet.lookup(

            config.PROTOCOL,

            config.CENTRAL_HOSTNAME

        )

    return
        protocol.centralID

end

-- ============================================================
-- ESTABLECER CENTRAL
-- ============================================================

function protocol.setCentral(
    id
)

    if
        type(id)
        ~= "number"
    then

        return false

    end

    protocol.centralID =
        id

    return true

end

-- ============================================================
-- LIMPIAR CENTRAL
-- ============================================================

function protocol.clearCentral()

    protocol.centralID =
        nil

end

-- ============================================================
-- ENVIAR A CENTRAL
-- ============================================================

function protocol.send(
    message
)

    if
        type(message)
        ~=
        "table"
    then

        return false,
            "MENSAJE_INVALIDO"

    end

    local modemOK,
        modemError =
        protocol.open()

    if not modemOK then

        return false,
            modemError

    end

    if not protocol.centralID then

        return false,
            "CENTRAL_NO_ENCONTRADA"

    end

    local ok =
        rednet.send(

            protocol.centralID,

            message,

            config.PROTOCOL

        )

    if not ok then

        return false,
            "ENVIO_FALLIDO"

    end

    return true

end

-- ============================================================
-- ENVIAR A ID ESPECIFICO
--
-- La Central puede utilizarlo para responder
-- directamente a una turtle o monitor.
-- ============================================================

function protocol.sendTo(
    id,
    message
)

    if
        type(id)
        ~= "number"
    then

        return false,
            "ID_INVALIDO"

    end

    if
        type(message)
        ~=
        "table"
    then

        return false,
            "MENSAJE_INVALIDO"

    end

    local modemOK,
        modemError =
        protocol.open()

    if not modemOK then

        return false,
            modemError

    end

    local ok =
        rednet.send(

            id,

            message,

            config.PROTOCOL

        )

    if not ok then

        return false,
            "ENVIO_FALLIDO"

    end

    return true

end

-- ============================================================
-- BROADCAST
-- ============================================================

function protocol.broadcast(
    message
)

    if
        type(message)
        ~=
        "table"
    then

        return false,
            "MENSAJE_INVALIDO"

    end

    local modemOK,
        modemError =
        protocol.open()

    if not modemOK then

        return false,
            modemError

    end

    rednet.broadcast(

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
-- CONECTAR A CENTRAL
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

        local central =
            protocol.findCentral()

        if central then

            protocol.centralID =
                central

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

function protocol.receive(
    timeout
)

    local modemOK =
        protocol.open()

    if not modemOK then

        return nil,
            nil

    end

    return rednet.receive(

        config.PROTOCOL,

        timeout

    )

end

-- ============================================================
-- RECIBIR SOLO DE CENTRAL
-- ============================================================

function protocol.receiveCentral(
    timeout
)

    if not protocol.centralID then

        return nil,
            nil

    end

    -- ========================================================
    -- CON TIMEOUT
    --
    -- Debemos respetar el tiempo total aunque lleguen
    -- mensajes de otros equipos.
    -- ========================================================

    if timeout ~= nil then

        local timer =
            os.startTimer(
                timeout
            )

        while true do

            local event,
                p1,
                p2,
                p3 =
                os.pullEvent()

            if
                event
                ==
                "timer"
                and
                p1
                ==
                timer
            then

                return nil,
                    nil

            end

            if
                event
                ==
                "rednet_message"
            then

                local senderID =
                    p1

                local message =
                    p2

                local messageProtocol =
                    p3

                if
                    messageProtocol
                    ==
                    config.PROTOCOL

                    and

                    senderID
                    ==
                    protocol.centralID
                then

                    return
                        senderID,
                        message

                end

            end

        end

    end

    -- ========================================================
    -- SIN TIMEOUT
    -- ========================================================

    while true do

        local id,
            msg =
            protocol.receive()

        if
            id
            ==
            protocol.centralID
        then

            return
                id,
                msg

        end

    end

end

-- ============================================================
-- ESPERAR MENSAJE DE UN TIPO
-- ============================================================

function protocol.wait(
    typeName,
    timeout
)

    if
        type(typeName)
        ~=
        "string"
    then

        return nil,
            "TIPO_INVALIDO"

    end

    -- ========================================================
    -- SIN TIMEOUT
    -- ========================================================

    if timeout == nil then

        while true do

            local id,
                msg =
                protocol.receiveCentral()

            if
                id
                and
                type(msg)
                ==
                "table"
                and
                msg.type
                ==
                typeName
            then

                return msg

            end

        end

    end

    -- ========================================================
    -- CON TIMEOUT
    -- ========================================================

    local started =
        os.clock()

    while true do

        local elapsed =
            os.clock()
            -
            started

        local remaining =
            timeout
            -
            elapsed

        if remaining <= 0 then

            return nil,
                "TIMEOUT"

        end

        local id,
            msg =
            protocol.receiveCentral(
                remaining
            )

        if not id then

            return nil,
                "TIMEOUT"

        end

        if
            type(msg)
            ==
            "table"
            and
            msg.type
            ==
            typeName
        then

            return msg

        end

    end

end

-- ============================================================
-- COMPROBAR TIPO DE MENSAJE
-- ============================================================

function protocol.isMessage(
    message,
    typeName
)

    return
        type(message)
        ==
        "table"
        and
        message.type
        ==
        typeName

end

-- ============================================================
-- ESTADO
-- ============================================================

function protocol.getStats()

    return {

        modemSide =
            protocol.modemSide,

        modemOpen =
            protocol.modemSide
            ~= nil
            and
            rednet.isOpen(
                protocol.modemSide
            ),

        centralID =
            protocol.centralID,

        connected =
            protocol.centralID
            ~=
            nil,

        protocol =
            config.PROTOCOL

    }

end

return protocol
