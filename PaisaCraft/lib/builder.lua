-- ============================================================
-- PAISACRAFT
-- BUILDER v6.1.2
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
-- MAPA DINÁMICO DE DROPS
--
-- Ejemplo:
--
-- minecraft:stone
--      ->
-- minecraft:cobblestone
--
-- No es persistente.
-- Si reinicia la turtle, simplemente volverá
-- a aprender los drops.
-- ============================================================

local knownDrops = {}

-- ============================================================
-- MODO ACTUAL
-- ============================================================

function builder.getBuildMode()

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

function builder.getReplaceFilter()

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
-- INSPECCIONAR
-- ============================================================

function builder.inspectTarget()

    local ok, data =
        turtle.inspectDown()

    if not ok then
        return nil
    end

    return data

end

-- ============================================================
-- ¿SE PUEDE REEMPLAZAR?
-- ============================================================

function builder.canReplace(data)

    if not data then
        return false
    end

    local filter =
        builder.getReplaceFilter()

    if filter == nil then
        return true
    end

    return
        filter[data.name]
        == true

end

-- ============================================================
-- ASEGURAR MATERIAL
-- ============================================================

function builder.ensureMaterial()

    if inventory.selectBuildingMaterial() then
        return true
    end

    print("")
    print("==============================")
    print("      SIN MATERIALES")
    print("==============================")

    local ok, err =
        stations.fullRestock(
            true
        )

    if not ok then
        return false, err
    end

    if
        not inventory.selectBuildingMaterial()
    then

        return false,
            "SIN_MATERIAL"

    end

    return true

end

-- ============================================================
-- TANDA
-- ============================================================

function builder.ensureBatchCapacity()

    if not state.batchLimitReached() then
        return true
    end

    print("")
    print("==============================")
    print("       FIN DE TANDA")
    print("==============================")

    print(
        "Procesados:",
        state.blocksThisBatch
    )

    local ok, err =
        stations.fullRestock(
            true
        )

    if not ok then
        return false, err
    end

    return true

end

-- ============================================================
-- PREPARAR SLOT PARA UN BLOQUE
--
-- Si conocemos qué drop produce este bloque,
-- podemos saber ANTES de romper si slot 16
-- es compatible.
--
-- Si todavía no conocemos su drop y slot 16
-- contiene algo, descargamos primero.
-- ============================================================

function builder.prepareDropStorage(
    blockData
)

    if not blockData then

        return false,
            "BLOQUE_INVALIDO"

    end

    if inventory.isReservedEmpty() then
        return true
    end

    local knownDrop =
        knownDrops[
            blockData.name
        ]

    -- ========================================================
    -- TODAVÍA NO SABEMOS QUÉ DROPEA
    --
    -- Para no arriesgar una mezcla,
    -- vaciamos el slot.
    -- ========================================================

    if not knownDrop then

        print("")
        print(
            "Drop desconocido -> descarga preventiva"
        )

        return stations.unloadOnly(
            true
        )

    end

    -- ========================================================
    -- DROP CONOCIDO Y COMPATIBLE
    -- ========================================================

    if
        inventory.reservedAcceptsItem(
            knownDrop
        )
    then

        return true

    end

    -- ========================================================
    -- INCOMPATIBLE / LLENO
    -- ========================================================

    print("")
    print(
        "Slot 16 incompatible -> descarga"
    )

    return stations.unloadOnly(
        true
    )

end

-- ============================================================
-- COLOCAR
-- ============================================================

function builder.place()

    local materialOK,
        materialError =
        builder.ensureMaterial()

    if not materialOK then

        return false,
            materialError

    end

    local ok, reason =
        turtle.placeDown()

    if ok then

        return true,
            "PLACED"

    end

    -- ========================================================
    -- POSIBLE ENTIDAD
    -- ========================================================

    for attempt = 1, 3 do

        sleep(0.25)

        if turtle.placeDown() then

            return true,
                "PLACED"

        end

    end

    -- Algo ocupó la posición.

    if turtle.detectDown() then

        return true,
            "EXISTING"

    end

    return false,
        "PLACE_FAILED:"
        ..
        tostring(reason)

end

-- ============================================================
-- ROMPER
-- ============================================================

function builder.dig(
    blockData
)

    if not blockData then

        return false,
            "SIN_BLOQUE"

    end

    -- ========================================================
    -- PREPARAR ALMACENAMIENTO
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
    -- SNAPSHOT ANTES DEL DIG
    -- ========================================================

    local before =
        inventory.snapshot()

    -- La selección del slot 16 se mantiene
    -- como preferencia, pero NO dependemos
    -- de que CC:Tweaked lo use para guardar
    -- los drops.

    inventory.selectReservedSlot()

    -- ========================================================
    -- DIG
    -- ========================================================

    local ok, reason =
        turtle.digDown()

    if not ok then

        return false,
            "DIG_FAILED:"
            ..
            tostring(reason)

    end

    -- El comando de la turtle ya es síncrono,
    -- pero dejamos un yield mínimo antes
    -- de inspeccionar el inventario.

    sleep(0)

    -- ========================================================
    -- LOCALIZAR Y CONSOLIDAR DROPS
    -- ========================================================

    local collected,
        dropName,
        dropCount =
        inventory.collectDigDrops(
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

        knownDrops[
            blockData.name
        ] =
            dropName

    end

    print(
        "Drop:",
        dropName or "ninguno",
        dropCount or 0
    )

    state.clearBuildingSlot()

    return true,
        "DUG"

end

-- ============================================================
-- PLACE
-- ============================================================

function builder.processPlace(
    existingBlock
)

    if existingBlock then

        return true,
            "EXISTING"

    end

    return builder.place()

end

-- ============================================================
-- REPLACE
-- ============================================================

function builder.processReplace(
    existingBlock
)

    -- ========================================================
    -- HUECO
    -- ========================================================

    if not existingBlock then

        return builder.place()

    end

    -- ========================================================
    -- FILTRO
    -- ========================================================

    if
        not builder.canReplace(
            existingBlock
        )
    then

        return true,
            "FILTERED"

    end

    -- ========================================================
    -- ROMPER
    -- ========================================================

    local digOK,
        digResult =
        builder.dig(
            existingBlock
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

        -- No avanzamos currentIndex.
        -- El trabajo podrá retomarse exactamente
        -- en esta coordenada.

        return false,
            "REPLACE_PLACE_FAILED:"
            ..
            tostring(placeResult)

    end

    return true,
        "REPLACED"

end

-- ============================================================
-- CLEAR
-- ============================================================

function builder.processClear(
    existingBlock
)

    if not existingBlock then

        return true,
            "EMPTY"

    end

    local digOK,
        digResult =
        builder.dig(
            existingBlock
        )

    if not digOK then

        return false,
            digResult

    end

    return true,
        "CLEARED"

end

-- ============================================================
-- PROCESAR POSICIÓN ACTUAL
-- ============================================================

function builder.processCurrentBlock()

    -- ========================================================
    -- TANDA
    -- ========================================================

    local batchOK,
        batchError =
        builder.ensureBatchCapacity()

    if not batchOK then

        return false,
            batchError

    end

    -- ========================================================
    -- INSPECCIONAR
    -- ========================================================

    local existingBlock =
        builder.inspectTarget()

    local mode =
        builder.getBuildMode()

    -- ========================================================
    -- PLACE
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.PLACE
    then

        return builder.processPlace(
            existingBlock
        )

    end

    -- ========================================================
    -- REPLACE
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.REPLACE
    then

        return builder.processReplace(
            existingBlock
        )

    end

    -- ========================================================
    -- CLEAR
    -- ========================================================

    if
        mode ==
        config.BUILD_MODES.CLEAR
    then

        return builder.processClear(
            existingBlock
        )

    end

    return false,
        "MODO_DESCONOCIDO:"
        ..
        tostring(mode)

end

return builder