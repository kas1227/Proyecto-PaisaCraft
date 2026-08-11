-- ============================================================
-- PAISACRAFT
-- STARTUP CENTRAL
-- ============================================================

local CENTRAL =
    "/PaisaCraft/central.lua"

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT CENTRAL")
print("==============================")

print("")
print("Iniciando central...")

sleep(1)

-- ============================================================
-- COMPROBAR CENTRAL
-- ============================================================

if not fs.exists(CENTRAL) then

    print("")
    print("==============================")
    print("           ERROR")
    print("==============================")

    print("")
    print("central.lua no existe.")

    print("")
    print("Ruta esperada:")

    print(
        CENTRAL
    )

    return

end

-- ============================================================
-- EJECUTAR CENTRAL
-- ============================================================

local ok,
    err =
    pcall(
        function()

            shell.run(
                CENTRAL
            )

        end
    )

-- ============================================================
-- ERROR
-- ============================================================

if not ok then

    print("")
    print("==============================")
    print("       CENTRAL CRASH")
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
