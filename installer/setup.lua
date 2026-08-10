-- ============================================================
-- PAISACRAFT
-- SETUP / BOOTSTRAP
-- ============================================================

local GITHUB_USER =
    "TU_USUARIO"

local GITHUB_REPO =
    "Proyecto-Tortugas-Breteadoras"

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

    "install.lua",
    "update.lua",

    "central.lua",
    "worker.lua",
    "monitor.lua",

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
        .. "/"
        .. relativePath

    local destination =
        ROOT
        .. "/"
        .. relativePath

    print("")
    print(
        "Descargando:"
    )

    print(
        relativePath
    )

    -- ========================================================
    -- HTTP
    -- ========================================================

    local response,
        errorMessage =
        http.get(url)

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

    -- ========================================================
    -- DIRECTORIO
    -- ========================================================

    ensureParent(
        destination
    )

    -- ========================================================
    -- ARCHIVO TEMPORAL
    -- ========================================================

    local temporary =
        destination
        .. ".download"

    if fs.exists(temporary) then

        fs.delete(
            temporary
        )

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

    file.write(
        content
    )

    file.close()

    -- ========================================================
    -- REEMPLAZAR
    -- ========================================================

    if fs.exists(destination) then

        fs.delete(
            destination
        )

    end

    fs.move(
        temporary,
        destination
    )

    return true

end

-- ============================================================
-- ENCABEZADO
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
    .. "/"
    .. GITHUB_REPO
)

print("")
print(
    "Rama:",
    GITHUB_BRANCH
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

local answer =
    string.lower(
        read()
    )

if answer ~= "s" then

    print("")
    print(
        "Instalacion cancelada."
    )

    return

end

-- ============================================================
-- CREAR ROOT
-- ============================================================

if not fs.exists(ROOT) then

    fs.makeDir(
        ROOT
    )

end

-- ============================================================
-- DESCARGAR
-- ============================================================

local successful = 0

local errors = {}

for index, relativePath
    in ipairs(FILES)
do

    print("")
    print(
        "["
        .. index
        .. "/"
        .. #FILES
        .. "]"
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

-- ============================================================
-- ERRORES
-- ============================================================

if #errors > 0 then

    print("")
    print(
        "No se ejecutara install.lua."
    )

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
            "  "
            .. item.error
        )

    end

    print("")
    print(
        "Corrige los errores"
    )

    print(
        "y ejecuta setup de nuevo."
    )

    return

end

-- ============================================================
-- DATA
-- ============================================================

local dataDirectory =
    ROOT
    .. "/data"

if
    not fs.exists(
        dataDirectory
    )
then

    fs.makeDir(
        dataDirectory
    )

end

-- ============================================================
-- INSTALADOR
-- ============================================================

print("")
print("==============================")
print("      DESCARGA COMPLETA")
print("==============================")

print("")
print(
    "Iniciando instalador..."
)

sleep(1)

shell.run(
    ROOT
    .. "/install.lua"
)