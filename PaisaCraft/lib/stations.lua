-- ============================================================
-- PAISACRAFT
-- ESTACIONES v6.1.5
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
-- CALLBACK DE CONTROL
-- ============================================================

local controlCallback = nil


function stations.setControlCallback(callback)

    controlCallback = callback

end


local function checkControl(msg)

    if controlCallback then

        return controlCallback(msg)

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

        return state.assignment.buildMode

    end

    return config.DEFAULT_BUILD_MODE

end

-- ============================================================
-- ¿NECESITA MATERIALES?
-- ============================================================

local function needsMaterials()

    return
        getBuildMode()
        ~= config.BUILD_MODES.CLEAR

end

-- ============================================================
-- ¿USA DESCARGA?
-- ============================================================

local function usesUnloadStation()

    local mode =
        getBuildMode()

    return
        mode == config.BUILD_MODES.REPLACE
        or
        mode == config.BUILD_MODES.CLEAR

end

-- ============================================================
-- CANCELAR RESERVAS
-- ============================================================

function stations.cancelReservations()

    protocol.send({

        type =
            protocol.MESSAGE.CANCEL_RESERVATIONS

    })

end

-- ============================================================
-- ESPERAR PERMISO DE ESTACIÓN
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
            protocol.receiveCentral(3)

        if
            id
            and
            type(msg) == "table"
        then

            if msg.type == grantedType then

                return true

            elseif msg.type == waitType then

                print(
                    "Esperando turno. Cola:",
                    msg.position or "?"
                )

            else

                checkControl(msg)

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

local function goToStation(position)

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
-- LIBERAR ESTACIONES
-- ============================================================

local function finishMaterial()

    protocol.send({

        type =
            protocol.MESSAGE.MATERIAL_DONE

    })

end


local function finishFuel()

    protocol.send({

        type =
            protocol.MESSAGE.FUEL_DONE

    })

end


local function finishUnload()

    protocol.send({

        type =
            protocol.MESSAGE.UNLOAD_DONE

    })

end

-- ============================================================
-- SALIR DE ESTACIÓN
-- ============================================================

function stations.leaveStation()

    while true do

        local ok, reason =
            movement.forward()

        if ok then
            return true
        end

        if reason ~= "BLOQUEADO" then

            return false,
                reason

        end

        print(
            "Salida bloqueada..."
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
-- DESCARGAR MATERIAL RETIRADO
--
-- SLOT 16:
-- exclusivamente para bloques/items retirados.
-- ============================================================

function stations.unloadRemovedItems()

    -- Nada que descargar.

    if
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        == 0
    then

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

    print("")
    print("==============================")
    print("          DESCARGA")
    print("==============================")

    print("")
    print(
        "Items:",
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
    )

    -- ========================================================
    -- PEDIR TURNO
    -- ========================================================

    local permissionOK,
        permissionError =
        stations.requestUnload()

    if not permissionOK then

        return false,
            permissionError

    end

    -- ========================================================
    -- IR A DESCARGA
    -- ========================================================

    local navigationOK,
        navigationError =
        goToStation(station)

    if not navigationOK then

        finishUnload()

        return false,
            navigationError

    end

    -- ========================================================
    -- CONFIRMAR RESERVA
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
    -- SLOT 16
    -- ========================================================

    turtle.select(
        config.RESERVED_SLOT
    )

    -- ========================================================
    -- DESCARGAR HACIA ARRIBA
    --
    -- En el punto de descarga habrá un sistema
    -- que reciba/extráiga los items.
    -- ========================================================

    while
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        > 0
    do

        local before =
            turtle.getItemCount(
                config.RESERVED_SLOT
            )

        turtle.dropUp()

        local after =
            turtle.getItemCount(
                config.RESERVED_SLOT
            )

        -- ====================================================
        -- VERIFICAR SI REALMENTE SALIERON ITEMS
        -- ====================================================

        if after >= before then

            print(
                "Esperando espacio de descarga..."
            )

            sleep(
                config.STOCK_WAIT
            )

        end

        -- ====================================================
        -- CONTROL
        -- ====================================================

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

    -- ========================================================
    -- VERIFICACIÓN FINAL
    -- ========================================================

    if
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        ~= 0
    then

        finishUnload()

        return false,
            "DESCARGA_INCOMPLETA"

    end

    print("")
    print(
        "Descarga completa."
    )

    print(
        "Slot 16 libre."
    )

    -- ========================================================
    -- SALIR
    -- ========================================================

    local leaveOK,
        leaveError =
        stations.leaveStation()

    finishUnload()

    if not leaveOK then

        return false,
            leaveError

    end

    return true

end

-- ============================================================
-- DESCARGA COMPATIBLE CON BUILDER
--
-- builder.lua ya utiliza unloadOnly().
-- Mantenemos esta función para no romperlo.
-- ============================================================

function stations.unloadOnly(returnAfter)

    if
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        == 0
    then

        return true

    end

    local returnPosition = nil
    local returnDirection = nil

    if returnAfter then

        returnPosition =
            state.getPosition()

        returnDirection =
            state.getDirection()

    end

    local ok, err =
        stations.unloadRemovedItems()

    if not ok then

        return false,
            err

    end

    -- ========================================================
    -- VOLVER AL PUNTO ANTERIOR
    -- ========================================================

    if
        returnAfter
        and
        returnPosition
    then

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
-- CONSUMIR COMBUSTIBLE DEL INVENTARIO
-- ============================================================

function stations.refuelFromChest(targetFuel)

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

        -- ====================================================
        -- SLOT 16 JAMÁS SE UTILIZA
        -- ====================================================

        local ok, reason =
            inventory.collectFuelUp(16)

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
-- REPOSTAR
-- ============================================================

function stations.refuel(targetFuel)

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

    -- ========================================================
    -- PEDIR TURNO
    -- ========================================================

    local permissionOK,
        permissionError =
        stations.requestFuel()

    if not permissionOK then

        return false,
            permissionError

    end

    -- ========================================================
    -- IR
    -- ========================================================

    local navigationOK,
        navigationError =
        goToStation(station)

    if not navigationOK then

        finishFuel()

        return false,
            navigationError

    end

    -- ========================================================
    -- CONFIRMAR
    -- ========================================================

    local confirmOK,
        confirmError =
        stations.requestFuel()

    if not confirmOK then

        finishFuel()

        return false,
            confirmError

    end

    print("")
    print(
        "Fuel actual:",
        movement.getFuelLevel()
    )

    print(
        "Objetivo:",
        targetFuel
    )

    -- ========================================================
    -- REPOSTAR
    -- ========================================================

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

    -- ========================================================
    -- SALIR
    -- ========================================================

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
-- CARGAR MATERIALES
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

    -- ========================================================
    -- PEDIR TURNO
    -- ========================================================

    local permissionOK,
        permissionError =
        stations.requestMaterial()

    if not permissionOK then

        return false,
            permissionError

    end

    -- ========================================================
    -- IR
    -- ========================================================

    local navigationOK,
        navigationError =
        goToStation(station)

    if not navigationOK then

        finishMaterial()

        return false,
            navigationError

    end

    -- ========================================================
    -- CONFIRMAR
    -- ========================================================

    local confirmOK,
        confirmError =
        stations.requestMaterial()

    if not confirmOK then

        finishMaterial()

        return false,
            confirmError

    end

    -- ========================================================
    -- IMPORTANTE
    --
    -- inventory.collectBuildMaterialsUp()
    -- solo utiliza slots 1-15.
    -- ========================================================

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

    print("")
    print(
        "Materiales:",
        inventory.countBuildMaterials()
    )

    -- ========================================================
    -- SLOT 16 DEBE PERMANECER LIBRE
    -- ========================================================

    if
        usesUnloadStation()
        and
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        > 0
    then

        finishMaterial()

        return false,
            "SLOT_16_OCUPADO_TRAS_CARGA"

    end

    -- ========================================================
    -- SALIR
    -- ========================================================

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

function stations.fullRestock(returnAfter)

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

    local mode =
        getBuildMode()

    print("")
    print("==============================")
    print("       CICLO DE SERVICIO")
    print("==============================")

    -- ========================================================
    -- PASO 1
    -- DESCARGA
    --
    -- Solo REPLACE / CLEAR.
    -- Solo si slot 16 contiene algo.
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
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        > 0
    then

        print("")
        print(
            "1/3 Descargando..."
        )

        local unloadOK,
            unloadError =
            stations.unloadRemovedItems()

        if not unloadOK then

            stations.cancelReservations()

            return false,
                unloadError

        end

    end

    -- ========================================================
    -- SEGURIDAD
    -- ========================================================

    if state.returnRequested then

        stations.cancelReservations()

        return false,
            "RETURN_REQUESTED"

    end

    -- ========================================================
    -- VERIFICAR SLOT 16
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
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        ~= 0
    then

        return false,
            "SLOT_16_NO_SE_DESCARGO"

    end

    -- ========================================================
    -- PASO 2
    -- COMBUSTIBLE
    -- ========================================================

    print("")
    print(
        "2/3 Repostando..."
    )

    local targetFuel =
        fuel.calculateTarget(
            returnPosition
        )

    print(
        "Fuel calculado:",
        targetFuel
    )

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

    -- ========================================================
    -- CONTROL
    -- ========================================================

    if state.returnRequested then

        stations.cancelReservations()

        return false,
            "RETURN_REQUESTED"

    end

    -- ========================================================
    -- PASO 3
    -- MATERIALES
    --
    -- PLACE / REPLACE.
    -- CLEAR no necesita bloques.
    -- ========================================================

    if needsMaterials() then

        print("")
        print(
            "3/3 Cargando materiales..."
        )

        local materialOK,
            materialError =
            stations.collectMaterials()

        if not materialOK then

            stations.cancelReservations()

            return false,
                materialError

        end

    else

        print("")
        print(
            "3/3 Materiales no requeridos."
        )

    end

    -- ========================================================
    -- VERIFICACIÓN FINAL DEL SLOT 16
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
        turtle.getItemCount(
            config.RESERVED_SLOT
        )
        ~= 0
    then

        return false,
            "SLOT_16_OCUPADO_AL_SALIR"

    end

    -- ========================================================
    -- NUEVA TANDA
    -- ========================================================

    state.resetBatchCounter()

    state.save()

    print("")
    print("==============================")
    print("       SERVICIO COMPLETO")
    print("==============================")

    if
        mode ==
        config.BUILD_MODES.REPLACE
    then

        print(
            "Slot 16 listo para reemplazos."
        )

    end

    -- ========================================================
    -- REGRESAR AL TRABAJO
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

        print(
            "Trabajo reanudado."
        )

    end

    return true

end

return stations
