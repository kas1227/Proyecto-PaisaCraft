-- ============================================================
-- PAISACRAFT
-- STARTUP CENTRAL
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT CENTRAL")
print("==============================")

print("")
print("Iniciando central...")

sleep(1)

if not fs.exists("central.lua") then

    print("")
    print("ERROR:")
    print("central.lua no existe.")

    return

end

local ok, err =
    pcall(
        function()

            shell.run(
                "central.lua"
            )

        end
    )

if not ok then

    print("")
    print("==============================")
    print("       CENTRAL CRASH")
    print("==============================")

    print("")
    print(
        tostring(err)
    )

    print("")
    print(
        "Reiniciando en 5 segundos..."
    )

    sleep(5)

    os.reboot()

end