return {
    client = {
        debug = true,

        notifications = {
            enabled = true,
            position = 'top',
            duration = 3000,
        },

        effects = {
            combatEnter = false,
            combatExit = false,
            attackEffect = false,
            damageEffect = 'DrugsMichaelAliensFight',
        },

        camera = {
            distance = 3.5,

            height = 0.5,

            fov = 80.0,

            smoothness = 0.1,
        },

        ui = {
            showInstructions = true,

            instructionsPosition = { x = 0.1, y = 0.1 },

            colors = {
                primary = { r = 255, g = 255, b = 255, a = 255 },
                secondary = { r = 200, g = 200, b = 200, a = 255 },
                danger = { r = 255, g = 100, b = 100, a = 255 },
                success = { r = 100, g = 255, b = 100, a = 255 },
            },
        },

        sounds = {
            enabled = true,

            combatEnter = 'WEAPON_PURCHASE',
            combatExit = 'CANCEL',

            attack = 'PUNCH_01',
            heavyAttack = 'PUNCH_02',

            block = 'WEAPON_BLADE_DRAW',
            dodge = 'WEAPON_BLADE_SHEATH',
        },

        performance = {
            movementUpdateRate = 50,

            cameraUpdateRate = 16,

            syncDistance = 50.0,
        },
    },
}