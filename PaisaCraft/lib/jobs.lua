-- ============================================================
-- ¿TANDA COMPLETA?
-- ============================================================

function jobs.needsBatchService()

    return
        (
            state.blocksThisBatch
            or 0
        )
        >=
        config.BATCH_BLOCK_LIMIT

end

-- ============================================================
-- SERVICIO DE TANDA
--
-- Orden interno de stations.fullRestock():
--
-- REPLACE:
--   descarga -> fuel -> materiales -> regreso
--
-- CLEAR:
--   descarga -> fuel -> regreso
--
-- PLACE:
--   fuel -> materiales -> regreso
-- ============================================================

function jobs.batchService()

    if not jobs.needsBatchService() then
        return true
    end

    print("")
    print("==============================")
    print("       TANDA COMPLETA")
    print("==============================")

    print("")
    print(
        "Bloques de tanda:",
        state.blocksThisBatch
    )

    print(
        "Limite:",
        config.BATCH_BLOCK_LIMIT
    )

    jobs.report(
        "RESTOCK"
    )

    -- ========================================================
    -- IMPORTANTE:
    --
    -- true significa:
    -- guardar posición actual,
    -- hacer servicio,
    -- regresar al punto de trabajo.
    -- ========================================================

    local ok, err =
        stations.fullRestock(
            true
        )

    if not ok then

        return false,
            err

    end

    -- stations.fullRestock()
    -- ya reinicia blocksThisBatch.

    state.save()

    jobs.report(
        "BUILDING"
    )

    return true

end
