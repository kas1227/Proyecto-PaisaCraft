-- ============================================================
-- PAISACRAFT
-- BUILDER v6.1.5
-- ============================================================

local config =
    require("lib.config")

local state =
    require("lib.state")

local inventory =
    require("lib.inventory")

local stations =
    require("lib.stations")

local builder = {}

-- ============================================================
-- DROPS CONOCIDOS
--
-- Se aprende dinamicamente:
--
-- bloque roto -> item recibido
-- ============================================================

local knownDrops = {}

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
-- FILTRO REPLACE
-- ============================================================

local function getReplaceFilter()

    if
        state.assignment
        and
        state.assignment.replaceFilter
        ~= nil
    then

        return
            state.assignment.replaceFilter

    end

    return
        config.DEFAULT_REPLACE_FILTER

end

-- ============================================================
-- INSPECCIONAR ABAJO
-- ============================================================

function builder.inspectDown()

    local exists,
        data =
        turtle.inspectDown()

    if not exists then

        return false,
            nil

    end

    return true,
        data

end

-- ============================================================
-- ¿DEBE REEMPLAZARSE ESTE BLOQUE?
-- ============================================================

function builder.matchesReplaceFilter(
    blockData
)

    local filter =
        getReplaceFilter()

    -- ========================================================
    -- SIN FILTRO
    --
    -- Cualquier bloque puede reemplazarse.
    -- ========================================================

    if filter == nil then

        return true

    end

    if not blockData then

        return false

    end

    -- ========================================================
    -- STRING
    --
    -- Ejemplo:
    --
    -- minecraft:stone
    -- ========================================================

    if type(filter) == "string" then

        return
            blockData.name
            ==
            filter

    end

    -- ========================================================
    -- TABLA
    --
    -- Puede ser:
    --
    -- {
    --     ["minecraft:stone"] = true,
    --     ["minecraft:dirt"] = true
    -- }
    --
    -- o:
    --
    -- {
    --     "minecraft:stone",
    --     "minecraft:dirt"
    -- }
    -- ========================================================

    if type(filter) == "table" then

        if
            filter[
                blockData.name
            ]
            ==
            true
        then

            return true

        end

        for _, name
            in ipairs(filter)
        do

            if name == blockData.name then

                return true

            end

        end

    end

    return false

end

-- ============================================================
-- DROP CONOCIDO
-- ============================================================

function builder.getKnownDrop(
    blockName
)

    if not blockName then
        return nil
    end

    return
        knownDrops[
            blockName
        ]

end

-- ============================================================
-- APRENDER DROP
-- ============================================================

function builder.learnDrop(
    blockName,
    dropName
)

    if
        not blockName
        or
        not dropName
    then

        return false

    end

    knownDrops[
        blockName
    ] =
        dropName

    return true

end

-- ============================================================
-- PREPARAR SLOT 16
--
-- Antes de romper intentamos prever si el drop
-- va a caber en el slot reservado.
-- ============================================================

function builder.prepareDropStorage(
    blockData
)

    if not blockData then

        return false,
            "SIN_BLOQUE"

    end

    -- ========================================================
    -- SLOT VACIO
    -- ========================================================

    if inventory.isReservedEmpty() then

        return true

    end

    -- ========================================================
    -- SLOT LLENO
    -- ========================================================

    if
        not inventory.reservedSlotHasSpace()
    then

        print("")
        print(
            "Slot 16 lleno."
        )

        local unloadOK,
            unloadError =
            stations.unloadOnly(
                true
            )

        if not unloadOK then

            return false,
                unloadError

        end

        return true

    end

    -- ========================================================
    -- DROP YA CONOCIDO
    -- ========================================================

    local expectedDrop =
        builder.getKnownDrop(
            blockData.name
        )

    if expectedDrop then

        if
            inventory.reservedAcceptsItem(
                expectedDrop
            )
        then

            return true

        end

        print("")
        print(
            "Drop diferente al slot 16."
        )

        local unloadOK,
            unloadError =
            stations.unloadOnly(
                true
            )

        if not unloadOK then

            return false,
                unloadError

        end

        return true

    end

    -- ========================================================
    -- DROP DESCONOCIDO
    --
    -- Como el slot 16 ya tiene algo y no sabemos
    -- que drop producira este bloque, descargamos
    -- preventivamente para evitar mezcla.
    -- ========================================================

    print("")
    print(
        "Drop desconocido."
    )

    print(
        "Descarga preventiva."
    )

    local unloadOK,
        unloadError =
        stations.unloadOnly(
            true
        )

    if not unloadOK then

        return false,
            unloadError

    end

    return true

end

-- ============================================================
-- CREAR RETRY BEFORE
--
-- Los drops ya existen dentro del inventario.
--
-- Para volver a pasarlos por collectDigDrops()
-- necesitamos reconstruir un snapshot anterior
-- artificial.
-- ============================================================

local function buildRetrySnapshot(
    originalBefore
)

    local current =
        inventory.snapshot()

    local retryBefore = {}

    for slot =
        config.SLOT_FIRST,
        config.SLOT_LAST
    do

        local info =
            current[slot]
            or
            {
                count = 0,
                name = nil
            }

        retryBefore[slot] = {

            count =
                info.count,

            name =
                info.name

        }

    end

    local originalDeltas =
        inventory.findPositiveDeltas(
            originalBefore
        )

    for _, delta
        in ipairs(
            originalDeltas
        )
    do

        local slot =
            delta.slot

        local entry =
            retryBefore[slot]

        if entry then

            entry.count =
                math.max(

                    0,

                    entry.count
                    -
                    delta.count

                )

            if entry.count == 0 then

                entry.name =
                    nil

            end

        end

    end

    return retryBefore

end

-- ============================================================
-- CONSOLIDAR DROP CON REINTENTO
-- ============================================================

local function collectDropsWithRetry(
    before
)

    local collected,
        dropName,
        dropCount =
        inventory.collectDigDrops(
            before
        )

    if collected then

        return true,
            dropName,
            dropCount

    end

    local errorCode =
        dropName

    local retryable =
        errorCode ==
        "DROP_MULTITIPO"

        or

        errorCode ==
        "DROP_INCOMPATIBLE_CON_SLOT_16"

        or

        errorCode ==
        "SLOT_16_SIN_ESPACIO"

    if not retryable then

        return false,
            errorCode

    end

    print("")
    print(
        "Drop requiere descarga."
    )

    -- ========================================================
    -- DESCARGAR SLOT 16
    -- ========================================================

    local unloadOK,
        unloadError =
        stations.unloadOnly(
            true
        )

    if not unloadOK then

        return false,
            unloadError
            or
            "DESCARGA_FALLIDA"

    end

    -- ========================================================
    -- VOLVER A DETECTAR LOS DROPS DEL DIG ORIGINAL
    -- ========================================================

    local retryBefore =
        buildRetrySnapshot(
            before
        )

    collected,
    dropName,
    dropCount =
        inventory.collectDigDrops(
            retryBefore
        )

    if not collected then

        return false,
            dropName
            or
            "ERROR_RECOGIENDO_DROP"

    end

    return true,
        dropName,
        dropCount

end

-- ============================================================
-- ROMPER ABAJO
-- ============================================================

function builder.dig(
    blockData
)

    if not blockData then

        return false,
            "SIN_BLOQUE"

    end

    -- ========================================================
    -- PREPARAR SLOT 16
    -- ========================================================

    local storageOK,
        storageError =
        builder.prepareDropStorage(
            blockData
        )

    if not storageOK then

        return false,
            storageError

    end

    -- ========================================================
    -- SNAPSHOT
    -- ========================================================

    local before =
        inventory.snapshot()

    -- Preferimos que el drop entre directamente
    -- al slot reservado si Minecraft lo permite.

    inventory.selectReservedSlot()

    -- ========================================================
    -- DIG
    -- ========================================================

    local ok,
        reason =
        turtle.digDown()

    if not ok then

        return false,
            "DIG_FAILED:"
            ..
            tostring(reason)

    end

    -- Permitir que CC actualice el inventario.

    sleep(0)

    -- ========================================================
    -- RECOGER DROP
    -- ========================================================

    local collected,
        dropName,
        dropCount =
        collectDropsWithRetry(
            before
        )

    if not collected then

        return false,
            dropName
            or
            "ERROR_RECOGIENDO_DROP"

    end

    -- ========================================================
    -- APRENDER DROP
    -- ========================================================

    if dropName then

        builder.learnDrop(

            blockData.name,

            dropName

        )

    end

    print(
        "Drop:",
        dropName
        or
        "ninguno",
        dropCount
        or
        0
    )

    state.clearBuildingSlot()

    return true,
        "DUG"

end

-- ============================================================
-- COLOCAR BLOQUE ABAJO
-- ============================================================

function builder.place()

    local materialOK =
        inventory.selectBuildingMaterial()

    if not materialOK then

        return false,
            "SIN_MATERIAL"

    end

    local ok,
        reason =
        turtle.placeDown()

    if not ok then

        return false,
            "PLACE_FAILED:"
            ..
            tostring(reason)

    end

    return true,
        "PLACED"

end

-- ============================================================
-- PLACE
--
-- Solo coloca si abajo esta vacio.
-- ============================================================

function builder.processPlace()

    local exists =
        turtle.detectDown()

    if exists then

        return true,
            "SKIPPED"

    end

    return builder.place()

end

-- ============================================================
-- REPLACE
-- ============================================================

function builder.processReplace()

    local exists,
        blockData =
        builder.inspectDown()

    -- ========================================================
    -- NO HAY BLOQUE
    --
    -- Colocamos normalmente.
    -- ========================================================

    if not exists then

        local placeOK,
            placeResult =
            builder.place()

        if not placeOK then

            return false,
                placeResult

        end

        return true,
            "PLACED"

    end

    -- ========================================================
    -- FILTRO
    -- ========================================================

    if
        not builder.matchesReplaceFilter(
            blockData
        )
    then

        return true,
            "SKIPPED"

    end

    -- ========================================================
    -- ROMPER
    -- ========================================================

    local digOK,
        digResult =
        builder.dig(
            blockData
        )

    if not digOK then

        return false,
            digResult

    end

    -- ========================================================
    -- COLOCAR
    -- ========================================================

    local placeOK,
        placeResult =
        builder.place()

    if not placeOK then

        return false,
            placeResult

    end

    return true,
        "REPLACED"

end

-- ============================================================
-- CLEAR
-- ============================================================

function builder.processClear()

    local exists,
        blockData =
        builder.inspectDown()

    if not exists then

        return true,
            "SKIPPED"

    end

    local digOK,
        digResult =
        builder.dig(
            blockData
        )

    if not digOK then

        return false,
            digResult

    end

    return true,
        "CLEARED"

end

-- ============================================================
-- PROCESAR BLOQUE ACTUAL
-- ============================================================

function builder.processCurrentBlock()

    local mode =
        getBuildMode()

    -- ========================================================
    -- PLACE
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.PLACE
    then

        return
            builder.processPlace()

    end

    -- ========================================================
    -- REPLACE
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.REPLACE
    then

        return
            builder.processReplace()

    end

    -- ========================================================
    -- CLEAR
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.CLEAR
    then

        return
            builder.processClear()

    end

    return false,
        "MODO_DESCONOCIDO:"
        ..
        tostring(mode)

end

-- ============================================================
-- ESTADISTICAS
-- ============================================================

function builder.getStats()

    local known = 0

    for _ in pairs(
        knownDrops
    )
    do

        known =
            known
            +
            1

    end

    return {

        mode =
            getBuildMode(),

        replaceFilter =
            getReplaceFilter(),

        knownDrops =
            known,

        reservedItems =
            inventory.getReservedCount(),

        reservedSpace =
            inventory.getReservedSpace()

    }

end

return builder
