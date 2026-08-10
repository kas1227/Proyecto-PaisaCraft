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

    -- Preferimos slot 16 para drops,
    -- aunque luego consolidamos por snapshot.

    inventory.selectReservedSlot()

    -- ========================================================
    -- ROMPER
    -- ========================================================

    local ok, reason =
        turtle.digDown()

    if not ok then

        return false,
            "DIG_FAILED:"
            ..
            tostring(reason)

    end

    sleep(0)

    -- ========================================================
    -- PRIMER INTENTO DE CONSOLIDAR DROPS
    -- ========================================================

    local collected,
        dropName,
        dropCount =
        inventory.collectDigDrops(
            before
        )

    -- ========================================================
    -- SI EL DROP NO CABE / ES INCOMPATIBLE
    --
    -- Descargamos lo que ya había en slot 16
    -- y volvemos a intentar consolidar.
    -- ========================================================

    if not collected then

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

        if retryable then

            print("")
            print(
                "Drop requiere descarga."
            )

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

            -- =================================================
            -- NUEVO SNAPSHOT BASE
            --
            -- Los drops del bloque ya están dentro del
            -- inventario. Creamos un "before" artificial
            -- donde esos deltas cuentan como nuevos otra vez.
            -- =================================================

            local current =
                inventory.snapshot()

            local retryBefore = {}

            for slot =
                config.SLOT_FIRST,
                config.SLOT_LAST
            do

                local info =
                    current[slot]
                    or {
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

            -- =================================================
            -- RESTAR LOS DELTAS DEL DIG ORIGINAL
            --
            -- De esta forma collectDigDrops()
            -- puede volver a detectarlos.
            -- =================================================

            local originalDeltas =
                inventory.findPositiveDeltas(
                    before
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
                        entry.name = nil
                    end

                end

            end

            collected,
            dropName,
            dropCount =
                inventory.collectDigDrops(
                    retryBefore
                )

        end

    end

    -- ========================================================
    -- SI TODAVÍA FALLA
    -- ========================================================

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
