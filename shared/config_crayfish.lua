Config = Config or {}

Config.Crayfish = {
    enabled = true,

    -- Сценарий из оригинального crayfish_search.ysc.c.
    -- Анимацию "рука в норе" запускает сам движок по этому scenario point.
    scenarioHash = `RANSACK_REACH_IN_CRAYSISH_HOLE`,

    -- Объект рака, который оригинал создаёт у норы.
    crayfishModel = `p_crayfish01x`,

    -- Рак создаётся на groundZ + 0.1.
    crayfishZOffset = 0.1,

    -- Scenario point создаётся на Y - 0.3 относительно декали норы.
    scenarioYOffset = -0.3,

    -- Норы и их decal-хеши из оригинального скрипта.
    Holes = {
        {
            coords = vector3(2027.286011, -1722.365112, 40.638821),
            decal = `dis_bay_catfishhole01_decal`,
        },
        {
            coords = vector3(2045.317993, -1785.749268, 40.788002),
            decal = `dis_bay_catfishhole02_decal`,
        },
        {
            coords = vector3(2021.326294, -1789.359131, 40.571224),
            decal = `dis_bay_catfishhole03_decal`,
        },
        {
            coords = vector3(2087.084473, -1859.779785, 40.584389),
            decal = `dis_bay_catfishhole04_decal`,
        },
        {
            coords = vector3(2058.207764, -1866.672729, 40.555130),
            decal = `dis_bay_catfishhole05_decal`,
        },
        {
            coords = vector3(2042.217407, -1885.945679, 40.370936),
            decal = `dis_bay_catfishhole06_decal`,
        },
        {
            coords = vector3(1672.226685, -826.944336, 39.949604),
            decal = `dis_bay_catfishhole07_decal`,
        },
        {
            coords = vector3(1710.451538, -850.612122, 40.295162),
            decal = `dis_bay_catfishhole08_decal`,
        },
        {
            coords = vector3(1693.836792, -942.689819, 40.499973),
            decal = `dis_bay_catfishhole09_decal`,
        },
        {
            coords = vector3(1756.401123, -1017.802368, 40.911179),
            decal = `dis_bay_catfishhole10_decal`,
        },
        {
            coords = vector3(2339.417480, -544.361145, 40.920261),
            decal = `dis_bay_catfishhole11_decal`,
        },
        {
            coords = vector3(2301.988525, -515.641907, 41.003044),
            decal = `dis_bay_catfishhole12_decal`,
        },
        {
            coords = vector3(2253.820312, -549.918213, 40.702431),
            decal = `dis_bay_catfishhole13_decal`,
        },
        {
            coords = vector3(2281.212402, -640.506470, 40.693916),
            decal = `dis_bay_catfishhole14_decal`,
        },
        {
            coords = vector3(2216.071045, -679.224915, 40.724941),
            decal = `dis_bay_catfishhole15_decal`,
        },
        {
            coords = vector3(2176.333984, -693.790283, 40.765686),
            decal = `dis_bay_catfishhole16_decal`,
        },
        {
            coords = vector3(2258.766602, -720.280701, 40.503241),
            decal = `dis_bay_catfishhole17_decal`,
        },
    },
}