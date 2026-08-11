-- ============================================================
-- PAISACRAFT
-- STARTUP MONITOR
-- ============================================================

local MONITOR =
    "/PaisaCraft/monitor.lua"

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT MONITOR")
print("==============================")

print("")
print("Iniciando monitor...")

sleep(1)

-- ============================================================
-- COMPROBAR MONITOR
-- ============================================================

if not fs.exists(MONITOR) then

    print("")
    print("==============================")
    print("           ERROR")
    print("==============================")

    print("")
    print("monitor.lua no existe.")

    print("")
    print("Ruta esperada:")

    print(
        MONITOR
    )

    return

end

-- ============================================================
-- EJECUTAR MONITOR
-- ============================================================

local ok,
    err =
    pcall(
        function()

            shell.run(
                MONITOR
            )

        end
    )

-- ============================================================
-- ERROR
-- ============================================================

if not ok then

    print("")
    print("==============================")
    print("       MONITOR CRASH")
    print("==============================")

    print("")

    print(
        tostring(
            err
        )
    )

    print("")
    print(
        "Reiniciando en 5 segundos..."
    )

    sleep(5)

    os.reboot()

end
