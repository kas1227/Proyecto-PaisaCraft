-- ============================================================
-- PAISACRAFT
-- INVENTARIO v6.1.5
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local inventory = {}

-- ============================================================
-- UTILIDADES DE SLOT
-- ============================================================

function inventory.isReservedSlot(slot)

    return
        slot == config.RESERVED_SLOT

end


function inventory.isBuildSlot(slot)

    return
        slot >= config.BUILD_SLOT_FIRST
        and
        slot <= config.BUILD_SLOT_LAST

end


function inventory.getCount(slot)

    return turtle.getItemCount(slot)

end


function inventory.getSpace(slot)

    return turtle.getItemSpace(slot)

end


function inventory.isEmpty(slot)

    return
        turtle.getItemCount(slot) == 0

end


function inventory.getItemDetail(slot)

    if turtle.getItemCount(slot) <= 0 then
        return nil
    end

    return turtle.getItemDetail(slot)

end

-- ============================================================
-- SLOT VACÍO DE TRABAJO
-- ============================================================

function inventory.findEmptyBuildSlot()

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if turtle.getItemCount(slot) == 0 then
            return slot
        end

    end

    return nil

end

-- ============================================================
-- COMBUSTIBLE
-- ============================================================

function inventory.isFuel(slot)

    if turtle.getItemCount(slot) <= 0 then
        return false
    end

    turtle.select(slot)

    return turtle.refuel(0)

end


function inventory.consumeFuelFromInventory(
    targetFuel
)

    targetFuel =
        targetFuel
        or
        config.TARGET_FUEL

    local currentFuel =
        turtle.getFuelLevel()

    if currentFuel == "unlimited" then
        return true
    end

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            if turtle.refuel(0) then

                turtle.refuel()

                currentFuel =
                    turtle.getFuelLevel()

                if
                    currentFuel == "unlimited"
                    or
                    currentFuel >= targetFuel
                then

                    return true

                end

            end

        end

    end

    currentFuel =
        turtle.getFuelLevel()

    return
        currentFuel == "unlimited"
        or
        currentFuel >= targetFuel

end

-- ============================================================
-- MATERIAL DE CONSTRUCCIÓN
-- ============================================================

function inventory.selectBuildingMaterial()

    local current =
        state.buildingSlot

    -- ========================================================
    -- MANTENER STACK ACTUAL
    -- ========================================================

    if current then

        if
            inventory.isBuildSlot(current)
            and
            turtle.getItemCount(current) > 0
        then

            turtle.select(current)

            if not turtle.refuel(0) then
                return true
            end

        end

        state.clearBuildingSlot()

    end

    -- ========================================================
    -- BUSCAR OTRO STACK
    -- ========================================================

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            if not turtle.refuel(0) then

                state.setBuildingSlot(slot)

                return true

            end

        end

    end

    return false

end

-- ============================================================
-- CONTAR MATERIAL
-- ============================================================

function inventory.countBuildMaterials()

    local total = 0

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            if not turtle.refuel(0) then

                total =
                    total
                    +
                    turtle.getItemCount(slot)

            end

        end

    end

    return total

end


function inventory.countBuildStacks()

    local total = 0

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        if turtle.getItemCount(slot) > 0 then

            turtle.select(slot)

            if not turtle.refuel(0) then

                total =
                    total + 1

            end

        end

    end

    return total

end


function inventory.hasBuildMaterial()

    return
        inventory.countBuildMaterials()
        > 0

end

-- ============================================================
-- SLOT 16 RESERVADO
-- ============================================================

function inventory.selectReservedSlot()

    turtle.select(
        config.RESERVED_SLOT
    )

end


function inventory.getReservedCount()

    return turtle.getItemCount(
        config.RESERVED_SLOT
    )

end


function inventory.getReservedSpace()

    return turtle.getItemSpace(
        config.RESERVED_SLOT
    )

end


function inventory.getReservedDetail()

    return inventory.getItemDetail(
        config.RESERVED_SLOT
    )

end


function inventory.isReservedEmpty()

    return
        inventory.getReservedCount()
        == 0

end


function inventory.reservedSlotHasSpace()

    return
        inventory.getReservedSpace()
        > 0

end

-- ============================================================
-- ¿PUEDE EL SLOT 16 RECIBIR ESTE ITEM?
-- ============================================================

function inventory.reservedAcceptsItem(
    itemName
)

    if not itemName then
        return false
    end

    if inventory.isReservedEmpty() then
        return true
    end

    if not inventory.reservedSlotHasSpace() then
        return false
    end

    local detail =
        inventory.getReservedDetail()

    if not detail then
        return false
    end

    return
        detail.name == itemName

end

-- ============================================================
-- SNAPSHOT DEL INVENTARIO
--
-- Se utiliza antes de digDown().
-- ============================================================

function inventory.snapshot()

    local result = {}

    for slot =
        config.SLOT_FIRST,
        config.SLOT_LAST
    do

        local count =
            turtle.getItemCount(slot)

        local detail = nil

        if count > 0 then

            detail =
                turtle.getItemDetail(slot)

        end

        result[slot] = {

            count = count,

            name =
                detail
                and detail.name
                or nil

        }

    end

    return result

end

-- ============================================================
-- DETECTAR ITEMS NUEVOS
--
-- Compara inventario anterior con el actual.
-- ============================================================

function inventory.findPositiveDeltas(
    before
)

    local deltas = {}

    if type(before) ~= "table" then
        return deltas
    end

    for slot =
        config.SLOT_FIRST,
        config.SLOT_LAST
    do

        local old =
            before[slot]
            or {
                count = 0,
                name = nil
            }

        local newCount =
            turtle.getItemCount(slot)

        local detail = nil

        if newCount > 0 then

            detail =
                turtle.getItemDetail(slot)

        end

        local newName =
            detail
            and detail.name
            or nil

        local added = 0

        -- ====================================================
        -- MISMO ITEM, AUMENTÓ CANTIDAD
        -- ====================================================

        if
            old.name == newName
            and
            newCount > old.count
        then

            added =
                newCount
                -
                old.count

        -- ====================================================
        -- SLOT ANTES VACÍO / CAMBIÓ ITEM
        -- ====================================================

        elseif
            newCount > 0
            and
            old.name ~= newName
        then

            added =
                newCount

        end

        if added > 0 then

            table.insert(
                deltas,
                {
                    slot = slot,
                    count = added,
                    name = newName
                }
            )

        end

    end

    return deltas

end

-- ============================================================
-- MOVER DELTA AL SLOT 16
-- ============================================================

local function transferDeltaToReserved(
    delta
)

    if not delta then

        return false,
            "DELTA_INVALIDO"

    end

    if delta.slot == config.RESERVED_SLOT then

        return true

    end

    if delta.count <= 0 then
        return true
    end

    turtle.select(
        delta.slot
    )

    -- ========================================================
    -- SI SLOT 16 YA TIENE ITEM,
    -- COMPROBAR COMPATIBILIDAD REAL.
    -- ========================================================

    if not inventory.isReservedEmpty() then

        if
            not turtle.compareTo(
                config.RESERVED_SLOT
            )
        then

            return false,
                "DROP_MULTITIPO"

        end

    end

    if
        inventory.getReservedSpace()
        <
        delta.count
    then

        return false,
            "SLOT_16_SIN_ESPACIO"

    end

    local ok =
        turtle.transferTo(
            config.RESERVED_SLOT,
            delta.count
        )

    if not ok then

        return false,
            "TRANSFERENCIA_DROP_FALLIDA"

    end

    return true

end

-- ============================================================
-- CONSOLIDAR DROPS DEL ÚLTIMO DIG
--
-- Los drops pueden aparecer en cualquier slot.
-- Esta función detecta cuáles son nuevos
-- y los mueve al slot 16.
-- ============================================================

function inventory.collectDigDrops(
    before
)

    local deltas =
        inventory.findPositiveDeltas(
            before
        )

    if #deltas == 0 then

        -- Algunos bloques pueden no producir drop.
        return true, nil, 0

    end

    local dropName = nil
    local totalMoved = 0

    -- ========================================================
    -- PRIMERA PASADA:
    -- COMPROBAR QUE LOS DROPS SEAN COMPATIBLES.
    -- ========================================================

    for _, delta
        in ipairs(deltas)
    do

        if delta.name then

            if
                dropName
                and
                delta.name ~= dropName
            then

                return false,
                    "DROP_MULTITIPO"

            end

            dropName =
                delta.name

        end

    end

    -- ========================================================
    -- COMPROBAR COMPATIBILIDAD CON SLOT 16 EXISTENTE
    -- ========================================================

    if
        dropName
        and
        not inventory.isReservedEmpty()
    then

        local reserved =
            inventory.getReservedDetail()

        if
            not reserved
            or
            reserved.name ~= dropName
        then

            return false,
                "DROP_INCOMPATIBLE_CON_SLOT_16"

        end

    end

    -- ========================================================
    -- ESPACIO TOTAL
    -- ========================================================

    local amount = 0

    for _, delta
        in ipairs(deltas)
    do

        amount =
            amount
            +
            delta.count

    end

    if
        inventory.getReservedSpace()
        <
        amount
    then

        return false,
            "SLOT_16_SIN_ESPACIO"

    end

    -- ========================================================
    -- MOVER
    -- ========================================================

    for _, delta
        in ipairs(deltas)
    do

        local ok, err =
            transferDeltaToReserved(
                delta
            )

        if not ok then

            return false,
                err

        end

        totalMoved =
            totalMoved
            +
            delta.count

    end

    state.clearBuildingSlot()

    return true,
        dropName,
        totalMoved

end

-- ============================================================
-- DESCARGA
-- ============================================================

function inventory.needsUnload()

    if not config.AUTO_UNLOAD then
        return false
    end

    -- Si el slot reservado contiene algo,
    -- existe material retirado pendiente de descargar.
    return
        inventory.getReservedCount()
        > 0

end


function inventory.unloadReservedUp()

    if inventory.isReservedEmpty() then
        return true
    end

    inventory.selectReservedSlot()

    return turtle.dropUp()

end


function inventory.unloadReservedDown()

    if inventory.isReservedEmpty() then
        return true
    end

    inventory.selectReservedSlot()

    return turtle.dropDown()

end


function inventory.unloadReservedFront()

    if inventory.isReservedEmpty() then
        return true
    end

    inventory.selectReservedSlot()

    return turtle.drop()

end

-- ============================================================
-- CARGAR MATERIAL DESDE ARRIBA
-- ============================================================

function inventory.collectBuildMaterialsUp()

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        local count =
            turtle.getItemCount(slot)

        if count == 0 then

            turtle.select(slot)

            turtle.suckUp(64)

        else

            turtle.select(slot)

            -- No rellenar stacks de fuel.

            if not turtle.refuel(0) then

                local space =
                    turtle.getItemSpace(slot)

                if space > 0 then

                    turtle.suckUp(
                        space
                    )

                end

            end

        end

    end

    state.clearBuildingSlot()

    return
        inventory.countBuildMaterials()

end

-- ============================================================
-- CARGAR FUEL DESDE ARRIBA
-- ============================================================

function inventory.collectFuelUp(
    amount
)

    amount =
        amount or 16

    local slot =
        inventory.findEmptyBuildSlot()

    if not slot then

        return false,
            "INVENTARIO_LLENO"

    end

    turtle.select(slot)

    if not turtle.suckUp(amount) then

        return false,
            "SIN_COMBUSTIBLE"

    end

    if not turtle.refuel(0) then

        -- Devolver item incorrecto.

        turtle.dropUp()

        return false,
            "ITEM_NO_ES_FUEL"

    end

    return true

end

-- ============================================================
-- ESPACIO DE CONSTRUCCIÓN
-- ============================================================

function inventory.availableBuildSpace()

    local total = 0

    for slot =
        config.BUILD_SLOT_FIRST,
        config.BUILD_SLOT_LAST
    do

        total =
            total
            +
            turtle.getItemSpace(slot)

    end

    return total

end

-- ============================================================
-- ESTADÍSTICAS
-- ============================================================

function inventory.getStats()

    local reserved =
        inventory.getReservedDetail()

    return {

        buildBlocks =
            inventory.countBuildMaterials(),

        buildStacks =
            inventory.countBuildStacks(),

        reservedItems =
            inventory.getReservedCount(),

        reservedItem =
            reserved
            and reserved.name
            or nil,

        reservedSpace =
            inventory.getReservedSpace(),

        availableSpace =
            inventory.availableBuildSpace()

    }

end

return inventory
