-- ============================================================
-- PAISACRAFT
-- STARTUP WORKER
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT WORKER")
print("==============================")

print("")
print("Iniciando worker...")

sleep(1)

if not fs.exists("worker.lua") then

    print("")
    print("ERROR:")
    print("worker.lua no existe.")

    return

end

local ok, err =
    pcall(
        function()

            shell.run(
                "worker.lua"
            )

        end
    )

if not ok then

    print("")
    print("==============================")
    print("        WORKER CRASH")
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