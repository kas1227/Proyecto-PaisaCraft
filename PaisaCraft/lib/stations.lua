-- ============================================================
-- PAISACRAFT
-- ESTACIONES v6.1.3
-- ============================================================

local config =
    require("lib.config")

local protocol =
    require("lib.protocol")

local state =
    require("lib.state")

local navigation =
    require("lib.navigation")

local inventory =
    require("lib.inventory")

local movement =
    require("lib.movement")

local fuel =
    require("lib.fuel")

local stations = {}

-- ============================================================
-- CALLBACK CONTROL
-- ============================================================

local controlCallback = nil


function stations.setControlCallback(
    callback
)

    controlCallback =
        callback

end


local function checkControl(msg)

    if controlCallback then

        return controlCallback(
            msg
        )

    end

    return true

end

-- ============================================================
-- MODO
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


local function needsMaterials()

    return
        getBuildMode()
        ~=
        config.BUILD_MODES.CLEAR

end

-- ============================================================
-- CANCELAR TODAS LAS RESERVAS
-- ============================================================

function stations.cancelReservations()

    protocol.send({

        type =
            protocol.MESSAGE.CANCEL_RESERVATIONS

    })

end

-- ============================================================
-- PERMISO GENÉRICO
-- ============================================================

local function waitForPermission(
    requestType,
    grantedType,
    waitType
)

    while true do

        protocol.send({

            type =
                requestType

        })

        local id, msg =
            protocol.receiveCentral(
                3
            )

        if
            id
            and
            type(msg) == "table"
        then

            if msg.type == grantedType then

                return true

            elseif msg.type == waitType then

                print(
                    "Cola:",
                    msg.position
                    or
                    "?"
                )

            else

                checkControl(
                    msg
                )

            end

        end

        if state.returnRequested then

            stations.cancelReservations()

            return false,
                "RETURN_REQUESTED"

        end

    end

end

-- ============================================================
-- MATERIAL
-- ============================================================

function stations.requestMaterial()

    return waitForPermission(

        protocol.MESSAGE.MATERIAL_REQUEST,

        protocol.MESSAGE.MATERIAL_GRANTED,

        protocol.MESSAGE.MATERIAL_WAIT

    )

end

-- ============================================================
-- FUEL
-- ============================================================

function stations.requestFuel()

    return waitForPermission(

        protocol.MESSAGE.FUEL_REQUEST,

        protocol.MESSAGE.FUEL_GRANTED,

        protocol.MESSAGE.FUEL_WAIT

    )

end

-- ============================================================
-- DESCARGA
-- ============================================================

function stations.requestUnload()

    return waitForPermission(

        protocol.MESSAGE.UNLOAD_REQUEST,

        protocol.MESSAGE.UNLOAD_GRANTED,

        protocol.MESSAGE.UNLOAD_WAIT

    )

end

-- ============================================================
-- IR A ESTACIÓN
-- ============================================================

local function goToStation(
    position
)

    if not position then

        return false,
            "ESTACION_NO_CONFIGURADA"

    end

    return navigation.goToPosition(

        position,

        {
            onControl =
                function()

                    return checkControl()

                end
        }

    )

end

-- ============================================================
-- SALIR
-- ============================================================

function stations.leaveStation()

    while true do

        local ok, reason =
            movement.forward()

        if ok then
            return true
        end

        if
            reason
            ~=
            "BLOQUEADO"
        then

            return false,
                reason

        end

        print(
            "Salida de estación bloqueada..."
        )

        sleep(0.25)

        if not checkControl() then

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            return false,
                "RETURN_REQUESTED"

        end

    end

end

-- ============================================================
-- LIBERAR DESCARGA
-- ============================================================

local function finishUnload()

    protocol.send({

        type =
            protocol.MESSAGE.UNLOAD_DONE

    })

end

-- ============================================================
-- DESCARGA SIMPLE
-- ============================================================

function stations.unloadOnly(
    returnAfter
)

    if not config.AUTO_UNLOAD then
        return true
    end

    if inventory.isReservedEmpty() then
        return true
    end

    if not state.assignment then

        return false,
            "SIN_ASIGNACION"

    end

    local station =
        state.assignment.unloadStation

    if not station then

        return false,
            "UNLOAD_STATION_NO_CONFIGURADA"

    end

    local returnPosition = nil
    local returnDirection = nil

    if returnAfter then

        returnPosition =
            state.getPosition()

        returnDirection =
            state.getDirection()

    end

    print("")
    print("==============================")
    print("           DESCARGA")
    print("==============================")

    -- ========================================================
    -- SOLICITAR TURNO
    -- ========================================================

    local permissionOK,
        permissionError =
        stations.requestUnload()

    if not permissionOK then

        return false,
            permissionError

    end

    -- ========================================================
    -- IR
    -- ========================================================

    local navigationOK,
        navigationError =
        goToStation(
            station
        )

    if not navigationOK then

        finishUnload()

        return false,
            navigationError

    end

    -- ========================================================
    -- RECONFIRMAR RESERVA
    -- ========================================================

    local confirmOK,
        confirmError =
        stations.requestUnload()

    if not confirmOK then

        finishUnload()

        return false,
            confirmError

    end

    -- ========================================================
    -- VACIAR SLOT 16
    -- ========================================================

    while
        not inventory.isReservedEmpty()
    do

        inventory.selectReservedSlot()

        if not turtle.dropUp() then

            print(
                "Esperando espacio de descarga..."
            )

            sleep(
                config.STOCK_WAIT
            )

        end

        if not checkControl() then

            finishUnload()

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            finishUnload()

            return false,
                "RETURN_REQUESTED"

        end

    end

    print(
        "Descarga completada."
    )

    -- ========================================================
    -- SALIR
    -- ========================================================

    local leaveOK,
        leaveError =
        stations.leaveStation()

    -- Liberamos cuando la turtle ya ha intentado
    -- abandonar físicamente el punto.

    finishUnload()

    if not leaveOK then

        return false,
            leaveError

    end

    -- ========================================================
    -- REGRESAR
    -- ========================================================

    if
        returnAfter
        and
        returnPosition
    then

        print("")
        print(
            "Regresando al trabajo..."
        )

        local returnOK,
            returnError =
            navigation.goToPosition(

                returnPosition,

                {
                    onControl =
                        function()

                            return checkControl()

                        end
                }

            )

        if not returnOK then

            return false,
                returnError

        end

        if returnDirection ~= nil then

            movement.turnTo(
                returnDirection
            )

        end

    end

    return true

end

-- ============================================================
-- REPOSTAR DESDE COFRE
-- ============================================================

function stations.refuelFromChest(
    targetFuel
)

    targetFuel =
        targetFuel
        or
        config.TARGET_FUEL

    inventory.consumeFuelFromInventory(
        targetFuel
    )

    while true do

        local current =
            movement.getFuelLevel()

        if
            current == math.huge
            or
            current >= targetFuel
        then

            return true

        end

        local ok, reason =
            inventory.collectFuelUp(
                16
            )

        if ok then

            inventory.consumeFuelFromInventory(
                targetFuel
            )

        else

            if
                reason ==
                "INVENTARIO_LLENO"
            then

                return
                    movement.getFuelLevel()
                    >=
                    config.MIN_FUEL

            end

            print(
                "Esperando combustible..."
            )

            sleep(
                config.STOCK_WAIT
            )

        end

        if not checkControl() then
            return false
        end

        if state.returnRequested then
            return false
        end

    end

end

-- ============================================================
-- LIBERAR FUEL
-- ============================================================

local function finishFuel()

    protocol.send({

        type =
            protocol.MESSAGE.FUEL_DONE

    })

end

-- ============================================================
-- FUEL
-- ============================================================

function stations.refuel(
    targetFuel
)

    if not state.assignment then

        return false,
            "SIN_ASIGNACION"

    end

    local station =
        state.assignment.fuelStation

    if not station then

        return false,
            "FUEL_STATION_NO_CONFIGURADA"

    end

    targetFuel =
        targetFuel
        or
        config.TARGET_FUEL

    print("")
    print("==============================")
    print("        COMBUSTIBLE")
    print("==============================")

    local permissionOK,
        permissionError =
        stations.requestFuel()

    if not permissionOK then

        return false,
            permissionError

    end

    local navigationOK,
        navigationError =
        goToStation(
            station
        )

    if not navigationOK then

        finishFuel()

        return false,
            navigationError

    end

    -- Reconfirmar.

    local confirmOK,
        confirmError =
        stations.requestFuel()

    if not confirmOK then

        finishFuel()

        return false,
            confirmError

    end

    print(
        "Objetivo:",
        targetFuel
    )

    print(
        "Actual:",
        movement.getFuelLevel()
    )

    local fuelOK =
        stations.refuelFromChest(
            targetFuel
        )

    if not fuelOK then

        finishFuel()

        return false,
            "SIN_FUEL"

    end

    print(
        "Fuel final:",
        movement.getFuelLevel()
    )

    local leaveOK,
        leaveError =
        stations.leaveStation()

    finishFuel()

    if not leaveOK then

        return false,
            leaveError

    end

    return true

end

-- ============================================================
-- LIBERAR MATERIAL
-- ============================================================

local function finishMaterial()

    protocol.send({

        type =
            protocol.MESSAGE.MATERIAL_DONE

    })

end

-- ============================================================
-- MATERIALES
-- ============================================================

function stations.collectMaterials()

    if not needsMaterials() then
        return true
    end

    if not state.assignment then

        return false,
            "SIN_ASIGNACION"

    end

    local station =
        state.assignment.materialStation

    if not station then

        return false,
            "MATERIAL_STATION_NO_CONFIGURADA"

    end

    print("")
    print("==============================")
    print("         MATERIALES")
    print("==============================")

    local permissionOK,
        permissionError =
        stations.requestMaterial()

    if not permissionOK then

        return false,
            permissionError

    end

    local navigationOK,
        navigationError =
        goToStation(
            station
        )

    if not navigationOK then

        finishMaterial()

        return false,
            navigationError

    end

    -- Reconfirmar.

    local confirmOK,
        confirmError =
        stations.requestMaterial()

    if not confirmOK then

        finishMaterial()

        return false,
            confirmError

    end

    inventory.collectBuildMaterialsUp()

    while
        not inventory.hasBuildMaterial()
    do

        print(
            "Esperando materiales..."
        )

        sleep(
            config.STOCK_WAIT
        )

        inventory.collectBuildMaterialsUp()

        if not checkControl() then

            finishMaterial()

            return false,
                "INTERRUPTED"

        end

        if state.returnRequested then

            finishMaterial()

            return false,
                "RETURN_REQUESTED"

        end

    end

    print(
        "Materiales:",
        inventory.countBuildMaterials()
    )

    local leaveOK,
        leaveError =
        stations.leaveStation()

    finishMaterial()

    if not leaveOK then

        return false,
            leaveError

    end

    state.clearBuildingSlot()

    return true

end

-- ============================================================
-- RESTOCK COMPLETO
-- ============================================================

function stations.fullRestock(
    returnAfter
)

    if not state.assignment then

        return false,
            "SIN_ASIGNACION"

    end

    local returnPosition = nil
    local returnDirection = nil

    if returnAfter then

        returnPosition =
            state.getPosition()

        returnDirection =
            state.getDirection()

    end

    -- ========================================================
    -- 1. DESCARGA
    -- ========================================================

    if
        not inventory.isReservedEmpty()
    then

        local ok, err =
            stations.unloadOnly(
                false
            )

        if not ok then
            return false, err
        end

    end

    if state.returnRequested then

        stations.cancelReservations()

        return false,
            "RETURN_REQUESTED"

    end

    -- ========================================================
    -- 2. FUEL OBJETIVO
    -- ========================================================

    local targetFuel =
        fuel.calculateTarget(
            returnPosition
        )

    print("")
    print(
        "Fuel calculado:",
        targetFuel
    )

    -- ========================================================
    -- 3. FUEL
    -- ========================================================

    local fuelOK,
        fuelError =
        stations.refuel(
            targetFuel
        )

    if not fuelOK then

        stations.cancelReservations()

        return false,
            fuelError

    end

    if state.returnRequested then

        stations.cancelReservations()

        return false,
            "RETURN_REQUESTED"

    end

    -- ========================================================
    -- 4. MATERIAL
    -- ========================================================

    if needsMaterials() then

        local materialOK,
            materialError =
            stations.collectMaterials()

        if not materialOK then

            stations.cancelReservations()

            return false,
                materialError

        end

    end

    -- ========================================================
    -- 5. NUEVA TANDA
    -- ========================================================

    state.resetBatchCounter()

    state.save()

    -- ========================================================
    -- 6. REGRESAR
    -- ========================================================

    if
        returnAfter
        and
        returnPosition
    then

        print("")
        print(
            "Regresando al trabajo..."
        )

        local returnOK,
            returnError =
            navigation.goToPosition(

                returnPosition,

                {
                    onControl =
                        function()

                            return checkControl()

                        end
                }

            )

        if not returnOK then

            return false,
                returnError

        end

        if returnDirection ~= nil then

            movement.turnTo(
                returnDirection
            )

        end

    end

    return true

end

return stations