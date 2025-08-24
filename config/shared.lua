return {
    combat = {
        enabled = true,
        menuKey = 'F6',
        exitKey = 'ESC',

        disableControls = {
            30, 31, 32, 33, 34, 35,  -- A, D, W, S, shift, ctrl
            36,  -- CTRL
            21,  -- SHIFT
            22,  -- SPACE
            -- Attack controls (we'll read these via IsDisabledControlPressed)
            24, 25,  -- LMB, RMB
            237, 238,  -- Alternative mouse controls
            -- Weapons and other controls
            37, 44,  -- TAB, Q
            -- Other controls
            18, 19, 20,  -- Enter, N, Y
            200, 202,  -- ESC, BACKSPACE
            177,  -- ESC (alternative)
            75,  -- F
            27, 23, 71, 72, 63, 64, 65, 66, 67, 68, 69, 70,  -- Car controls
            -- Weapon wheel
            12, 13, 14, 15, 16, 17,  -- Weapon selection
            -- Character controls
            38, 47, 74, 51, 52, 77, 137, 138,  -- E, G, H, Q, E, etc
            -- Phone and radio
            288, 289, 170,  -- Phone, radio
        },

        cameraRotationSpeed = 2.0,

        animationTimeout = {
            idle = 1000,
            movement = 100,
            attack = 200,
            dodge = 600,
        },
    },

    animations = {
        dict = 'r9@sword@locomotion@root@one',

        idle = {
            name = 'w_idle',
            loop = true,
            flag = 1,
        },

        holsterOn = {
            name = 'holster_on',
            loop = false,
            flag = 0,
        },

        holsterOff = {
            name = 'holster_off',
            loop = false,
            flag = 0,
        },

        movement = {
            forward = {
                name = 'w_forward',
                loop = true,
                flag = 1,
            },
            backward = {
                name = 'w_bwd',
                loop = true,
                flag = 1,
            },
            left = {
                name = 'w_left',
                loop = true,
                flag = 1,
            },
            right = {
                name = 'w_right',
                loop = true,
                flag = 1,
            },
        },

        attacks = {
            {
                dict = 'r9@sword@atk@root@one',
                name = 'kick',
                duration = 800,
                flag = 0,
            },
            {
                dict = 'r9@sword@atk@root@one',
                name = 'move_med',
                duration = 1000,
                flag = 0,
            },
            {
                dict = 'r9@sword@atk@root@one',
                name = 'move_med_down_l',
                duration = 1200,
                flag = 0,
            },
            {
                dict = 'r9@sword@atk@root@one',
                name = 'move_slow_lup',
                duration = 1400,
                flag = 0,
            },
            {
                dict = 'r9@sword@atk@root@one',
                name = 'move_slow_rdown',
                duration = 1300,
                flag = 0,
            },
            {
                dict = 'r9@sword@atk@root@one',
                name = 'move_strong_ldown',
                duration = 1500,
                flag = 0,
            },
        },

        dodges = {
            backward = {
                dict = 'r9@sword@dodge@root@one',
                name = 'dodge_bkw',
                duration = 600,
                flag = 0,
            },
            left = {
                dict = 'r9@sword@dodge@root@one',
                name = 'dodge_l',
                duration = 600,
                flag = 0,
            },
            right = {
                dict = 'r9@sword@dodge@root@one',
                name = 'dodge_r',
                duration = 600,
                flag = 0,
            },
        },

        hitReactions = {
            head = {
                dict = 'r9@sword@hitreact@root@one',
                name = 'hit_head_front',
                duration = 1000,
                flag = 0,
            },
            torsoRight = {
                dict = 'r9@sword@hitreact@root@one',
                name = 'hit_torso_right',
                duration = 800,
                flag = 0,
            },
            torsoLeft = {
                dict = 'r9@sword@hitreact@root@one',
                name = 'hit_torso_left',
                duration = 800,
                flag = 0,
            },
            torsoFront = {
                dict = 'r9@sword@hitreact@root@one',
                name = 'hit_torso_front',
                duration = 800,
                flag = 0,
            },
        },
    },

    controls = {
        forward = 32,    -- W
        backward = 33,   -- S
        left = 34,       -- A
        right = 35,      -- D

        attack = 24,     -- LMB (Left Mouse Button)
        heavyAttack = 25, -- RMB (Right Mouse Button)

        dodge = 22,      -- SPACE

        block = 21,      -- SHIFT

        exit = 200,      -- ESC
    },
}