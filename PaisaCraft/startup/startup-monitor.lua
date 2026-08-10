-- ============================================================
-- PAISACRAFT
-- STARTUP MONITOR
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT MONITOR")
print("==============================")

print("")
print("Iniciando monitor...")

sleep(1)

if not fs.exists("monitor.lua") then

    print("")
    print("ERROR:")
    print("monitor.lua no existe.")

    return

end

local ok, err =
    pcall(
        function()

            shell.run(
                "monitor.lua"
            )

        end
    )

if not ok then

    print("")
    print("==============================")
    print("       MONITOR CRASH")
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