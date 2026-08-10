-- ============================================================
-- PAISACRAFT
-- INSTALADOR v6.1.4
-- ============================================================

local config =
    require("lib.config")

local utils =
    require("lib.utils")

-- ============================================================
-- ARCHIVOS
-- ============================================================

local SETTINGS_FILE =
    config.SETTINGS_FILE

local STARTUP_TARGET =
    "startup.lua"

-- ============================================================
-- GUARDAR CONFIGURACIÓN
-- ============================================================

local function saveSettings(
    role
)

    utils.ensureDirectory(
        config.DATA_DIR
    )

    local previous =
        utils.loadTable(
            SETTINGS_FILE
        )
        or
        {}

    previous.role =
        role

    previous.installedVersion =
        config.VERSION

    previous.computerID =
        os.getComputerID()

    local ok, err =
        utils.saveTable(
            SETTINGS_FILE,
            previous
        )

    if not ok then

        return false,
            err

    end

    return true

end

-- ============================================================
-- INSTALAR STARTUP
-- ============================================================

local function installStartup(
    source
)

    if not fs.exists(source) then

        return false,
            "No existe "
            ..
            source

    end

    if fs.exists(
        STARTUP_TARGET
    )
    then

        fs.delete(
            STARTUP_TARGET
        )

    end

    fs.copy(
        source,
        STARTUP_TARGET
    )

    return true

end

-- ============================================================
-- INSTALAR ROL
-- ============================================================

local function installRole(
    role,
    startupFile
)

    print("")
    print("==============================")
    print("          INSTALANDO")
    print("==============================")

    print("")
    print(
        "Rol:",
        role
    )

    -- ========================================================
    -- DATA
    -- ========================================================

    utils.ensureDirectory(
        config.DATA_DIR
    )

    -- ========================================================
    -- STARTUP
    -- ========================================================

    local startupOK,
        startupError =
        installStartup(
            startupFile
        )

    if not startupOK then

        print("")
        print(
            "ERROR startup:"
        )

        print(
            tostring(
                startupError
            )
        )

        return false

    end

    -- ========================================================
    -- SETTINGS
    -- ========================================================

    local settingsOK,
        settingsError =
        saveSettings(
            role
        )

    if not settingsOK then

        print("")
        print(
            "ERROR settings:"
        )

        print(
            tostring(
                settingsError
            )
        )

        return false

    end

    print("")
    print("==============================")
    print("     INSTALACION COMPLETA")
    print("==============================")

    print("")
    print(
        "Rol:",
        role
    )

    print(
        "Version:",
        config.VERSION
    )

    print(
        "Computer ID:",
        os.getComputerID()
    )

    print("")
    print(
        "startup.lua instalado."
    )

    print("")
    print(
        "Reinicia el dispositivo"
    )

    print(
        "o ejecuta:"
    )

    print("")
    print(
        "reboot"
    )

    return true

end

-- ============================================================
-- MENU
-- ============================================================

local function menu()

    term.clear()
    term.setCursorPos(
        1,
        1
    )

    print("==============================")
    print("       PAISACRAFT INSTALL")
    print("==============================")

    print("")
    print(
        "Version:",
        config.VERSION
    )

    print("")
    print(
        "Selecciona dispositivo:"
    )

    print("")
    print("1. Worker")
    print("2. Central")
    print("3. Monitor")
    print("4. Cancelar")

    print("")
    write("> ")

    return read()

end

-- ============================================================
-- MAIN
-- ============================================================

local option =
    menu()

if option == "1" then

    installRole(

        "WORKER",

        "startup/startup-worker.lua"

    )

elseif option == "2" then

    installRole(

        "CENTRAL",

        "startup/startup-central.lua"

    )

elseif option == "3" then

    installRole(

        "MONITOR",

        "startup/startup-monitor.lua"

    )

else

    print("")
    print(
        "Instalacion cancelada."
    )

end