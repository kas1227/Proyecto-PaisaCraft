-- ============================================================
-- PAISACRAFT
-- STARTUP WORKER
-- ============================================================

local WORKER =
    "/PaisaCraft/worker.lua"

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT WORKER")
print("==============================")

print("")
print("Iniciando worker...")

sleep(1)

if not fs.exists(WORKER) then

    print("")
    print("ERROR:")
    print("No existe:")
    print(WORKER)

    return

end

local ok, err =
    pcall(
        function()

            shell.run(
                WORKER
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
