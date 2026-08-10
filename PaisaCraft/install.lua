-- ============================================================
-- PAISACRAFT
-- INSTALADOR v6.1.4
-- ============================================================

local ROOT =
    "/PaisaCraft"

local DATA_DIR =
    ROOT
    .. "/data"

local SETTINGS_FILE =
    DATA_DIR
    .. "/settings.cfg"

local STARTUP_TARGET =
    "/startup.lua"

-- ============================================================
-- STARTUPS
-- ============================================================

local STARTUPS = {

    WORKER =
        ROOT
        .. "/startup/startup-worker.lua",

    CENTRAL =
        ROOT
        .. "/startup/startup-central.lua",

    MONITOR =
        ROOT
        .. "/startup/startup-monitor.lua"

}

-- ============================================================
-- CREAR DIRECTORIO
-- ============================================================

local function ensureDirectory(path)

    if fs.exists(path) then
        return true
    end

    fs.makeDir(path)

    return fs.exists(path)

end

-- ============================================================
-- GUARDAR TABLA
-- ============================================================

local function saveTable(
    filename,
    data
)

    local directory =
        fs.getDir(filename)

    if
        directory
        and
        directory ~= ""
    then

        ensureDirectory(
            directory
        )

    end

    local file =
        fs.open(
            filename,
            "w"
        )

    if not file then

        return false,
            "No puedo escribir "
            ..
            filename

    end

    file.write(
        textutils.serialize(
            data
        )
    )

    file.close()

    return true

end

-- ============================================================
-- GUARDAR CONFIGURACION
-- ============================================================

local function saveSettings(
    role
)

    ensureDirectory(
        DATA_DIR
    )

    return saveTable(

        SETTINGS_FILE,

        {
            role =
                role,

            computerID =
                os.getComputerID(),

            root =
                ROOT
        }

    )

end

-- ============================================================
-- INSTALAR STARTUP
-- ============================================================

local function installStartup(
    role
)

    local source =
        STARTUPS[role]

    if not source then

        return false,
            "ROL_INVALIDO"

    end

    print("")
    print("Startup origen:")
    print(source)

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

    if
        not fs.exists(
            STARTUP_TARGET
        )
    then

        return false,
            "No se pudo crear "
            ..
            STARTUP_TARGET

    end

    return true

end

-- ============================================================
-- INSTALAR ROL
-- ============================================================

local function installRole(
    role
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

    local startupOK,
        startupError =
        installStartup(
            role
        )

    if not startupOK then

        print("")
        print("ERROR startup:")
        print(
            tostring(
                startupError
            )
        )

        return false

    end

    local settingsOK,
        settingsError =
        saveSettings(
            role
        )

    if not settingsOK then

        print("")
        print("ERROR settings:")
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
        "Computer ID:",
        os.getComputerID()
    )

    print("")
    print(
        "/startup.lua creado."
    )

    print("")
    print(
        "Reinicia con:"
    )

    print("")
    print("reboot")

    return true

end

-- ============================================================
-- MENU
-- ============================================================

term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       PAISACRAFT INSTALL")
print("==============================")

print("")
print("Selecciona dispositivo:")
print("")
print("1. Worker")
print("2. Central")
print("3. Monitor")
print("4. Cancelar")
print("")

write("> ")

local option =
    read()

if option == "1" then

    installRole(
        "WORKER"
    )

elseif option == "2" then

    installRole(
        "CENTRAL"
    )

elseif option == "3" then

    installRole(
        "MONITOR"
    )

else

    print("")
    print(
        "Instalacion cancelada."
    )

end
