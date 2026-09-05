Config = {}

Config.Locale = 'en'

-- The DOJ job name as registered in VORP's jobs table.
-- Must match exactly what's in your vorp_character / job setup.
Config.JobName = 'doj'

-- Courthouse blip + duty NPC. Interacting with the NPC opens the Duty Book.
Config.Courthouse = {
    blip = {
        enabled = true,
        sprite  = 'blip_ambient_law',
        label   = 'Courthouse',
        coords  = vector3(-275.0, 793.0, 119.0)
    },
    npc = {
        enabled          = false,
        model            = 'cs_mp_marshalldavies',
        coords           = vector4(-275.0, 793.0, 118.0, 90.0),
        interactDistance = 2.5,
        promptLabel      = 'Duty Book'
    }
}

Config.Grades = {
    [0] = { label = 'Prosecutor',       salary = 0.66,  isBoss = false, canJudge = false },
    [1] = { label = 'Clerk',            salary = 0.74,  isBoss = false,  canJudge = false },
    [2] = { label = 'Judge',            salary = 1.0, isBoss = true,  canJudge = true  },
    [3] = { label = 'Chief Justice',    salary = 1.14, isBoss = true,  canJudge = true  }
}

-- Salary tick in minutes.
Config.SalaryInterval = 1

-- Courtroom zones. The gavel only works from inside one of these.
Config.Courtrooms = {
    {
        name   = 'Saint Denis Courtroom',
        coords = vector3(-280.0, 815.0, 119.0),
        radius = 12.0
    }
}

-- Commands. Both open NUI menus; no direct-action commands.
Config.Commands = {
    judge    = 'judge',     -- opens Judge's Bench (Strike Gavel)
    dutybook = 'dojduty'   -- opens Duty Book (toggle duty + roster + kick)
}

-- HUD position (normalized 0.0 - 1.0)
Config.HUD = {
    x = 0.012,
    y = 0.915,
    scale = 0.35,
    color = { 240, 240, 240, 220 }
}

-- Discord webhooks (empty string = disabled)
Config.Webhooks = {
    duty   = '',
    kick   = '',
    lawyer = ''   -- hires, fires, bills (issued/paid/denied/expired) + ledger withdrawals
}

Config.WebhookName   = 'DOJ Logs'
Config.WebhookAvatar = ''

-- Lawyers — a register of players (by character id) who receive lawyer alerts
-- WITHOUT needing the DOJ job. Managed by DOJ bosses via /lawyerhire & /lawyerfire.
Config.Lawyers = {
    -- Command names
    hireCommand  = 'lawyerhire',   -- /lawyerhire [server id]            (DOJ boss only)
    fireCommand  = 'lawyerfire',   -- /lawyerfire [server id | char id]  (DOJ boss only)
    alertCommand = 'lawyeralert',  -- /lawyeralert [message]             (anyone)
    menuCommand  = 'lawyermenu',   -- /lawyermenu                        (lawyers only)
    billCommand  = 'lawyerbill',   -- /lawyerbill                        (lawyers only)

    -- On-duty DOJ members also count as lawyers (receive alerts + open the menu).
    includeOnDutyDoj = false,

    -- Seconds a player must wait between sending alerts (anti-spam).
    alertCooldown = 30,

    -- How many recent alerts to keep and show in the menu.
    maxStoredAlerts = 25,

    -- Seconds the "Locate" map blip stays after a lawyer clicks it.
    locateBlipTime = 600,

    -- Billing + ledger --------------------------------------------------------
    -- Lawyers open the billing/ledger NUI with /lawyerbill, or from a world
    -- prompt at these spots. Add as many locations as you like.
    menuLocations = {
        vector3(-275.0, 793.0, 119.0),   -- Saint Denis courthouse (example)
    },
    promptDistance = 2.0,            -- how close (metres) the prompt appears
    promptLabel    = 'Law Office',   -- prompt text

    maxBill          = 0,    -- largest a single bill may charge (0 = no limit)
    billTimeout      = 60,   -- seconds the recipient has to accept/deny
    maxLedgerHistory = 20    -- transactions shown in the ledger history list
}
