-- ============================================================
-- PAISACRAFT
-- CONFIGURACION GENERAL v6.1.5
-- ============================================================

local config = {}

-- ============================================================
-- PROYECTO
-- ============================================================

config.PROJECT_NAME = "PaisaCraft"
config.VERSION = "6.1.5"

config.ROOT =
    "/PaisaCraft"

-- ============================================================
-- REDNET
-- ============================================================

config.PROTOCOL =
    "builder_net"

config.CENTRAL_HOSTNAME =
    "builder-central"

config.HEARTBEAT_INTERVAL = 5

config.WORKER_TIMEOUT = 30

config.RESERVATION_TIMEOUT = 30

-- ============================================================
-- ARCHIVOS
-- ============================================================

config.DATA_DIR =
    config.ROOT
    ..
    "/data"

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

config.SETTINGS_FILE =
    config.DATA_DIR
    ..
    "/settings.cfg"

-- ============================================================
-- GPS
-- ============================================================

config.GPS_TIMEOUT = 5

config.GPS_SYNC_INTERVAL = 40

-- ============================================================
-- NAVEGACION
-- ============================================================

config.MAX_NAV_STEPS = 5000

config.MAX_POSITION_VISITS = 6

-- ============================================================
-- ENTIDADES
-- ============================================================

config.ENTITY_RETRIES = 3

config.ENTITY_WAIT = 0.25

-- ============================================================
-- GUARDADO
-- ============================================================

config.SAVE_INTERVAL = 10

-- ============================================================
-- ESTACIONES
-- ============================================================

config.STOCK_WAIT = 3

-- ============================================================
-- INVENTARIO
-- ============================================================

config.SLOT_FIRST = 1
config.SLOT_LAST = 16

config.BUILD_SLOT_FIRST = 1
config.BUILD_SLOT_LAST = 15

-- Slot reservado para material retirado.
config.RESERVED_SLOT = 16

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

-- ============================================================
-- COMBUSTIBLE
-- ============================================================

config.MIN_FUEL = 500

config.TARGET_FUEL = 3000

config.FUEL_SAFETY_MARGIN = 200

-- ============================================================
-- MODOS
-- ============================================================

config.BUILD_MODES = {

    PLACE = "PLACE",

    REPLACE = "REPLACE",

    CLEAR = "CLEAR"

}

config.DEFAULT_BUILD_MODE =
    config.BUILD_MODES.PLACE

-- ============================================================
-- REPLACE
-- ============================================================

config.DEFAULT_REPLACE_FILTER = nil

-- ============================================================
-- DESCARGA
-- ============================================================

config.AUTO_UNLOAD = true

config.UNLOAD_THRESHOLD = 1.0

-- ============================================================
-- RESTOCK
-- ============================================================

config.AUTO_RESTOCK = true

config.BATCH_BLOCK_LIMIT =
    config.MAX_BUILD_BLOCKS

-- ============================================================
-- DEBUG
-- ============================================================

config.DEBUG = false

return config
