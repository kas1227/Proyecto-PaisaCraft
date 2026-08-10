-- ============================================================
-- PAISACRAFT
-- ACTUALIZADOR DESDE GITHUB v6.1.4
-- ============================================================

local config =
    require("lib.config")

local utils =
    require("lib.utils")

-- ============================================================
-- MANIFEST
-- ============================================================

local FILES = {

    "central.lua",
    "worker.lua",
    "monitor.lua",

    "install.lua",
    "update.lua",

    "startup/startup-worker.lua",
    "startup/startup-central.lua",
    "startup/startup-monitor.lua",

    "lib/config.lua",
    "lib/utils.lua",
    "lib/protocol.lua",
    "lib/state.lua",
    "lib/gps.lua",
    "lib/movement.lua",
    "lib/navigation.lua",
    "lib/inventory.lua",
    "lib/stations.lua",
    "lib/builder.lua",
    "lib/fuel.lua",
    "lib/jobs.lua"

}

-- ============================================================
-- SETTINGS
-- ============================================================

local function loadSettings()

    return
        utils.loadTable(
            config.SETTINGS_FILE
        )
        or
        {}

end


local function saveSettings(
    settings
)

    utils.ensureDirectory(
        config.DATA_DIR
    )

    return utils.saveTable(

        config.SETTINGS_FILE,

        settings

    )

end

-- ============================================================
-- NORMALIZAR BASE URL
-- ============================================================

local function normalizeBaseURL(
    url
)

    while
        string.sub(
            url,
            -1
        )
        ==
        "/"
    do

        url =
            string.sub(
                url,
                1,
                -2
            )

    end

    return url

end

-- ============================================================
-- CONFIGURAR GITHUB
-- ============================================================

local function getBaseURL()

    local settings =
        loadSettings()

    if
        settings.githubRawBase
        and
        settings.githubRawBase
        ~= ""
    then

        return
            normalizeBaseURL(
                settings.githubRawBase
            )

    end

    print("")
    print("==============================")
    print("      CONFIGURAR GITHUB")
    print("==============================")

    print("")
    print(
        "Introduce la URL RAW base."
    )

    print("")
    print(
        "Ejemplo:"
    )

    print(
        "https://raw.githubusercontent.com/"
    )

    print(
        "usuario/repositorio/main/PaisaCraft"
    )

    print("")
    write("> ")

    local url =
        read()

    if
        not url
        or
        url == ""
    then

        return nil

    end

    url =
        normalizeBaseURL(
            url
        )

    settings.githubRawBase =
        url

    saveSettings(
        settings
    )

    return url

end

-- ============================================================
-- CREAR DIRECTORIO PADRE
-- ============================================================

local function ensureParent(
    filename
)

    local directory =
        fs.getDir(
            filename
        )

    if
        directory
        and
        directory ~= ""
        and
        not fs.exists(directory)
    then

        fs.makeDir(
            directory
        )

    end

end

-- ============================================================
-- DESCARGAR
-- ============================================================

local function downloadFile(
    baseURL,
    filename
)

    local url =
        baseURL
        ..
        "/"
        ..
        filename

    print("")
    print(
        "Descargando:"
    )

    print(
        filename
    )

    local response,
        errorMessage =
        http.get(
            url
        )

    if not response then

        return false,
            errorMessage
            or
            "HTTP_ERROR"

    end

    local data =
        response.readAll()

    response.close()

    if
        not data
        or
        data == ""
    then

        return false,
            "ARCHIVO_VACIO"

    end

    -- ========================================================
    -- ARCHIVO TEMPORAL
    --
    -- No sobrescribimos directamente el archivo bueno.
    -- ========================================================

    local temporary =
        filename
        ..
        ".update"

    ensureParent(
        temporary
    )

    local file =
        fs.open(
            temporary,
            "w"
        )

    if not file then

        return false,
            "NO_PUEDO_ESCRIBIR"

    end

    file.write(
        data
    )

    file.close()

    -- ========================================================
    -- REEMPLAZAR
    -- ========================================================

    if fs.exists(filename) then

        fs.delete(
            filename
        )

    end

    fs.move(
        temporary,
        filename
    )

    return true

end

-- ============================================================
-- ACTUALIZAR STARTUP INSTALADO
-- ============================================================

local function reinstallStartup()

    local settings =
        loadSettings()

    local role =
        settings.role

    local source = nil

    if role == "WORKER" then

        source =
            "startup/startup-worker.lua"

    elseif role == "CENTRAL" then

        source =
            "startup/startup-central.lua"

    elseif role == "MONITOR" then

        source =
            "startup/startup-monitor.lua"

    end

    if not source then

        print("")
        print(
            "Rol no configurado."
        )

        return

    end

    if not fs.exists(source) then

        print("")
        print(
            "Startup actualizado no encontrado."
        )

        return

    end

    if fs.exists(
        "startup.lua"
    )
    then

        fs.delete(
            "startup.lua"
        )

    end

    fs.copy(
        source,
        "startup.lua"
    )

    print("")
    print(
        "startup.lua actualizado."
    )

end

-- ============================================================
-- MAIN
-- ============================================================

term.clear()
term.setCursorPos(
    1,
    1
)

print("==============================")
print("       PAISACRAFT UPDATE")
print("==============================")

print("")
print(
    "Version actual:",
    config.VERSION
)

local baseURL =
    getBaseURL()

if not baseURL then

    print("")
    print(
        "Actualizacion cancelada."
    )

    return

end

print("")
print(
    "Origen:"
)

print(
    baseURL
)

print("")
print(
    "¿Actualizar? (s/n)"
)

write("> ")

if
    string.lower(
        read()
    )
    ~=
    "s"
then

    print("")
    print(
        "Cancelado."
    )

    return

end

-- ============================================================
-- DESCARGAR TODOS
-- ============================================================

local success = 0
local failed = {}

for _, filename
    in ipairs(FILES)
do

    local ok, err =
        downloadFile(
            baseURL,
            filename
        )

    if ok then

        success =
            success + 1

        print(
            "OK"
        )

    else

        table.insert(
            failed,
            {
                file = filename,
                error = err
            }
        )

        print(
            "ERROR:",
            tostring(err)
        )

    end

end

-- ============================================================
-- STARTUP
-- ============================================================

reinstallStartup()

-- ============================================================
-- RESULTADO
-- ============================================================

print("")
print("==============================")
print("       ACTUALIZACION")
print("==============================")

print("")
print(
    "Correctos:",
    success
)

print(
    "Errores:",
    #failed
)

if #failed > 0 then

    print("")
    print(
        "Archivos con error:"
    )

    for _, item
        in ipairs(failed)
    do

        print(
            item.file
        )

        print(
            "  ",
            tostring(
                item.error
            )
        )

    end

    print("")
    print(
        "NO reinicies todavía."
    )

    return

end

print("")
print(
    "Actualizacion completa."
)

print("")
print(
    "Reiniciando en 3 segundos..."
)

sleep(3)

os.reboot()