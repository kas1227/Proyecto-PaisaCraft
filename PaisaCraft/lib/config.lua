-- ============================================================
-- PAISACRAFT
-- CONFIGURACION GENERAL v6.1.5
-- ============================================================

local config = {}

-- ============================================================
-- PROYECTO
-- ============================================================

config.PROJECT_NAME =
    "PaisaCraft"

config.VERSION =
    "6.1.5"

config.ROOT =
    "/PaisaCraft"

-- ============================================================
-- REDNET
-- ============================================================

config.PROTOCOL =
    "builder_net"

config.CENTRAL_HOSTNAME =
    "builder-central"

-- Cada cuantos segundos el worker anuncia
-- que sigue vivo.
config.HEARTBEAT_INTERVAL =
    5

-- Tiempo sin heartbeat antes de considerar
-- una turtle desconectada.
config.WORKER_TIMEOUT =
    30

-- Tiempo maximo que una turtle puede conservar
-- una reserva de estacion sin responder.
config.RESERVATION_TIMEOUT =
    30

-- ============================================================
-- ARCHIVOS / DATOS
-- ============================================================

config.DATA_DIR =
    config.ROOT
    ..
    "/data"

config.SETTINGS_FILE =
    config.DATA_DIR
    ..
    "/settings.cfg"

config.WORKER_STATE_FILE =
    config.DATA_DIR
    ..
    "/worker_state.cfg"

config.CENTRAL_CONFIG_FILE =
    config.DATA_DIR
    ..
    "/central.cfg"

config.MONITOR_CONFIG_FILE =
    config.DATA_DIR
    ..
    "/monitor.cfg"

-- ============================================================
-- GPS
-- ============================================================

config.GPS_TIMEOUT =
    5

-- Cada cuantos movimientos puede volver a
-- sincronizar posicion mediante GPS.
config.GPS_SYNC_INTERVAL =
    40

-- ============================================================
-- NAVEGACION
-- ============================================================

-- Limite de seguridad para evitar bucles
-- infinitos de navegacion.
config.MAX_NAV_STEPS =
    5000

-- Numero maximo de veces que puede visitar
-- una misma posicion antes de considerarla
-- potencialmente bloqueada.
config.MAX_POSITION_VISITS =
    6

-- ============================================================
-- ENTIDADES / OBSTACULOS
-- ============================================================

config.ENTITY_RETRIES =
    3

config.ENTITY_WAIT =
    0.25

-- ============================================================
-- GUARDADO
-- ============================================================

-- Para PLACE no necesitamos guardar
-- despues de absolutamente cada bloque.
config.SAVE_INTERVAL =
    10

-- ============================================================
-- ESTACIONES
-- ============================================================

-- Tiempo entre intentos cuando:
--
-- - no hay materiales
-- - no hay combustible
-- - la descarga esta llena
config.STOCK_WAIT =
    3

-- ============================================================
-- INVENTARIO
-- ============================================================

config.SLOT_FIRST =
    1

config.SLOT_LAST =
    16

-- ============================================================
-- SLOTS DE CONSTRUCCION
--
-- IMPORTANTISIMO:
--
-- El slot 16 NUNCA pertenece a este rango.
-- ============================================================

config.BUILD_SLOT_FIRST =
    1

config.BUILD_SLOT_LAST =
    15

-- ============================================================
-- SLOT RESERVADO
--
-- Se utiliza exclusivamente para los items
-- obtenidos al romper/reemplazar bloques.
-- ============================================================

config.RESERVED_SLOT =
    16

-- ============================================================
-- CAPACIDAD MAXIMA POR TANDA
--
-- 15 slots x 64 = 960 bloques
-- ============================================================

config.MAX_BUILD_BLOCKS =
    (
        config.BUILD_SLOT_LAST
        -
        config.BUILD_SLOT_FIRST
        +
        1
    )
    *
    64

-- El limite de tanda utiliza exactamente
-- la capacidad disponible para materiales.
config.BATCH_BLOCK_LIMIT =
    config.MAX_BUILD_BLOCKS

-- ============================================================
-- COMBUSTIBLE
-- ============================================================

-- Nunca queremos trabajar por debajo
-- de este nivel sin intentar servicio.
config.MIN_FUEL =
    500

-- Objetivo normal al repostar.
config.TARGET_FUEL =
    3000

-- Margen extra añadido a la estimacion
-- necesaria para regresar a servicio.
config.FUEL_SAFETY_MARGIN =
    200

-- ============================================================
-- MODOS DE TRABAJO
-- ============================================================

config.BUILD_MODES = {

    -- Coloca solamente donde haya aire.
    PLACE =
        "PLACE",

    -- Rompe el bloque existente
    -- y coloca el nuevo.
    REPLACE =
        "REPLACE",

    -- Solo rompe.
    CLEAR =
        "CLEAR"

}

config.DEFAULT_BUILD_MODE =
    config.BUILD_MODES.PLACE

-- ============================================================
-- REPLACE
-- ============================================================

-- nil =
-- se permite reemplazar cualquier bloque.
--
-- La asignacion puede proporcionar
-- su propio replaceFilter.
config.DEFAULT_REPLACE_FILTER =
    nil

-- ============================================================
-- DESCARGA
-- ============================================================

config.AUTO_UNLOAD =
    true

-- Conservamos esta variable por compatibilidad.
--
-- La nueva inventory.needsUnload()
-- considera que existe material pendiente
-- siempre que slot 16 contenga algo.
config.UNLOAD_THRESHOLD =
    1.0

-- ============================================================
-- RESTOCK
-- ============================================================

config.AUTO_RESTOCK =
    true

-- ============================================================
-- DEBUG
-- ============================================================

config.DEBUG =
    false

-- ============================================================
-- VALIDACION DE CONFIGURACION
--
-- Estas comprobaciones hacen que PaisaCraft
-- falle inmediatamente si accidentalmente
-- configuramos el slot reservado dentro de
-- los slots de construccion.
-- ============================================================

if
    config.RESERVED_SLOT
    >=
    config.BUILD_SLOT_FIRST
    and
    config.RESERVED_SLOT
    <=
    config.BUILD_SLOT_LAST
then

    error(
        "CONFIG ERROR: "
        ..
        "RESERVED_SLOT no puede estar "
        ..
        "dentro de BUILD_SLOT_FIRST..BUILD_SLOT_LAST"
    )

end

if
    config.BUILD_SLOT_FIRST
    <
    config.SLOT_FIRST
    or
    config.BUILD_SLOT_LAST
    >
    config.SLOT_LAST
then

    error(
        "CONFIG ERROR: "
        ..
        "rango de slots de construccion invalido"
    )

end

if
    config.BATCH_BLOCK_LIMIT
    <=
    0
then

    error(
        "CONFIG ERROR: "
        ..
        "BATCH_BLOCK_LIMIT debe ser mayor que 0"
    )

end

-- ============================================================
-- RETURN
-- ============================================================

return config
