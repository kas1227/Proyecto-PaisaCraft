-- ============================================================
-- PAISACRAFT
-- SETUP / BOOTSTRAP
-- ============================================================

local GITHUB_USER =
    "kas1227"

local GITHUB_REPO =
    "Proyecto-PaisaCraft"

local GITHUB_BRANCH =
    "main"

local ROOT =
    "/PaisaCraft"

local BASE_URL =
    "https://raw.githubusercontent.com/"
    .. GITHUB_USER
    .. "/"
    .. GITHUB_REPO
    .. "/"
    .. GITHUB_BRANCH
    .. "/PaisaCraft"

-- ============================================================
-- ARCHIVOS DEL PROYECTO
-- ============================================================

local FILES = {

    -- Programas principales
    "central.lua",
    "worker.lua",
    "monitor.lua",

    -- Instalacion / update
    "install.lua",
    "update.lua",

    -- Startup
    "startup/startup-worker.lua",
    "startup/startup-central.lua",
    "startup/startup-monitor.lua",

    -- Librerias
    "lib/builder.lua",
    "lib/config.lua",
    "lib/fuel.lua",
    "lib/gps.lua",
    "lib/inventory.lua",
    "lib/jobs.lua",
    "lib/movement.lua",
    "lib/navigation.lua",
    "lib/protocol.lua",
    "lib/state.lua",
    "lib/stations.lua",
    "lib/utils.lua"

}

-- ============================================================
-- CREAR DIRECTORIO PADRE
-- ============================================================

local function ensureParent(path)

    local directory =
        fs.getDir(path)

    if
        directory
        and
        directory ~= ""
        and
        not fs.exists(directory)
    then

        fs.makeDir(directory)

    end

end

-- ============================================================
-- DESCARGAR ARCHIVO
-- ============================================================

local function downloadFile(
    relativePath
)

    local url =
        BASE_URL
        ..
        "/"
        ..
        relativePath

    local destination =
        ROOT
        ..
        "/"
        ..
        relativePath

    print("")
    print(
        "Descargando:"
    )

    print(
        relativePath
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

    local content =
        response.readAll()

    response.close()

    if
        not content
        or
        content == ""
    then

        return false,
            "ARCHIVO_VACIO"

    end

    ensureParent(
        destination
    )

    local temporary =
        destination
        ..
        ".download"

    if fs.exists(temporary) then
        fs.delete(temporary)
    end

    local file =
        fs.open(
            temporary,
            "w"
        )

    if not file then

        return false,
            "NO_PUEDO_ESCRIBIR"

    end

    file.write(content)
    file.close()

    if fs.exists(destination) then
        fs.delete(destination)
    end

    fs.move(
        temporary,
        destination
    )

    return true

end

-- ============================================================
-- UI
-- ============================================================

term.clear()
term.setCursorPos(
    1,
    1
)

print("==============================")
print("       PAISACRAFT SETUP")
print("==============================")

print("")
print(
    "Repositorio:"
)

print(
    GITHUB_USER
    ..
    "/"
    ..
    GITHUB_REPO
)

print("")
print(
    "Destino:",
    ROOT
)

print("")
print(
    "Archivos:",
    #FILES
)

print("")
print(
    "¿Continuar? (s/n)"
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
-- CREAR ROOT
-- ============================================================

if not fs.exists(ROOT) then

    fs.makeDir(ROOT)

end

-- ============================================================
-- DESCARGAR TODO
-- ============================================================

local successful = 0
local errors = {}

for index, relativePath
    in ipairs(FILES)
do

    print("")
    print(
        "["
        ..
        index
        ..
        "/"
        ..
        #FILES
        ..
        "]"
    )

    local ok, err =
        downloadFile(
            relativePath
        )

    if ok then

        successful =
            successful + 1

        print(
            "OK"
        )

    else

        table.insert(
            errors,
            {
                file =
                    relativePath,

                error =
                    tostring(err)
            }
        )

        print(
            "ERROR:"
        )

        print(
            tostring(err)
        )

    end

end

-- ============================================================
-- RESULTADO
-- ============================================================

print("")
print("==============================")
print("          RESULTADO")
print("==============================")

print("")
print(
    "Correctos:",
    successful
)

print(
    "Errores:",
    #errors
)

if #errors > 0 then

    print("")
    print(
        "Archivos fallidos:"
    )

    for _, item
        in ipairs(errors)
    do

        print("")
        print(
            item.file
        )

        print(
            item.error
        )

    end

    print("")
    print(
        "No se ejecutara install.lua."
    )

    return

end

-- ============================================================
-- DATA
-- ============================================================

local dataDirectory =
    ROOT
    ..
    "/data"

if not fs.exists(dataDirectory) then

    fs.makeDir(
        dataDirectory
    )

end

-- ============================================================
-- EJECUTAR INSTALL
-- ============================================================

print("")
print("==============================")
print("      DESCARGA COMPLETA")
print("==============================")

print("")
print(
    "Iniciando install.lua..."
)

sleep(1)

shell.run(
    ROOT
    ..
    "/install.lua"
)
