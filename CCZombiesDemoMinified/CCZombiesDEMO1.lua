local Pine3D = require("Pine3D")
local dfpwm  = require("cc.audio.dfpwm")
local ccz = require("CCZ_API")
_G.ccz = ccz
local _mapPalette = {}
local _origPaletteSet = ccz.palette and ccz.palette.set
if ccz.palette then
    ccz.palette.set = function(color, r, g, b)
        term.setPaletteColor(color, r, g, b)
        _mapPalette[color] = {r, g, b}
    end
    ccz.palette.reset = function()
        _mapPalette = {}
        local defaults = {
            [colors.white]={0.94,0.94,0.94},[colors.orange]={0.97,0.58,0.15},
            [colors.magenta]={0.75,0.30,0.76},[colors.lightBlue]={0.37,0.64,0.90},
            [colors.yellow]={0.97,0.97,0.15},[colors.lime]={0.44,0.84,0.22},
            [colors.pink]={0.96,0.48,0.76},[colors.gray]={0.30,0.30,0.30},
            [colors.lightGray]={0.60,0.60,0.60},[colors.cyan]={0.17,0.68,0.68},
            [colors.purple]={0.50,0.25,0.76},[colors.blue]={0.20,0.31,0.85},
            [colors.brown]={0.49,0.31,0.15},[colors.green]={0.19,0.50,0.19},
            [colors.red]={0.75,0.18,0.18},[colors.black]={0.11,0.11,0.11},
        }
        for col,rgb in pairs(defaults) do term.setPaletteColor(col,rgb[1],rgb[2],rgb[3]) end
    end
end
local _ccDefaults = {
    [colors.white]={0.94,0.94,0.94}, [colors.orange]={0.95,0.69,0.17},
    [colors.magenta]={0.89,0.40,0.82},[colors.lightBlue]={0.49,0.70,0.90},
    [colors.yellow]={0.98,0.90,0.24}, [colors.lime]={0.49,0.96,0.24},
    [colors.pink]={0.97,0.74,0.78},  [colors.gray]={0.50,0.50,0.50},
    [colors.lightGray]={0.75,0.75,0.75},[colors.cyan]={0.30,0.75,0.82},
    [colors.purple]={0.68,0.38,0.79},[colors.blue]={0.22,0.36,0.78},
    [colors.brown]={0.63,0.45,0.29}, [colors.green]={0.38,0.65,0.25},
    [colors.red]={0.93,0.25,0.25},   [colors.black]={0.06,0.06,0.06},
}
local function reapplyMapPalette()
    for color, rgb in pairs(_ccDefaults) do
        local override = _mapPalette[color]
        if override then
            term.setPaletteColor(color, override[1], override[2], override[3])
        else
            term.setPaletteColor(color, rgb[1], rgb[2], rgb[3])
        end
    end
end
local powerOn        = false
local hasPowerSwitch = false
local powerSwitches  = {}
local multiplayerState = {
    isMultiplayer = false,
    isHost = false,
    myPlayerID = nil,
    lobbyID = nil,
    players = {},
    lobby = {
        name = "",
        mapIndex = 1,
        players = {},
        maxPlayers = 4,
        started = false
    },
    WS_URL = "wss://call-of-cc-zombies.onrender.com",
    ws = nil,
    wsConnected = false,
    wsMessageQueue = {},
    leaderboardData = nil
}
local WS_URL = multiplayerState.WS_URL
local isHost, myPlayerID, lobbyID, players, lobby, leaderboardData
local function updateMultiplayerAliases()
    isHost = multiplayerState.isHost
    myPlayerID = multiplayerState.myPlayerID
    lobbyID = multiplayerState.lobbyID
    players = multiplayerState.players
    lobby = multiplayerState.lobby
    leaderboardData = multiplayerState.leaderboardData
end
local gameStateVars = {
    current = "main_menu",
    pauseMenuOption = 1,
    gameMode = nil,
    currentMap = nil,
    mapData = nil,
    availableMaps = {},
    powerOn = false,
    hasPowerSwitch = false,
    powerSwitches = {}
}
local gameMode, availableMaps, pauseMenuOption, powerSwitches
local function updateGameStateAliases()
    gameMode = gameStateVars.gameMode
    availableMaps = gameStateVars.availableMaps
    pauseMenuOption = gameStateVars.pauseMenuOption
    powerSwitches = gameStateVars.powerSwitches
end
local PERK_COSTS = {
    perk_juggernog = 2500,
    perk_speedcola = 3000,
    perk_revive = function()
        if multiplayerState.isMultiplayer then return 1500 end
        local uses = player.quickReviveUses or 0
        return uses == 0 and 500 or uses == 1 and 1000 or 1500
    end,
    perk_staminup = 2000,
    perk_whoswho = 2000,
    perk_phd = 2000,
    perk_mulekick = 4000,
    perk_cherry = 2000,
    perk_doubletap = 2000
}
local PERK_JINGLES = {
    perk_revive = "-XDoiXkkP4k",
    perk_juggernog = "m6V2aw0shfo",
    perk_speedcola = "mR16k1y07P0",
    perk_mulekick = "CBpM7qasA4U",
    perk_whoswho = "21fl-DQ1U5A",
    pack_a_punch = "MtnEYpbhW1o",
    perk_cherry = "U_JMGGZLZPk",
    perk_phd = "BrqmNBVUDMA",
    perk_staminup = "QKWimJqku54",
    perk_doubletap = "BWo2SG828G8"
}
local WEAPONS = {
    m1911 = {
        id = "m1911",
        name = "M1911",
        type = "pistol",
        damage = 35,
        rpm = 300,
        mag = 8 * 2,
        reserve = 24 * 2,
        reloadTime = 1.6,
        spawn = "starting",
        isBox = false,
        fireMode = "semi",
        penetration = 0,
        recoil = 1.5,
        papName = "Mustang & Sally",
        papDamage = 105,
        papMag = 12 * 2,
        papReserve = 36 * 2
    },
    standard_lmg = {
        id = "standard_lmg",
        name = "Standard L.M.G.",
        type = "lmg",
        damage = 28,
        rpm = 650,
        mag = 100 * 2,
        reserve = 200 * 2,
        reloadTime = 4.0,
        spawn = "box",
        isBox = true,
        fireMode = "auto",
        penetration = 1,
        recoil = 0.6,
        papName = "115 Infused LMG",
        papDamage = 84,
        papMag = 150 * 2,
        papReserve = 300 * 2
    },
    ballista_sniper = {
        id = "ballista_sniper",
        name = "Ballista",
        type = "sniper",
        damage = 950,
        rpm = 50,
        mag = 5 * 2,
        reserve = 15 * 2,
        reloadTime = 2.8,
        spawn = "box",
        isBox = true,
        fireMode = "semi",
        penetration = -1,
        recoil = 3.5,
        papName = "Skull Crusher",
        papDamage = 2850,
        papMag = 8 * 2,
        papReserve = 24 * 2
    },
    ak47 = {
        id = "ak47",
        name = "AK-47",
        type = "assault",
        damage = 38,
        rpm = 600,
        mag = 30 * 2,
        reserve = 120 * 2,
        reloadTime = 2.6,
        spawn = "box",
        isBox = true,
        fireMode = "auto",
        penetration = 1,
        recoil = 1.0,
        papName = "Reznov's Revenge",
        papDamage = 114,
        papMag = 45 * 2,
        papReserve = 180 * 2
    },
    uzi_md = {
        id = "uzi_md",
        name = "Uzi-M.D.",
        type = "smg",
        damage = 18,
        rpm = 900,
        mag = 40 * 2,
        reserve = 160 * 2,
        reloadTime = 2.0,
        spawn = "box",
        isBox = true,
        custom = true,
        fireMode = "auto",
        penetration = 2,
        recoil = 0.5,
        papName = "Uzi & N",
        papDamage = 54,
        papMag = 60 * 2,
        papReserve = 240 * 2
    },
    raygun = {
        id = "raygun",
        name = "Ray Gun",
        type = "energy",
        damage = 250,
        rpm = 280,
        mag = 20 * 2,
        reserve = 80 * 2,
        reloadTime = 3.0,
        spawn = "box",
        isBox = true,
        splash = 50,
        fireMode = "semi",
        penetration = 0,
        recoil = 2.0,
        papName = "Dr N's Ray Gun",
        papDamage = 750,
        papMag = 30 * 2,
        papReserve = 120 * 2
    }
}
local weapon = {}
function weapon.createPlayerWeaponInstance(weaponId)
    local template = WEAPONS[weaponId]
    if not template then return nil end
    return {
        id = template.id,
        name = template.name,
        damage = template.damage,
        rpm = template.rpm,
        mag = template.mag,
        ammo = template.mag,
        reserve = template.reserve,
        reloadTime = template.reloadTime,
        lastFireTime = 0,
        fireMode = template.fireMode,
        penetration = template.penetration,
        recoil = template.recoil,
        splash = template.splash,
        isReloading = false,
        reloadEndTime = 0
    }
end
local player = {
    x = 0, y = 1, z = 0,
    rotX = 0, rotY = 0, rotZ = 0,
    velocityY = 0,
    onGround = false,
    health = 100,
    maxHealth = 100,
    points = 500,
    weapon = "pistol",
    ammo = 8,
    kills = 0,
    lastHitTime = 0,
    perks = {},
    height = 2,
    eyeHeight = 1.6,
    color = colors.blue,
    username = "",
    stats = {
        shotsFired = 0,
        shotsHit = 0,
        headshots = 0,
        downs = 0,
        revives = 0,
        damageDealt = 0,
        damageTaken = 0
    },
    weapons = {},
    maxWeaponSlots = 2,
    activeWeaponSlot = 1,
    firing = false,
    firedOnThisClick = false,
    recoil = 0,
    inAfterlife = false,
    afterlifeBodyPos = nil,
    afterlifePerks = {},
    afterlifeTimeLeft = 30,
    isDowned = false,
    downedTime = 0,
    bleedoutTime = 45,
    reviveProgress = 0,
    reloadMultiplier = 1,
    moveSpeedMultiplier = 1,
    quickReviveUses = 0,
    lastMeleeTime   = 0
}
player.weapons[1] = weapon.createPlayerWeaponInstance("m1911")
player.weapons[2] = nil
local camera = {x = 0, y = 1, z = 0, rotX = 0, rotY = 0, rotZ = 0}
local keysDown = {}
local keysJustPressed = {}
local targetRotY = 0
local targetRotZ = 0
local frame = Pine3D.newFrame()
local collisionMask = {}
local worldChunks = {}
local CHUNK_SIZE = 16
local zombies = {}
local zombieSpawns = {}
local MAX_ZOMBIES_ALIVE = 24
local roundState = {
    currentRound = 1,
    zombiesThisRound = 0,
    zombiesSpawned = 0,
    zombiesKilled = 0,
    roundActive = false,
    roundEndTime = 0,
    spawnDelay = 2,
    lastSpawnTime = 0,
    panzerSpawnedThisRound = false
}
local doors = {}
local doorBlocks = {}
local solidBlocks = {}
local stamina        = 1.0
local isSprinting    = false
local openedDoorMeshKeys = {}
local _ffBuild = nil
local playerColors = {
    colors.blue, colors.red, colors.green, colors.yellow,
    colors.purple, colors.cyan, colors.orange, colors.pink
}
local CHARACTERS = {
    { id = "DrNightheart",    name = "Dr. Nightheart"   },
    { id = "ArissNightheart", name = "Ariss Nightheart" },
    { id = "Bayard",          name = "Bayard"           },
    { id = "AliceE",          name = "Alice E."         },
}
local playerCharacter = nil
local loadedGunModels = {}
local takenCharacters = {}
local function assignCharacter()
    local available = {}
    for _, ch in ipairs(CHARACTERS) do
        if not takenCharacters[ch.id] or takenCharacters[ch.id] == myPlayerID then
            available[#available+1] = ch
        end
    end
    if #available == 0 then available = CHARACTERS end
    if playerCharacter then
        for _, ch in ipairs(available) do
            if ch.id == playerCharacter.id then return playerCharacter end
        end
    end
    local chosen = available[math.random(1, #available)]
    playerCharacter = chosen
    takenCharacters[chosen.id] = myPlayerID
    return chosen
end
local function loadGunModel(weaponId)
    if not playerCharacter then return nil end
    local charId = playerCharacter.id
    if not loadedGunModels[weaponId] then loadedGunModels[weaponId] = {} end
    local cached = loadedGunModels[weaponId][charId]
    if cached ~= nil then return cached or nil end
    local paths = {
        "guns/" .. weaponId .. "_" .. charId .. ".nfp",
        "guns/" .. weaponId .. ".nfp",
    }
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local img = paintutils.loadImage(path)
            if img then
                loadedGunModels[weaponId][charId] = img
                return img
            end
        end
    end
    loadedGunModels[weaponId][charId] = false
    return nil
end
local muzzleTimer = 0
local hitMarkers = {}
local MAX_HIT_MARKERS = 4
local announceQueue   = {}
local pendingSoundRequests = {}
local roundTransition = {
    phase     = nil,
    round     = 0,
    startTime = 0,
    clearDur  = 2.5,
    incomeDur = 2.5,
}
local _boxWeightedPool = (function()
    local pool = {}
    for _, e in ipairs({
        {"standard_lmg",    "Standard L.M.G.", 12},
        {"ak47",            "AK-47",           12},
        {"uzi_md",          "Uzi-M.D.",        12},
        {"ballista_sniper", "Ballista",          8},
        {"raygun",          "Ray Gun",           2},
    }) do
        for _ = 1, e[3] do pool[#pool+1] = {id=e[1], name=e[2]} end
    end
    return pool
end)()
local boxRoll = {
    active    = false,
    elapsed   = 0,
    duration  = 3.0,
    chosen    = nil,
    display   = "",
    spinTimer = 0,
    spinRate  = 0.08,
    done      = false,
    doneTimer = 0,
    doneDur   = 1.5,
}
local function getZombieCount(round)
    return math.floor(0.0842 * round^2 + 0.1954 * round + 22.05)
end
local function getZombieHealth(round)
    if round <= 9 then
        return 50 + (round * 100)
    else
        return math.floor(950 * (1.1 ^ (round - 9)))
    end
end
local function getZombieSpeed(round)
    return math.min(0.35, 0.10 + (round - 1) * 0.025)
end
local function hasPerk(perkId)
    for _, p in ipairs(player.perks) do
        if p == perkId then return true end
    end
    return false
end
local function ensureMuleKickSlots()
    if hasPerk("perk_mulekick") and player.maxWeaponSlots < 3 then
        player.maxWeaponSlots = 3
        player.weapons[3] = player.weapons[3] or nil
    end
end
local function switchWeaponSlot(slot)
    ensureMuleKickSlots()
    if slot < 1 or slot > player.maxWeaponSlots then return end
    if not player.weapons[slot] then return end
    player.activeWeaponSlot = slot
    player.weapon = player.weapons[slot].id
    player.ammo = player.weapons[slot].ammo
end
local function giveWeaponToPlayer(weaponId, slot)
    ensureMuleKickSlots()
    local instance = weapon.createPlayerWeaponInstance(weaponId)
    if not instance then return false end
    if slot and slot >= 1 and slot <= player.maxWeaponSlots then
        player.weapons[slot] = instance
        return true
    end
    for i = 1, player.maxWeaponSlots do
        if not player.weapons[i] then
            player.weapons[i] = instance
            return true
        end
    end
    player.weapons[player.activeWeaponSlot] = instance
    return true
end
local function getActiveWeapon()
    return player.weapons[player.activeWeaponSlot]
end
local function drawGunModel()
    if player.isDowned or player.inAfterlife then return end
    local w = getActiveWeapon()
    if not w then return end
    local img = loadGunModel(w.id)
    if not img then return end
    local sw, sh = term.getSize()
    local imgH = #img
    local startY = sh - imgH + 1
    for row = 1, imgH do
        local line = img[row]
        if line then
            for col = 1, #line do
                local pixel = line[col]
                if pixel and pixel ~= 0 then
                    term.setCursorPos(col, startY + row - 1)
                    term.setBackgroundColor(pixel)
                    term.write(" ")
                end
            end
        end
    end
    term.setCursorPos(1, 1)
end
local function getCurrentTime()
    return os.epoch("utc") / 1000
end
local function zombieWithinRange(z, ox, oz, maxRange)
    local dx = (z.x - ox)
    local dz = (z.z - oz)
    return (dx*dx + dz*dz) <= (maxRange * maxRange)
end
function weapon.performSplashDamage(origin, radius, damage, srcWeapon)
    local ox, oy, oz = origin.x, origin.y, origin.z
    local radiusSq   = radius * radius
    for _, z in ipairs(zombies) do
        if z and z.health > 0 then
            local dx   = z.x - ox
            local dy   = (z.y + 0.9) - oy
            local dz   = z.z - oz
            local distSq = dx*dx + dy*dy + dz*dz
            if distSq <= radiusSq then
                local dist   = math.sqrt(distSq)
                local factor = 1 - (dist / radius)
                local dmg    = math.floor(damage * factor)
                if dmg > 0 then
                    z.health = z.health - dmg
                    if z.health <= 0 and not z._killedByPlayer and not z._killedByMelee then
                        z._killedBySplash = true
                    end
                end
            end
        end
    end
    if not player._godMode then
        local pdx    = player.x - ox
        local pdy    = (player.y + player.eyeHeight) - oy
        local pdz    = player.z - oz
        local pDistSq = pdx*pdx + pdy*pdy + pdz*pdz
        if pDistSq <= radiusSq then
            local pDist  = math.sqrt(pDistSq)
            local factor = math.max(0, 1 - (pDist / radius))
            local selfDmg = math.floor(damage * factor)
            if selfDmg > 0 then
                player.health      = player.health - selfDmg
                player.lastHitTime = getCurrentTime()
                player.stats.damageTaken = player.stats.damageTaken + selfDmg
                table.insert(hitMarkers, {
                    text   = "SELF -" .. selfDmg,
                    expiry = getCurrentTime() + 0.8
                })
                if #hitMarkers > MAX_HIT_MARKERS then table.remove(hitMarkers, 1) end
            end
        end
    end
end
function weapon.performHitscanAndApply(w)
    local results = {}
    local ox, oy, oz = camera.x, camera.y, camera.z
    local yaw   = math.rad(player.rotY or 0)
    local pitch = math.rad(player.rotZ or 0)
    local dx = math.cos(yaw) * math.cos(pitch)
    local dy = math.sin(pitch)
    local dz = math.sin(yaw) * math.cos(pitch)
    local maxRange     = 50
    local hitRadius    = 0.6
    local headThreshold = 0.7
    local candidates = {}
    for i = 1, #zombies do
        local z = zombies[i]
        if z and z.health > 0 then
            if zombieWithinRange(z, ox, oz, maxRange + 1) then
                local centerY = z.y + (z.height or 1.8) * 0.5 + 0.4
                local vx = z.x - ox
                local vy = centerY - oy
                local vz = z.z - oz
                local t  = vx*dx + vy*dy + vz*dz
                if t > 0 and t <= maxRange then
                    local px   = ox + dx * t
                    local py   = oy + dy * t
                    local pz   = oz + dz * t
                    local ddx  = px - z.x
                    local ddy  = py - centerY
                    local ddz  = pz - z.z
                    if ddx*ddx + ddy*ddy + ddz*ddz <= hitRadius*hitRadius then
                        table.insert(candidates, {index = i, dist = t, hitY = py})
                    end
                end
            end
        end
    end
    if #candidates > 1 then
        table.sort(candidates, function(a,b) return a.dist < b.dist end)
    end
    local penetration = w.penetration or 0
    local maxHits = (penetration == -1) and 999 or (penetration + 1)
    local hits = 0
    for _, cand in ipairs(candidates) do
        if hits >= maxHits then break end
        local z = zombies[cand.index]
        if z and z.health > 0 then
            local isHeadshot = (cand.hitY >= (z.y + (z.height or 1.8) * headThreshold))
            local dmg = w.damage
            if isHeadshot then
                dmg = dmg * 2
                player.stats.headshots = player.stats.headshots + 1
            end
            player.stats.shotsHit    = player.stats.shotsHit    + 1
            player.stats.damageDealt = player.stats.damageDealt + dmg
            player.points = player.points + 10
            local markerText = "+10"
            z.health = z.health - dmg
            if z.health <= 0 then
                z._killedByPlayer = true
                z._headshotKill   = isHeadshot
                markerText = isHeadshot and "HEADSHOT! +110" or "+60"
            end
            table.insert(hitMarkers, {text = markerText, expiry = getCurrentTime() + 0.7})
            if #hitMarkers > MAX_HIT_MARKERS then table.remove(hitMarkers, 1) end
            table.insert(results, {
                zombieIndex = cand.index,
                damage      = dmg,
                remaining   = z.health,
                headshot    = isHeadshot
            })
            if w.splash and w.splash > 0 and z.health <= 0 then
                weapon.performSplashDamage(
                    {x = z.x, y = z.y + 0.9, z = z.z},
                    w.splash,
                    w.damage * 0.5,
                    w
                )
            end
            hits = hits + 1
        end
    end
    return results
end
function weapon.performHitscanDoubleTap(w)
    weapon.performHitscanAndApply(w)
    weapon.performHitscanAndApply(w)
end
local MELEE = {RANGE=2.2, CONE_DOT=0.4, COOLDOWN=0.5, POINTS=130}
function weapon.performMelee()
    local now = getCurrentTime()
    if now - (player.lastMeleeTime or 0) < MELEE.COOLDOWN then return end
    if player.isDowned or player.inAfterlife then return end
    player.lastMeleeTime = now
    local yaw = math.rad(player.rotY or 0)
    local fdx = math.cos(yaw)
    local fdz = math.sin(yaw)
    local px, pz = player.x, player.z
    for _, z in ipairs(zombies) do
        if z and z.health > 0 then
            local dx     = z.x - px
            local dz     = z.z - pz
            local distSq = dx*dx + dz*dz
            if distSq <= MELEE.RANGE * MELEE.RANGE then
                local dist = math.sqrt(distSq)
                local dot  = (dx/dist)*fdx + (dz/dist)*fdz
                if dot >= MELEE.CONE_DOT then
                    z.health = z.health - 99999
                    if z.health <= 0 then z._killedByMelee = true end
                    player.points = player.points + MELEE.POINTS
                    player.stats.damageDealt = player.stats.damageDealt + 99999
                    table.insert(hitMarkers, {
                        text   = "KNIFE! +" .. MELEE.POINTS,
                        expiry = now + 0.8
                    })
                    if #hitMarkers > MAX_HIT_MARKERS then table.remove(hitMarkers, 1) end
                end
            end
        end
    end
end
function weapon.performHitscanFromOrigin(origin, yaw, pitch, weaponTemplate)
    local results = {}
    local ox, oy, oz = origin.x, origin.y, origin.z
    yaw   = math.rad(yaw   or 0)
    pitch = math.rad(pitch or 0)
    local dx = math.cos(yaw) * math.cos(pitch)
    local dy = math.sin(pitch)
    local dz = math.sin(yaw) * math.cos(pitch)
    local maxRange      = 50
    local hitRadius     = 0.6
    local headThreshold = 0.7
    local candidates = {}
    for i = 1, #zombies do
        local z = zombies[i]
        if z and z.health > 0 then
            if zombieWithinRange(z, ox, oz, maxRange + 1) then
                local centerY = z.y + (z.height or 1.8) * 0.5 + 0.4
                local vx = z.x - ox
                local vy = centerY - oy
                local vz = z.z - oz
                local t  = vx*dx + vy*dy + vz*dz
                if t > 0 and t <= maxRange then
                    local px  = ox + dx * t
                    local py  = oy + dy * t
                    local pz  = oz + dz * t
                    local ddx = px - z.x
                    local ddy = py - centerY
                    local ddz = pz - z.z
                    if ddx*ddx + ddy*ddy + ddz*ddz <= hitRadius*hitRadius then
                        table.insert(candidates, {index = i, dist = t, hitY = py})
                    end
                end
            end
        end
    end
    if #candidates > 1 then
        table.sort(candidates, function(a,b) return a.dist < b.dist end)
    end
    local penetration = weaponTemplate.penetration or 0
    local maxHits = (penetration == -1) and 999 or (penetration + 1)
    local hits = 0
    for _, cand in ipairs(candidates) do
        if hits >= maxHits then break end
        local z = zombies[cand.index]
        if z and z.health > 0 then
            local isHeadshot = (cand.hitY >= (z.y + (z.height or 1.8) * headThreshold))
            local dmg = weaponTemplate.damage
            if isHeadshot then dmg = dmg * 2 end
            z.health = z.health - dmg
            if z.health <= 0 then
                z._killedByPlayer = true
                z._headshotKill   = isHeadshot
            end
            table.insert(results, {
                zombieIndex = cand.index,
                damage      = dmg,
                remaining   = z.health,
                headshot    = isHeadshot
            })
            hits = hits + 1
        end
    end
    return results
end
function weapon.tryFireWeapon()
    local w = getActiveWeapon()
    if not w then return end
    if w.isReloading then return end
    local now = getCurrentTime()
    local timeBetweenShots = 60 / w.rpm
    if now - (w.lastFireTime or 0) < timeBetweenShots then
        return
    end
    if w.ammo <= 0 then
        return
    end
    w.ammo = math.max(0, w.ammo - 1)
    w.lastFireTime = now
    player.ammo = w.ammo
    player.stats.shotsFired = player.stats.shotsFired + 1
    muzzleTimer = 0.12
    player.recoil = (player.recoil or 0) + (w.recoil or 0)
    if not multiplayerState.isMultiplayer or isHost then
        if player.doubleTap then
            weapon.performHitscanDoubleTap(w)
        else
            weapon.performHitscanAndApply(w)
        end
    else
        if multiplayerState.ws and multiplayerState.wsConnected then
            local origin = {x = camera.x, y = camera.y, z = camera.z}
            local yaw = player.rotY or 0
            local pitch = player.rotZ or 0
            multiplayerState.ws.send(textutils.serializeJSON({
                type = "fire_request",
                lobbyId = lobbyID,
                playerID = myPlayerID,
                weaponId = w.id,
                origin = origin,
                yaw = yaw,
                pitch = pitch,
                time = now
            }))
        end
    end
end
function weapon.reloadWeapon()
    local w = getActiveWeapon()
    if not w then return end
    if w.isReloading then return end
    if w.ammo >= w.mag then return end
    if not w.reserve or w.reserve <= 0 then return end
    local now = getCurrentTime()
    w.isReloading = true
    local multiplier = player.reloadMultiplier or 1
    w.reloadEndTime = now + (w.reloadTime or 1.5) / multiplier
    if player.electricCherry then
        for _, zombie in ipairs(zombies) do
            local dx = zombie.x - player.x
            local dz = zombie.z - player.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < 5 then
                zombie.health = zombie.health - 100
            end
        end
    end
end
function weapon.completeReload(w)
    if not w then return end
    if not w.reserve or w.reserve <= 0 then
        w.isReloading = false
        w.reloadEndTime = 0
        return
    end
    local needed = w.mag - w.ammo
    local take = math.min(needed, w.reserve)
    w.ammo = w.ammo + take
    w.reserve = w.reserve - take
    w.isReloading = false
    w.reloadEndTime = 0
    player.ammo = w.ammo
end
function weapon.updateFiring(dt)
    local w = getActiveWeapon()
    if not w then return end
    if w.isReloading and w.reloadEndTime and getCurrentTime() >= w.reloadEndTime then
        weapon.completeReload(w)
    end
    if w.isReloading then
        return
    end
    if w.fireMode == "auto" then
        if player.firing then
            weapon.tryFireWeapon()
        end
    else
        if player.firing and not player.firedOnThisClick then
            weapon.tryFireWeapon()
            player.firedOnThisClick = true
        end
    end
end
local function saveUsername(username)
    local file = fs.open("username.txt", "w")
    if file then
        file.write(username)
        file.close()
        return true
    end
    return false
end
local function loadUsername()
    if fs.exists("username.txt") then
        local file = fs.open("username.txt", "r")
        if file then
            local username = file.readAll()
            file.close()
            return username
        end
    end
    return nil
end
local function promptUsername()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2 - 10), math.floor(h/2 - 3))
    term.setTextColor(colors.red)
    term.write("CC CALL OF DUTY: ZOMBIES")
    term.setCursorPos(math.floor(w/2 - 8), math.floor(h/2 - 1))
    term.setTextColor(colors.white)
    term.write("Enter your username:")
    term.setCursorPos(math.floor(w/2 - 8), math.floor(h/2 + 1))
    term.setTextColor(colors.yellow)
    term.setBackgroundColor(colors.gray)
    term.write("                ")
    term.setCursorPos(math.floor(w/2 - 8), math.floor(h/2 + 1))
    local username = read()
    if username == "" then
        username = "Player"
    elseif #username > 16 then
        username = username:sub(1, 16)
    end
    saveUsername(username)
    player.username = username
    term.setBackgroundColor(colors.black)
end
local function connectWebSocket()
    if multiplayerState.ws then
        multiplayerState.ws.close()
    end
    multiplayerState.ws = http.websocket(WS_URL)
    if not multiplayerState.ws then
        return false
    end
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "register",
        playerID = myPlayerID,
        playerName = player.username or "Player"
    }))
    multiplayerState.wsConnected = true
    return true
end
local function submitScore()
    if multiplayerState.ws and multiplayerState.wsConnected then
        multiplayerState.ws.send(textutils.serializeJSON({
            type = "submit_score",
            playerName = player.username or "Player",
            mapName = gameStateVars.currentMap,
            round = roundState.currentRound,
            kills = player.kills,
            points = player.points
        }))
    end
end
local function fetchLeaderboards(mapName)
    if multiplayerState.ws and multiplayerState.wsConnected then
        multiplayerState.ws.send(textutils.serializeJSON({
            type = "get_leaderboards",
            mapName = mapName
        }))
    end
end
local function applyServerFireResult(msg)
    if msg.zombies then
        zombies = msg.zombies
    elseif msg.hits and #msg.hits > 0 then
        for _, h in ipairs(msg.hits) do
            local idx = h.zombieIndex
            if zombies[idx] then
                zombies[idx].health = h.remaining or (zombies[idx].health - (h.damage or 0))
                if zombies[idx].health <= 0 then
                    zombies[idx] = nil
                end
            end
            local text = h.headshot and "HEADSHOT! +100" or ("+" .. tostring(math.floor(h.damage or 0)))
            table.insert(hitMarkers, {text = text, expiry = getCurrentTime() + 0.7})
            if #hitMarkers > MAX_HIT_MARKERS then table.remove(hitMarkers, 1) end
        end
        local compacted = {}
        for i = 1, #zombies do
            if zombies[i] then table.insert(compacted, zombies[i]) end
        end
        zombies = compacted
    end
    if msg.playerID == myPlayerID and msg.points then
        player.points = msg.points
    end
end
local syncGameState
local sendPlayerUpdate
local foundLobbies = {}
local function handleServerMessage(msg)
    if msg.type == "character_assign" then
        if msg.charId and msg.playerID then takenCharacters[msg.charId] = msg.playerID end
    elseif msg.type == "lobby_created" then
        multiplayerState.lobbyID = msg.lobbyId
        multiplayerState.isHost = true
        player.color = playerColors[msg.playerColor]
        updateMultiplayerAliases()
    elseif msg.type == "join_success" then
        multiplayerState.lobbyID = msg.lobbyId
        player.color = playerColors[msg.playerColor]
        if msg.mapName then multiplayerState.lobby.mapName = msg.mapName end
        if msg.mapIndex then multiplayerState.lobby.mapIndex = msg.mapIndex end
        updateMultiplayerAliases()
    elseif msg.type == "join_failed" then
        print("Join failed: " .. (msg.error or "Unknown"))
    elseif msg.type == "lobby_list" then
        foundLobbies = msg.lobbies
    elseif msg.type == "lobby_updated" then
        lobby.players = msg.players
        updateMultiplayerAliases()
    elseif msg.type == "game_started" then
        if not isHost then
            local targetIdx = 1
            local targetName = msg.mapName or (lobby and lobby.mapName)
            if targetName then
                for i, m in ipairs(availableMaps) do
                    if m.name == targetName or m.file:find(targetName, 1, true) then
                        targetIdx = i
                        break
                    end
                end
            elseif lobby and lobby.mapIndex then
                targetIdx = math.max(1, math.min(lobby.mapIndex, #availableMaps))
            end
            initGame(targetIdx)
        end
    elseif msg.type == "player_state" then
        if msg.playerID ~= myPlayerID then
            players[msg.playerID] = {
                x = msg.x,
                y = msg.y,
                z = msg.z,
                rotY = msg.rotY,
                health = msg.health,
                maxHealth = msg.maxHealth or 100,
                points = msg.points,
                kills = msg.kills or 0,
                isDowned = msg.isDowned or false,
                perks = msg.perks or {},
                color = playerColors[msg.color] or colors.red
            }
        end
    elseif msg.type == "player_ready" then
        if isHost and multiplayerState.isMultiplayer then
            syncGameState()
            sendPlayerUpdate()
        end
        if not isHost then
            if msg.zombies then
                zombies = msg.zombies
            end
            if msg.roundState then roundState = msg.roundState end
            if msg.powerOn ~= nil then
                powerOn = msg.powerOn
                gameStateVars.powerOn = msg.powerOn
            end
            if msg.doors then
                for i, serverDoor in ipairs(msg.doors) do
                    if doors[i] then
                        doors[i].opened = serverDoor.opened
                        if serverDoor.opened and not doors[i]._wasOpen then
                            doors[i].blocks = {}
                            doors[i]._wasOpen = true
                        end
                    end
                end
            end
        end
    elseif msg.type == "lobby_closed" then
        gameStateVars.current = "main_menu"
        print("Lobby closed: " .. (msg.reason or "Unknown"))
    elseif msg.type == "fire_request" then
        if isHost then
            local requestPlayerID = msg.playerID
            local weaponId = msg.weaponId
            local origin = msg.origin
            local yaw = msg.yaw
            local pitch = msg.pitch
            local weaponTemplate = WEAPONS[weaponId]
            if weaponTemplate then
                local hits = weapon.performHitscanFromOrigin(origin, yaw, pitch, weaponTemplate)
                if multiplayerState.ws and multiplayerState.wsConnected then
                    multiplayerState.ws.send(textutils.serializeJSON({
                        type = "fire_result",
                        playerID = requestPlayerID,
                        hits = hits,
                        zombies = zombies,
                        points = nil
                    }))
                end
            end
        end
    elseif msg.type == "fire_result" then
        applyServerFireResult(msg)
    elseif msg.type == "leaderboards" then
        leaderboardData = msg
        updateMultiplayerAliases()
    end
end
local function createLobby(lobbyName, mapName, mapIndex)
    if not multiplayerState.wsConnected then
        if not connectWebSocket() then
            return false
        end
    end
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "create_lobby",
        lobbyName = lobbyName,
        mapName = mapName,
        mapIndex = mapIndex,
        maxPlayers = 4,
        playerName = player.username or "Player"
    }))
    return true
end
local function findLobbies()
    if not multiplayerState.wsConnected then
        if not connectWebSocket() then
            return {}
        end
    end
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "list_lobbies"
    }))
    foundLobbies = {}
    local timeout = os.startTimer(2)
    while true do
        local event, p1, p2 = os.pullEvent()
        if event == "timer" and p1 == timeout then
            break
        elseif event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg and msg.type == "lobby_list" then
                foundLobbies = msg.lobbies
                break
            end
        end
    end
    return foundLobbies
end
local function joinLobby(selectedLobbyID)
    if not multiplayerState.wsConnected then
        if not connectWebSocket() then
            return false, "Cannot connect to server"
        end
    end
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "join_lobby",
        lobbyId = selectedLobbyID,
        playerName = player.username or "Player"
    }))
    local timeout = os.startTimer(5)
    while true do
        local event, p1, p2 = os.pullEvent()
        if event == "timer" and p1 == timeout then
            return false, "Timeout"
        elseif event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then
                if msg.type == "join_success" then
                    multiplayerState.lobbyID = msg.lobbyId
                    player.color = playerColors[msg.playerColor]
                    if msg.mapName then multiplayerState.lobby.mapName = msg.mapName end
                    if msg.mapIndex then multiplayerState.lobby.mapIndex = msg.mapIndex end
                    updateMultiplayerAliases()
                    return true
                elseif msg.type == "join_failed" then
                    return false, msg.error
                end
            end
        end
    end
end
local function leaveLobby()
    if multiplayerState.wsConnected and multiplayerState.ws then
        multiplayerState.ws.send(textutils.serializeJSON({ type = "leave_lobby" }))
    end
end
local function startGameMultiplayer()
    if isHost and multiplayerState.wsConnected and multiplayerState.ws then
        multiplayerState.ws.send(textutils.serializeJSON({ type = "start_game" }))
        return true
    end
    return false
end
local _lastPlayerUpdateTime = 0
sendPlayerUpdate = function()
    if not multiplayerState.wsConnected or not multiplayerState.ws or not lobbyID then return end
    local now = os.epoch("utc") / 1000
    if now - _lastPlayerUpdateTime < 0.15 then return end
    _lastPlayerUpdateTime = now
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "player_update",
        x = player.x,
        y = player.y,
        z = player.z,
        rotY = player.rotY,
        health = player.health,
        maxHealth = player.maxHealth,
        points = player.points,
        kills = player.kills,
        isDowned = player.isDowned,
        perks = player.perks
    }))
end
syncGameState = function()
    if not isHost or not multiplayerState.wsConnected or not multiplayerState.ws or not lobbyID then return end
    local zombieSync = {}
    for i, z in ipairs(zombies) do
        zombieSync[i] = {
            x = z.x, y = z.y, z = z.z,
            type = z.type,
            health = z.health,
            maxHealth = z.maxHealth,
            state = z.state,
            currentFrame = z.currentFrame,
            animTimer = z.animTimer
        }
    end
    multiplayerState.ws.send(textutils.serializeJSON({
        type = "game_sync",
        zombies = zombieSync,
        roundState = roundState,
        doors = doors,
        powerOn = powerOn
    }))
end
local function loadMapData(filename)
    if not fs.exists(filename) then
        return nil, "File not found"
    end
    if filename:match("%.ccz$") then
        local f = fs.open(filename, "r")
        if not f then return nil, "Could not open file" end
        local content = f.readAll()
        f.close()
        local fn, loadErr = load(content, filename)
        if not fn then
            return nil, "CCZ syntax error: " .. tostring(loadErr)
        end
        local ok, result = pcall(fn)
        if not ok or type(result) ~= "table" then
            return nil, "CCZ exec error: " .. tostring(result)
        end
        result.name        = result.name        or filename:match("([^/\\]+)%.ccz$") or filename
        result.description = result.description or ""
        result.meshes      = result.meshes      or {}
        result.spawns      = result.spawns      or {player={{x=0,y=1,z=0}}, zombie={}}
        local function flattenIfNested(tbl)
            if type(tbl) ~= "table" or #tbl == 0 then return tbl end
            if type(tbl[1]) == "table" and tbl[1][1] and type(tbl[1][1]) == "table" then
                local flat = {}
                for _, inner in ipairs(tbl) do
                    for _, item in ipairs(inner) do
                        table.insert(flat, item)
                    end
                end
                return flat
            end
            return tbl
        end
        result.meshes   = flattenIfNested(result.meshes)
        result.entities = flattenIfNested(result.entities or {})
        return result
    end
    local f = fs.open(filename, "r")
    if not f then return nil, "Could not open file" end
    local content = f.readAll()
    f.close()
    local data = textutils.unserializeJSON(content)
    if not data then return nil, "Invalid JSON" end
    return data
end
local CCZLoader = {}
CCZLoader.loadedMaps = {}
CCZLoader.currentMap = nil
function CCZLoader.loadMap(mapName)
    local mapPath = "maps/" .. mapName .. ".ccz"
    if not fs.exists(mapPath) then
        print("Error: Map not found: " .. mapPath)
        return nil
    end
    local file = fs.open(mapPath, "r")
    local content = file.readAll()
    file.close()
    local func, loadErr = load(content, mapPath)
    if not func then
        print("Error parsing map: " .. tostring(loadErr))
        return nil
    end
    local success, mapData = pcall(func)
    if not success then
        print("Error loading map: " .. tostring(mapData))
        return nil
    end
    if not mapData or type(mapData) ~= "table" then
        print("Error: Invalid map format")
        return nil
    end
    mapData.version = mapData.version or 1
    mapData.name = mapData.name or mapName
    mapData.mapType = mapData.mapType or "normal"
    mapData.meshes = mapData.meshes or {}
    mapData.spawns = mapData.spawns or {player = {{x=0, y=1, z=0}}, zombie = {}}
    mapData.interactables = mapData.interactables or {}
    mapData.doors = mapData.doors or {}
    local function flattenMeshes(tbl)
        if type(tbl) ~= "table" or #tbl == 0 then return tbl end
        if type(tbl[1]) == "table" and tbl[1][1] and type(tbl[1][1]) == "table" then
            local flat = {}
            for _, inner in ipairs(tbl) do
                for _, item in ipairs(inner) do flat[#flat+1] = item end
            end
            return flat
        end
        return tbl
    end
    mapData.meshes = flattenMeshes(mapData.meshes)
    local normalized = {}
    for _, m in ipairs(mapData.meshes) do
        if m.min and m.max then
            normalized[#normalized+1] = m
        elseif m.x ~= nil and m.sx ~= nil then
            normalized[#normalized+1] = {
                min   = {m.x,           m.y,           m.z          },
                max   = {m.x + m.sx,    m.y + m.sy,    m.z + m.sz   },
                color = m.color or colors.white
            }
        elseif m[1] ~= nil and m[4] ~= nil then
            normalized[#normalized+1] = {
                min   = {m[1],        m[2],        m[3]       },
                max   = {m[1]+m[4],   m[2]+m[5],   m[3]+m[6]  },
                color = m[7] or colors.white
            }
        end
    end
    mapData.meshes = normalized
    print("Loaded map: " .. mapData.name .. " (v" .. mapData.version .. ", " .. #mapData.meshes .. " meshes)")
    CCZLoader.loadedMaps[mapName] = mapData
    CCZLoader.currentMap = mapData
    return mapData
end
function CCZLoader.scanMaps()
    local maps = {}
    if not fs.exists("maps") then
        fs.makeDir("maps")
    end
    local files = fs.list("maps")
    for _, filename in ipairs(files) do
        if filename:match("%.ccz$") then
            local mapName = filename:sub(1, -5)
            table.insert(maps, mapName)
        end
    end
    return maps
end
function CCZLoader.getDLCMaps()
    local allMaps = CCZLoader.scanMaps()
    local dlcMaps = {}
    local builtInMaps = {"MenuRoom", "Tranzit", "NHLabs", "Origins"}
    for _, mapName in ipairs(allMaps) do
        local isBuiltIn = false
        for _, builtIn in ipairs(builtInMaps) do
            if mapName == builtIn then
                isBuiltIn = true
                break
            end
        end
        if not isBuiltIn then
            table.insert(dlcMaps, mapName)
        end
    end
    return dlcMaps
end
local function checkAvailableMaps()
    availableMaps = {}
    gameStateVars.availableMaps = availableMaps
    local cczMaps = CCZLoader.scanMaps()
    for _, mapName in ipairs(cczMaps) do
        if mapName ~= "MenuRoom" then
            local mapData = CCZLoader.loadMap(mapName)
            if mapData then
                table.insert(availableMaps, {
                    name = mapData.name or mapName,
                    file = "maps/" .. mapName .. ".ccz",
                    description = mapData.description or "",
                    data = mapData
                })
            end
        end
    end
    gameStateVars.availableMaps = availableMaps
    return #availableMaps > 0
end
local world = {}
function world.isPlayerLookingAt(bounds, player)
    local lookDir = {
        math.sin(math.rad(player.rotY)) * math.cos(math.rad(player.rotZ)),
        -math.sin(math.rad(player.rotZ)),
        math.cos(math.rad(player.rotY)) * math.cos(math.rad(player.rotZ))
    }
    local rayOrigin = {player.x, player.y + 1.5, player.z}
    local rayLength = 5
    local function rayAABBIntersect(rayOrigin, rayDir, boxMin, boxMax)
        if rayDir[1] == 0 then rayDir[1] = 0.000001 end
        if rayDir[2] == 0 then rayDir[2] = 0.000001 end
        if rayDir[3] == 0 then rayDir[3] = 0.000001 end
        local tmin = (boxMin[1] - rayOrigin[1]) / rayDir[1]
        local tmax = (boxMax[1] - rayOrigin[1]) / rayDir[1]
        if tmin > tmax then tmin, tmax = tmax, tmin end
        local tymin = (boxMin[2] - rayOrigin[2]) / rayDir[2]
        local tymax = (boxMax[2] - rayOrigin[2]) / rayDir[2]
        if tymin > tymax then tymin, tymax = tymax, tymin end
        if tmin > tymax or tymin > tmax then return false end
        if tymin > tmin then tmin = tymin end
        if tymax < tmax then tmax = tymax end
        local tzmin = (boxMin[3] - rayOrigin[3]) / rayDir[3]
        local tzmax = (boxMax[3] - rayOrigin[3]) / rayDir[3]
        if tzmin > tzmax then tzmin, tzmax = tzmax, tzmin end
        if tmin > tzmax or tzmin > tmax then return false end
        return tmin >= 0 and tmin <= rayLength
    end
    return rayAABBIntersect(rayOrigin, lookDir, bounds.min, bounds.max)
end
function world.preBakeCollisions(meshes)
    collisionMask = {}
    if not meshes then return end
    term.setCursorPos(2, 7)
    term.setTextColor(colors.gray)
    write("INITIALIZING PHYSICS...")
    for i, m in ipairs(meshes) do
        for x = math.floor(m.min[1]), math.ceil(m.max[1]) do
            collisionMask[x] = collisionMask[x] or {}
            for z = math.floor(m.min[3]), math.ceil(m.max[3]) do
                collisionMask[x][z] = collisionMask[x][z] or {}
                for y = math.floor(m.min[2]), math.ceil(m.max[2]) do
                    collisionMask[x][z][y] = true
                end
            end
        end
        if i % 50 == 0 then
            term.setCursorPos(27, 7)
            write(math.floor(i/#meshes*100).."%")
        end
    end
    term.setCursorPos(27, 7)
    term.setTextColor(colors.lime)
    write("DONE")
end
function world.bakeWorldChunks(meshes)
    worldChunks = {}
    if not meshes then return end
    term.setCursorPos(2, 8)
    term.setTextColor(colors.gray)
    write("CHUNKING WORLD...")
    for i, m in ipairs(meshes) do
        local minChunkX = math.floor(m.min[1] / CHUNK_SIZE)
        local maxChunkX = math.floor(m.max[1] / CHUNK_SIZE)
        local minChunkZ = math.floor(m.min[3] / CHUNK_SIZE)
        local maxChunkZ = math.floor(m.max[3] / CHUNK_SIZE)
        for cx = minChunkX, maxChunkX do
            for cz = minChunkZ, maxChunkZ do
                local key = cx .. "," .. cz
                worldChunks[key] = worldChunks[key] or {}
                table.insert(worldChunks[key], {
                    min = m.min,
                    max = m.max,
                    color = m.color
                })
            end
        end
        if i % 50 == 0 then
            term.setCursorPos(20, 8)
            write(math.floor(i/#meshes*100).."%")
        end
    end
    term.setCursorPos(20, 8)
    term.setTextColor(colors.lime)
    write("DONE")
end
function initializeMap(mapName)
    local mapData = CCZLoader.loadMap(mapName)
    if not mapData then
        return false
    end
    CCZLoader.currentMap = mapData
    if mapData.meshes and #mapData.meshes > 0 then
        world.preBakeCollisions(mapData.meshes)
        world.bakeWorldChunks(mapData.meshes)
    end
    if mapData.spawns and mapData.spawns.player and #mapData.spawns.player > 0 then
        local spawn = mapData.spawns.player[1]
        player.x = spawn.x
        player.y = spawn.y
        player.z = spawn.z
    end
    if mapData.spawns and mapData.spawns.zombie then
        zombieSpawns = mapData.spawns.zombie
    end
    if mapData.doors then
    end
    if mapData.onLoad then
        pcall(mapData.onLoad, gameStateVars)
    end
    return true
end
function updateMapLogic(deltaTime)
    local mapData = CCZLoader.currentMap
    if not mapData then return end
    if mapData.onUpdate then
        pcall(mapData.onUpdate, gameStateVars, deltaTime)
    end
end
function onPlayerInteract()
    local mapData = CCZLoader.currentMap
    if not mapData then return false end
    if mapData.interactables then
        for _, interactable in ipairs(mapData.interactables) do
            if world.isPlayerLookingAt(interactable.bounds, player) then
                if interactable.onActivate then
                    pcall(interactable.onActivate, gameStateVars)
                end
                return true
            end
        end
    end
    if mapData.scriptBlocks then
        for blockId, blockDef in pairs(mapData.scriptBlocks) do
            if not blockDef.collected and blockDef.instances and blockDef.onInteract then
                for _, inst in ipairs(blockDef.instances) do
                    local dx = player.x - inst.x
                    local dz = player.z - inst.z
                    local dist = math.sqrt(dx*dx + dz*dz)
                    if dist < 2 then
                        blockDef.id = blockId
                        local ok, err = pcall(blockDef.onInteract, blockDef, gameStateVars)
                        if not ok then
                            ccz.game.announce("Script error: " .. tostring(err), 3)
                        end
                        return true
                    end
                end
            end
        end
    end
    return false
end
function onRoundStart(roundNumber)
    local mapData = CCZLoader.currentMap
    if not mapData or not mapData.onRoundStart then return end
    pcall(mapData.onRoundStart, gameStateVars, roundNumber)
end
function onRoundEnd(roundNumber)
    local mapData = CCZLoader.currentMap
    if not mapData or not mapData.onRoundEnd then return end
    pcall(mapData.onRoundEnd, gameStateVars, roundNumber)
end
function world.isBlocked(x, y, z)
    local ix, iy, iz = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5)
    local xTable = collisionMask[ix]
    if not xTable then return false end
    local zTable = xTable[iz]
    if not zTable then return false end
    return zTable[iy] == true
end
function world.showLoadingScreen(mapName)
    term.clear()
    term.setCursorPos(2, 2)
    local mapData = CCZLoader.currentMap
    local title    = (mapData and mapData.name)        or mapName
    local details  = (mapData and mapData.description) or ""
    local location = (mapData and mapData.location)    or ""
    term.setTextColor(colors.orange)
    print(title:upper())
    sleep(1.0)
    if details ~= "" then
        term.setCursorPos(2, 3)
        term.setTextColor(colors.white)
        print(details)
        sleep(0.8)
    end
    if location ~= "" then
        term.setCursorPos(2, 4)
        term.setTextColor(colors.gray)
        print(location)
        sleep(0.8)
    end
    sleep(0.4)
    term.setCursorPos(2, 6)
    term.setTextColor(colors.gray)
    print("---")
    if gameStateVars.mapData and gameStateVars.mapData.meshes then
        world.preBakeCollisions(gameStateVars.mapData.meshes)
        world.bakeWorldChunks(gameStateVars.mapData.meshes)
    end
    term.setTextColor(colors.lime)
    term.setCursorPos(2, 10)
    print("READY.")
    sleep(1)
end
function createBox(width, height, depth, color)
    local hw, hh, hd = width/2, height/2, depth/2
    local function newPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, c)
        return {
            x1 = x1, y1 = y1, z1 = z1,
            x2 = x2, y2 = y2, z2 = z2,
            x3 = x3, y3 = y3, z3 = z3,
            c = c
        }
    end
    return {
        newPoly(-hw,-hh,-hd, -hw,-hh,hd, hw,-hh,hd, color),
        newPoly(-hw,-hh,-hd, hw,-hh,hd, hw,-hh,-hd, color),
        newPoly(-hw,hh,-hd, hw,hh,hd, -hw,hh,hd, color),
        newPoly(-hw,hh,-hd, hw,hh,-hd, hw,hh,hd, color),
        newPoly(-hw,-hh,-hd, -hw,hh,-hd, -hw,hh,hd, color),
        newPoly(-hw,-hh,-hd, -hw,hh,hd, -hw,-hh,hd, color),
        newPoly(hw,-hh,-hd, hw,-hh,hd, hw,hh,hd, color),
        newPoly(hw,-hh,-hd, hw,hh,hd, hw,hh,-hd, color),
        newPoly(-hw,-hh,-hd, hw,-hh,-hd, hw,hh,-hd, color),
        newPoly(-hw,-hh,-hd, hw,hh,-hd, -hw,hh,-hd, color),
        newPoly(-hw,-hh,hd, hw,hh,hd, hw,-hh,hd, color),
        newPoly(-hw,-hh,hd, -hw,hh,hd, hw,hh,hd, color),
    }
end
local renderedObjects = {}
local cachedModels = {}
local function toAfterlifeColor(color)
    local blueMap = {
        [colors.white] = colors.lightBlue,
        [colors.orange] = colors.cyan,
        [colors.magenta] = colors.purple,
        [colors.lightBlue] = colors.lightBlue,
        [colors.yellow] = colors.cyan,
        [colors.lime] = colors.blue,
        [colors.pink] = colors.purple,
        [colors.gray] = colors.gray,
        [colors.lightGray] = colors.lightBlue,
        [colors.cyan] = colors.cyan,
        [colors.purple] = colors.purple,
        [colors.blue] = colors.blue,
        [colors.brown] = colors.gray,
        [colors.green] = colors.blue,
        [colors.red] = colors.purple,
        [colors.black] = colors.black
    }
    return blueMap[color] or colors.blue
end
local function getCachedBoxModel(width, height, depth, color)
    local actualColor = color
    if player.inAfterlife then
        actualColor = toAfterlifeColor(color)
    end
    local key = width .. "," .. height .. "," .. depth .. "," .. actualColor
    if not cachedModels[key] then
        cachedModels[key] = createBox(width, height, depth, actualColor)
    end
    return cachedModels[key]
end
function world.buildSolidBlocksFromMeshes()
    solidBlocks = {}
    if not gameStateVars.mapData or not gameStateVars.mapData.meshes then
        return
    end
    for _, mesh in ipairs(gameStateVars.mapData.meshes) do
        local minX, minY, minZ = mesh.min[1], mesh.min[2], mesh.min[3]
        local maxX, maxY, maxZ = mesh.max[1], mesh.max[2], mesh.max[3]
        for x = minX, maxX do
            for y = minY, maxY do
                for z = minZ, maxZ do
                    local key = x..","..y..","..z
                    solidBlocks[key] = true
                end
            end
        end
    end
end
function world.renderMap()
    renderedObjects = {}
    if not worldChunks then
        return
    end
    local cx = math.floor(player.x / CHUNK_SIZE)
    local cz = math.floor(player.z / CHUNK_SIZE)
    local renderedMeshes = {}
    for dx = -4, 4 do
        for dz = -4, 4 do
            local key = (cx + dx) .. "," .. (cz + dz)
            local chunk = worldChunks[key]
            if chunk then
                for _, mesh in ipairs(chunk) do
                    local meshKey = mesh.min[1]..","..mesh.min[2]..","..mesh.min[3]..","..mesh.max[1]..","..mesh.max[2]..","..mesh.max[3]
                    if not renderedMeshes[meshKey] then
                        renderedMeshes[meshKey] = true
                        local minX, minY, minZ = mesh.min[1], mesh.min[2], mesh.min[3]
                        local maxX, maxY, maxZ = mesh.max[1], mesh.max[2], mesh.max[3]
                        local width = maxX - minX + 1
                        local height = maxY - minY + 1
                        local depth = maxZ - minZ + 1
                        local centerX = minX + width / 2 - 0.5
                        local centerY = minY + height / 2 - 0.5
                        local centerZ = minZ + depth / 2 - 0.5
                        local boxModel = getCachedBoxModel(width, height, depth, mesh.color)
                        local obj = frame:newObject(boxModel, centerX, centerY, centerZ)
                        table.insert(renderedObjects, obj)
                    end
                end
            end
        end
    end
end
function world.findPlayerSpawn()
    local md = gameStateVars.mapData
    if not md then return 0, 1, 0 end
    if md.entities then
        for _, entity in ipairs(md.entities) do
            if entity.type == "player_spawn" then
                return entity.pos[1], entity.pos[2], entity.pos[3]
            end
        end
    end
    if md.spawns and md.spawns.player and #md.spawns.player > 0 then
        local sp = md.spawns.player[1]
        return sp.x, sp.y, sp.z
    end
    return 0, 1, 0
end
local perkColors = {
    perk_juggernog = colors.red,
    perk_whoswho = colors.cyan,
    perk_revive = colors.blue,
    perk_speedcola = colors.green,
    perk_phd = colors.purple,
    perk_staminup = colors.orange,
    perk_mulekick = colors.gray,
    perk_cherry = colors.magenta,
    perk_doubletap = colors.yellow
}
local perkMachines = {}
local papMachines  = {}
local mysteryBoxes = {}
function world.loadEntities()
    zombieSpawns  = {}
    doors         = {}
    doorBlocks    = {}
    powerSwitches = {}
    perkMachines  = {}
    papMachines   = {}
    mysteryBoxes  = {}
    hasPowerSwitch = false
    local mapData = gameStateVars.mapData
    if not mapData or not mapData.entities then return end
    local flat = {}
    for _, item in ipairs(mapData.entities) do
        if item.type then
            flat[#flat+1] = item
        elseif type(item) == "table" then
            for _, sub in ipairs(item) do
                if type(sub) == "table" and sub.type then flat[#flat+1] = sub end
            end
        end
    end
    for _, ent in ipairs(flat) do
        if not ent.pos then goto leSkip end
        local x, y, z = ent.pos[1], ent.pos[2], ent.pos[3]
        if ent.type == "zombie_spawn" then
            table.insert(zombieSpawns, {x=x,y=y,z=z})
        elseif ent.type == "power_switch" then
            hasPowerSwitch = true
            table.insert(powerSwitches, {pos={x=x,y=y,z=z}, activated=false})
        elseif ent.type == "door" then
            local door = {bounds=ent.bounds, cost=ent.cost or 750, opened=false, blocks={}}
            if ent.bounds then
                local b = ent.bounds
                for bx=b.min[1],b.max[1] do
                  for by=b.min[2],b.max[2] do
                    for bz=b.min[3],b.max[3] do
                      local key=bx..","..by..","..bz
                      table.insert(door.blocks, key); doorBlocks[key]=door
                    end
                  end
                end
            end
            table.insert(doors, door)
        elseif perkColors[ent.type] then
            table.insert(perkMachines, {
                type=ent.type, pos={x=x,y=y,z=z}, rotation=ent.rotation or 0,
                purchased=false,
                bounds={minX=x-0.5,maxX=x+1.5,minY=y,maxY=y+3,minZ=z-0.5,maxZ=z+1.5}
            })
        elseif ent.type == "mystery_box" then
            table.insert(mysteryBoxes, {
                pos={x=x,y=y,z=z}, rotation=ent.rotation or 0,
                bounds={minX=x-1,maxX=x+2,minY=y,maxY=y+1,minZ=z-0.5,maxZ=z+1.5}
            })
        elseif ent.type == "pack_a_punch" then
            table.insert(papMachines, {
                pos={x=x,y=y,z=z}, rotation=ent.rotation or 0,
                bounds={minX=x-1,maxX=x+2,minY=y,maxY=y+2,minZ=z-1,maxZ=z+2}
            })
        end
        ::leSkip::
    end
    if #zombieSpawns == 0 and mapData.spawns then
        for _, sp in ipairs(mapData.spawns.zombie or {}) do
            table.insert(zombieSpawns, {x=sp.x,y=sp.y,z=sp.z})
        end
    end
    if #zombieSpawns == 0 then
        local sp = (mapData.spawns and mapData.spawns.player and mapData.spawns.player[1]) or {x=0,y=1,z=0}
        for _,o in ipairs({{10,0,0},{-10,0,0},{0,0,10},{0,0,-10},{8,0,8},{-8,0,8},{8,0,-8},{-8,0,-8}}) do
            table.insert(zombieSpawns, {x=sp.x+o[1],y=sp.y+o[2],z=sp.z+o[3]})
        end
    end
    if not hasPowerSwitch then powerOn = true end
end
ccz.init({
    announceQueue      = announceQueue,
    pendingSoundRequests = pendingSoundRequests,
    player             = player,
    roundState         = roundState,
    gameStateVars      = gameStateVars,
    multiplayerState   = multiplayerState,
    doors              = doors,
    perkMachines       = perkMachines,
    zombies            = zombies,
})
local cachedEntityModels = {}
local function precomputeEntityModels()
    cachedEntityModels = {}
    cachedEntityModels.perkBox = createBox(1, 3, 1, colors.white)
    cachedEntityModels.mysteryBox = createBox(1, 1, 1, colors.yellow)
    cachedEntityModels.papBox = createBox(1, 1, 1, colors.purple)
    cachedEntityModels.doorBox = createBox(1, 1, 1, colors.red)
    for perkType, color in pairs(perkColors) do
        cachedEntityModels["perk_" .. perkType] = createBox(1, 3, 1, color)
    end
end
local function isEntityInRenderDistance(entityPos)
    local ex = entityPos.x or entityPos[1]
    local ez = entityPos.z or entityPos[3]
    local dx = player.x - ex
    local dz = player.z - ez
    local distSq = dx*dx + dz*dz
    return distSq <= (40 * 40)
end
local function renderPerkMachines()
    for _, m in ipairs(perkMachines) do
        if m.purchased then goto rpSkip end
        if not isEntityInRenderDistance(m.pos) then goto rpSkip end
        local x,y,z = m.pos.x, m.pos.y, m.pos.z
        local rot = m.rotation or 0
        local model = cachedEntityModels["perk_"..m.type] or cachedEntityModels.perkBox
        local dx1,dz1,dx2,dz2 = 0,0,0,1
        if rot==90  then dx1,dz1,dx2,dz2=0,0,1,0
        elseif rot==180 then dx1,dz1,dx2,dz2=0,0,0,-1
        elseif rot==270 then dx1,dz1,dx2,dz2=0,0,-1,0 end
        table.insert(renderedObjects, frame:newObject(model, x+dx1, y+1.5, z+dz1))
        table.insert(renderedObjects, frame:newObject(model, x+dx2, y+1.5, z+dz2))
        ::rpSkip::
    end
end
local function renderMysteryBoxes()
    for _, box in ipairs(mysteryBoxes) do
        if not isEntityInRenderDistance(box.pos) then goto mbSkip end
        local x,y,z = box.pos.x, box.pos.y, box.pos.z
        local rot = box.rotation or 0
        local positions = (rot==0 or rot==180)
            and {{x-1,y,z},{x,y,z},{x+1,y,z}}
            or  {{x,y,z-1},{x,y,z},{x,y,z+1}}
        for _,p in ipairs(positions) do
            table.insert(renderedObjects, frame:newObject(cachedEntityModels.mysteryBox, p[1],p[2],p[3]))
        end
        ::mbSkip::
    end
end
local function renderPaPMachines()
    for _, pap in ipairs(papMachines) do
        if not isEntityInRenderDistance(pap.pos) then goto papSkip end
        local x,y,z = pap.pos.x, pap.pos.y, pap.pos.z
        local rot = pap.rotation or 0
        local positions = (rot==0 or rot==180)
            and {{x-1,y,z},{x,y,z},{x+1,y,z},{x-1,y+1,z},{x,y+1,z},{x+1,y+1,z}}
            or  {{x,y,z-1},{x,y,z},{x,y,z+1},{x,y+1,z-1},{x,y+1,z},{x,y+1,z+1}}
        for _,p in ipairs(positions) do
            table.insert(renderedObjects, frame:newObject(cachedEntityModels.papBox, p[1],p[2],p[3]))
        end
        ::papSkip::
    end
end
local reviveHold   = {active=false, target=nil, targetID=nil, elapsed=0, isWhosWho=false}
local purchaseHold = {active=false, elapsed=0, label="", action=nil}
local function getNearestWhosWhoBody()
    if not player.inAfterlife or not player.afterlifeBodyPos then return false end
    local bp = player.afterlifeBodyPos
    local dx = player.x - bp.x
    local dz = player.z - bp.z
    return math.sqrt(dx*dx + dz*dz) < 2.5
end
local function completeWhosWhoRevive()
    player.inAfterlife = false
    player.health = player.maxHealth
    player.perks = {}
    for _, perk in ipairs(player.afterlifePerks) do
        if perk ~= "perk_whoswho" then
            table.insert(player.perks, perk)
        end
    end
    player.whosWho = false
    player.afterlifePerks = {}
    player.afterlifeBodyPos = nil
end
local function renderPlayers()
    if player.inAfterlife and player.afterlifeBodyPos then
        local bp = player.afterlifeBodyPos
        local bodyModel = createBox(0.8, 2, 0.8, colors.blue)
        local bodyObj = frame:newObject(bodyModel, bp.x, bp.y + 1, bp.z)
        table.insert(renderedObjects, bodyObj)
    end
    if not multiplayerState.isMultiplayer then return end
    for playerID, playerData in pairs(players) do
        local playerModel = createBox(0.8, 2, 0.8, playerData.color)
        local obj = frame:newObject(playerModel, playerData.x, playerData.y + 1, playerData.z)
        table.insert(renderedObjects, obj)
    end
end
local function renderPowerSwitches()
    if not powerSwitches then return end
    for _, switch in ipairs(powerSwitches) do
        local x, y, z = switch.pos.x, switch.pos.y, switch.pos.z
        local color = switch.activated and colors.lime or colors.red
        local switchModel1 = createBox(0.5, 1, 0.5, color)
        local switchModel2 = createBox(0.5, 1, 0.5, color)
        local obj1 = frame:newObject(switchModel1, x, y, z)
        local obj2 = frame:newObject(switchModel2, x, y + 1, z)
        table.insert(renderedObjects, obj1)
        table.insert(renderedObjects, obj2)
    end
end
function world.isBlockSolid(x, y, z)
    local key = math.floor(x)..","..math.floor(y)..","..math.floor(z)
    if solidBlocks[key] then
        if doorBlocks[key] then
            local door = doorBlocks[key]
            if door.opened then
                return false
            end
        end
        return true
    end
    return world.isBlocked(x, y, z)
end
function world.checkCollision(x, y, z, radius)
    radius = radius or 0.3
    local offsets = {
        {-radius, 0, -radius},
        {radius, 0, -radius},
        {-radius, 0, radius},
        {radius, 0, radius}
    }
    for _, offset in ipairs(offsets) do
        if world.isBlocked(x + offset[1], y, z + offset[3]) then
            local key = math.floor(x + offset[1])..","..math.floor(y)..","..math.floor(z + offset[3])
            if doorBlocks[key] and doorBlocks[key].opened then
            else
                return true
            end
        end
    end
    return false
end
function world.checkPlayerCollision(x, y, z, radius)
    radius = radius or 0.3
    for heightOffset = 0, player.height - 1 do
        if world.checkCollision(x, y + heightOffset, z, radius) then
            return true
        end
    end
    return false
end
function world.findGroundBelow(x, y, z, maxDistance)
    maxDistance = maxDistance or 10
    for i = 0, maxDistance do
        local checkY = y - i
        if world.isBlocked(x, checkY - 0.1, z) then
            return checkY
        end
    end
    return nil
end
local NAV_STEP   = 1
local flowField  = {}
local flowOrigin = {x=nil, z=nil}
local navWalkCache = {}
local function navSnap(v, origin)
    return math.floor((v - origin) / NAV_STEP + 0.5) * NAV_STEP + origin
end
local function navWalkable(wx, wz)
    local kx = wx + 1000
    local kz = wz + 1000
    local col = navWalkCache[kx]
    if col then
        local cached = col[kz]
        if cached ~= nil then return cached end
    else
        navWalkCache[kx] = {}
        col = navWalkCache[kx]
    end
    local groundY = world.findGroundBelow(wx, 10, wz, 12)
    local result  = false
    if groundY then
        if not world.isBlocked(wx, groundY, wz) and
           not world.isBlocked(wx, groundY + 1, wz) then
            result = true
        end
    end
    col[kz] = result
    return result
end
local function buildFlowField()
    flowField = {}
    local goalX = navSnap(player.x, 0)
    local goalZ = navSnap(player.z, 0)
    flowOrigin.x = player.x
    flowOrigin.z = player.z
    local queue   = {{goalX, goalZ}}
    local head    = 1
    local visited = {}
    local gKey    = goalX * 100003 + goalZ
    visited[gKey] = true
    if not flowField[goalX] then flowField[goalX] = {} end
    flowField[goalX][goalZ] = {0, 0}
    local d1x, d1z =  NAV_STEP, 0
    local d2x, d2z = -NAV_STEP, 0
    local d3x, d3z =  0,  NAV_STEP
    local d4x, d4z =  0, -NAV_STEP
    while head <= #queue do
        local cx = queue[head][1]
        local cz = queue[head][2]
        head = head + 1
        local nx, nz, k
        for pass = 1, 4 do
            if     pass == 1 then nx = cx+d1x; nz = cz+d1z
            elseif pass == 2 then nx = cx+d2x; nz = cz+d2z
            elseif pass == 3 then nx = cx+d3x; nz = cz+d3z
            else                   nx = cx+d4x; nz = cz+d4z
            end
            k = nx * 100003 + nz
            if not visited[k] then
                visited[k] = true
                if navWalkable(nx, nz) then
                    local ddx = cx - nx
                    local ddz = cz - nz
                    if not flowField[nx] then flowField[nx] = {} end
                    flowField[nx][nz] = {ddx, ddz}
                    queue[#queue+1] = {nx, nz}
                end
            end
        end
    end
end
local function getFlowDir(wx, wz)
    local gx = navSnap(wx, 0)
    local gz = navSnap(wz, 0)
    local col = flowField[gx]
    if not col then return nil end
    local cell = col[gz]
    if not cell then return nil end
    return cell[1], cell[2]
end
local NAV_REBUILD_DIST = 2.0
local function updateFlowField()
    if flowOrigin.x == nil then
        buildFlowField()
        return
    end
    local dx = player.x - flowOrigin.x
    local dz = player.z - flowOrigin.z
    if dx*dx + dz*dz >= NAV_REBUILD_DIST * NAV_REBUILD_DIST then
        buildFlowField()
    end
end
local zombie = {}
function zombie.spawnZombie(enemyType)
    if #zombieSpawns == 0 then return end
    local spawn = zombieSpawns[math.random(1, #zombieSpawns)]
    enemyType = enemyType or "normal"
    local hp = getZombieHealth(roundState.currentRound)
    if ccz.boss.getDef(enemyType) then
        local bossHp = enemyType == "panzer" and (hp * 5) or hp
        local def = ccz.boss.getDef(enemyType)
        local prevHealth = def.health
        def.health = bossHp
        local boss = ccz.boss.spawn(enemyType, {x = spawn.x, y = spawn.y, z = spawn.z})
        def.health = prevHealth
        if boss then
            boss.lastAttackTime = 0
            boss.state          = "chasing"
            boss.velocityY      = 0
            boss.onGround       = true
            boss.height         = 1.8
            roundState.zombiesSpawned = roundState.zombiesSpawned + 1
        end
        return
    end
    local zombie = {
        x = spawn.x,  y = spawn.y,  z = spawn.z,
        type          = enemyType,
        health        = hp,
        maxHealth     = hp,
        speed         = getZombieSpeed(roundState.currentRound),
        lastAttackTime= 0,
        state         = "chasing",
        velocityY     = 0,
        onGround      = true,
        height        = 1.8,
        currentFrame  = 1,
        animTimer     = 0
    }
    table.insert(zombies, zombie)
    roundState.zombiesSpawned = roundState.zombiesSpawned + 1
end
function zombie.updateZombies(dt)
    for i = #zombies, 1, -1 do
        local zombie = zombies[i]
        if zombie.state == "chasing" then
            local dx = player.x - zombie.x
            local dz = player.z - zombie.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > 50 then
                dx = dx / dist
                dz = dz / dist
                zombie.x = zombie.x + dx * zombie.speed * 0.5
                zombie.z = zombie.z + dz * zombie.speed * 0.5
            elseif dist < 1.5 then
                zombie.state = "attacking"
            elseif dist > 0.1 then
                local fdx, fdz = getFlowDir(zombie.x, zombie.z)
                if fdx and fdz then
                    dx, dz = fdx, fdz
                else
                    dx = dx / dist
                    dz = dz / dist
                end
                local spd = zombie.speed
                local newX = zombie.x + dx * spd
                local newZ = zombie.z + dz * spd
                local canMove = not world.checkCollision(newX, zombie.y, newZ)
                local canMoveX = not world.checkCollision(newX, zombie.y, zombie.z)
                local canMoveZ = not world.checkCollision(zombie.x, zombie.y, newZ)
                local moveX, moveZ
                if canMove then
                    moveX, moveZ = newX, newZ
                elseif canMoveX then
                    moveX, moveZ = newX, zombie.z
                elseif canMoveZ then
                    moveX, moveZ = zombie.x, newZ
                else
                    local upY = zombie.y + 1
                    if not world.checkCollision(newX, upY, newZ) then
                        local groundAbove = world.findGroundBelow(newX, upY + 0.5, newZ, 2)
                        if groundAbove and (groundAbove - zombie.y) <= 2 then
                            zombie.y = groundAbove
                            zombie.x = newX
                            zombie.z = newZ
                        end
                    end
                    moveX, moveZ = nil, nil
                end
                if moveX then
                    local groundY = world.findGroundBelow(moveX, zombie.y + 0.5, moveZ, 3)
                    if groundY then
                        local heightDiff = groundY - zombie.y
                        if heightDiff <= 2 and heightDiff >= -10 then
                            zombie.x = moveX
                            zombie.z = moveZ
                            zombie.y = groundY
                            zombie.onGround = true
                        end
                    else
                        zombie.onGround = false
                    end
                end
            end
        elseif zombie.state == "attacking" then
            local dx = player.x - zombie.x
            local dz = player.z - zombie.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > 1.5 then
                zombie.state = "chasing"
            else
                local currentTime = os.epoch("utc") / 1000
                local attackRate = (ccz.boss.isBoss(zombie) and zombie._def and zombie._def.attackRate) or 1
                if currentTime - zombie.lastAttackTime >= attackRate then
                    local dmgAmount = (ccz.boss.isBoss(zombie) and zombie._def and zombie._def.damage) or 35
                    if not player._godMode then
                        player.health = player.health - dmgAmount
                    end
                    player.lastHitTime = currentTime
                    zombie.lastAttackTime = currentTime
                    if ccz.boss.isBoss(zombie) and zombie._def and zombie._def.onAttack then
                        pcall(zombie._def.onAttack, zombie, player)
                    end
                    player.stats.damageTaken = player.stats.damageTaken + dmgAmount
                    if player.health <= 0 and not player.isDowned then
                        player.stats.downs = player.stats.downs + 1
                        if not multiplayerState.isMultiplayer and player.quickRevive then
                            player.health = player.maxHealth
                            player.quickRevive = false
                            player.quickReviveUses = (player.quickReviveUses or 0) + 1
                            for i, perk in ipairs(player.perks) do
                                if perk == "perk_revive" then
                                    table.remove(player.perks, i)
                                    break
                                end
                            end
                            if player.quickReviveUses >= 3 then
                                for _, m in ipairs(perkMachines) do
                                    if m.type == "perk_revive" then
                                        m.purchased = true
                                        break
                                    end
                                end
                            end
                        elseif not multiplayerState.isMultiplayer and player.whosWho and not player.inAfterlife then
                            player.inAfterlife = true
                            player.afterlifeBodyPos = {x = player.x, y = player.y, z = player.z}
                            player.afterlifePerks = {}
                            for i, perk in ipairs(player.perks) do
                                player.afterlifePerks[i] = perk
                            end
                            player.health = 100
                            player.afterlifeTimeLeft = 30
                            player.afterlifeStartTime = os.epoch("utc") / 1000
                            player.isDowned = false
                        else
                            player.isDowned = true
                            player.downedTime = currentTime
                            player.health = 1
                            player.reviveProgress = 0
                            local _md = CCZLoader.currentMap
                            if _md and _md.onPlayerDowned then
                                pcall(_md.onPlayerDowned, gameStateVars, player)
                            end
                        end
                    end
                end
            end
        end
        if ccz.boss.isBoss(zombie) and zombie.health > 0 then
            if zombie.type ~= "panzer" then
                local prevHp = zombie._prevHealth or zombie.health
                ccz.boss.update(zombie, dt, prevHp)
                zombie._prevHealth = zombie.health
            end
        end
        if zombie.health <= 0 then
            local shouldRemove = false
            if zombie._dying then
                local elapsed = os.epoch("utc") / 1000 - (zombie._deathTime or 0)
                if elapsed >= 0.8 then
                    shouldRemove = true
                end
            else
                local mapData = CCZLoader.currentMap
                if mapData and mapData.onZombieKill then
                    pcall(mapData.onZombieKill, gameStateVars, zombie, player)
                end
                if ccz.boss.isBoss(zombie) then
                    ccz.boss.update(zombie, 0, zombie.health + 1)
                end
                if not zombie._dying then
                    shouldRemove = true
                end
            end
            if shouldRemove then
                table.remove(zombies, i)
                roundState.zombiesKilled = roundState.zombiesKilled + 1
                if not zombie._killedBySplash then
                    player.kills = player.kills + 1
                    local killPts
                    if ccz.boss.isBoss(zombie) then
                        killPts = (zombie._def and zombie._def.killPoints) or 500
                        ccz.game.announce("+" .. killPts .. " BONUS POINTS!", 2.5)
                    elseif zombie._killedByMelee then
                        killPts = 0
                    elseif zombie._killedByPlayer then
                        killPts = zombie._headshotKill and 100 or 50
                    else
                        killPts = 100
                    end
                    player.points = player.points + killPts
                end
            end
        end
    end
end
local function loadVoxelModel(filename)
    local raw = loadMapData(filename)
    if not raw or not raw.frames then
        print("[VoxelModel] Failed to load: " .. tostring(filename))
        return nil
    end
    local res = raw.res or 0.25
    local def = {
        res        = res,
        frameCount = #raw.frames,
        frames     = {},
        _geomCache = {}
    }
    local cache = def._geomCache
    for fi, rawFrame in ipairs(raw.frames) do
        local builtFrame = {}
        for _, entry in ipairs(rawFrame) do
            local ox    = entry[1] * res
            local oy    = entry[2] * res
            local oz    = entry[3] * res
            local sizeX = entry[4] * res
            local sizeY = entry[5] * res
            local sizeZ = entry[6] * res
            local color = entry[7]
            local key = sizeX .. "_" .. sizeY .. "_" .. sizeZ .. "_" .. color
            if not cache[key] then
                cache[key] = createBox(sizeX, sizeY, sizeZ, color)
            end
            table.insert(builtFrame, {box = cache[key], ox = ox, oy = oy, oz = oz})
        end
        def.frames[fi] = builtFrame
    end
    return def
end
local specialModels = {
    _sirenPending = false,
    _shake        = nil,
}
local function playPanzerSiren()
    if fs.exists("panzer.dfpwm") and not specialModels._sirenPending then
        local speaker = peripheral.find("speaker")
        if speaker then
            specialModels._sirenPending = true
            local sirenKey = "__siren__" .. tostring(os.epoch("utc"))
            pendingSoundRequests[sirenKey] = {
                speaker  = speaker,
                volume   = 1,
                _isLocal = true,
                _file    = "panzer.dfpwm",
                _key     = sirenKey
            }
        end
    end
    specialModels._shake = {
        startTime = os.epoch("utc") / 1000,
        duration  = 0.3,
        magnitude = 2
    }
end
local function updateSpecialAudio(dt)
    for key, req in pairs(pendingSoundRequests) do
        if req._isLocal then
            pendingSoundRequests[key] = nil
            specialModels._sirenPending = false
            local speaker = req.speaker
            if speaker and fs.exists(req._file) then
                local decoder = dfpwm.make_decoder()
                local file = fs.open(req._file, "rb")
                local chunk = file.read(16 * 1024)
                while chunk do
                    local buf = decoder(chunk)
                    speaker.playAudio(buf, 1.0)
                    chunk = file.read(16 * 1024)
                end
                file.close()
            end
        end
    end
    if specialModels._shake then
        local elapsed = os.epoch("utc") / 1000 - specialModels._shake.startTime
        if elapsed < specialModels._shake.duration then
            local t = elapsed / specialModels._shake.duration
            player.rotZ = player.rotZ + math.sin(t * math.pi * 6) * specialModels._shake.magnitude * (1 - t)
        else
            specialModels._shake = nil
        end
    end
end
local function initializeSpecialModels()
    ccz.animation.define("panzer", {
        walk     = {frames = {1, 1}, loop = true,  fps = 4},
        flameOut = {frames = {1, 1}, loop = true,  fps = 6},
        death    = {frames = {1, 1}, loop = false, fps = 4, onEnd = "dead"},
        dead     = {frames = {1, 1}, loop = false, fps = 1},
    })
    ccz.boss.register("panzer", {
        model      = "models/panzermodel.json",
        health     = nil,
        speed      = 0.14,
        damage     = 50,
        attackRate = 1.0,
        killPoints = 500,
        animation  = "panzer",
        phases = {
            {healthPct = 1.0, state = "walk",     speed = 0.14},
            {healthPct = 0.66, state = "flameOut", speed = 0.20,
                onEnter = function(boss)
                    ccz.game.announce("Panzer Soldát ENRAGED!", 2)
                end
            },
            {healthPct = 0.33, state = "walk",    speed = 0.28},
        },
        onSpawn = function(boss)
            playPanzerSiren()
        end,
        onAttack = function(boss, target)
            specialModels._shake = {
                startTime = os.epoch("utc") / 1000,
                duration  = 0.2,
                magnitude = 1.5
            }
        end,
        onDeath = function(boss)
            boss._dying     = true
            boss._deathTime = os.epoch("utc") / 1000
            if boss.animState then
                ccz.animation.setState(boss.animState, "death")
            end
            ccz.game.announce("Panzer Soldát destroyed!", 3)
        end,
    })
    for bossType, def in pairs(ccz.boss._getAllDefs()) do
        if def.model and type(def.model) == "string" and def.model:match("%.json$") then
            local modelFile = fs.exists(def.model)               and def.model
                           or fs.exists("maps/" .. def.model)    and "maps/" .. def.model
                           or nil
            if modelFile then
                specialModels[bossType] = loadVoxelModel(modelFile)
            end
        end
    end
    if not specialModels.panzer then
        local legacy = fs.exists("models/panzermodel.json") and "models/panzermodel.json"
                    or fs.exists("panzermodel.json")        and "panzermodel.json"
                    or nil
        if legacy then specialModels.panzer = loadVoxelModel(legacy) end
    end
end
local audioStreams = {
    eeSong = {
        playing = false,
        handle = nil,
        decoder = nil,
        url = nil,
        buffer = nil,
        start = nil,
        size = 16 * 1024
    },
    jingle = {
        playing = false,
        handle = nil,
        decoder = nil,
        url = nil,
        buffer = nil,
        start = nil,
        size = 16 * 1024,
        currentPerk = nil,
        cooldown = 0
    }
}
local lastNearPerk = nil
local function stopEESong()
    audioStreams.eeSong.playing = false
    if audioStreams.eeSong.handle then
        audioStreams.eeSong.handle.close()
        audioStreams.eeSong.handle = nil
    end
    audioStreams.eeSong.decoder = nil
    audioStreams.eeSong.buffer = nil
    audioStreams.eeSong.url = nil
    local speaker = peripheral.find("speaker")
    if speaker then
        speaker.stop()
    end
end
local function startEESong()
    stopEESong()
    local mapInfo = CCZLoader.currentMap
    if not mapInfo or not mapInfo.eeSongId then
        return
    end
    local speaker = peripheral.find("speaker")
    if not speaker then
        return
    end
    local apiBase = "https://" .. "ipod-2to6magyna-uc" .. ".a.run.app/"
    audioStreams.eeSong.url = apiBase .. "?v=2.1&id=" .. mapInfo.eeSongId
    http.request({url = audioStreams.eeSong.url, binary = true})
    audioStreams.eeSong.playing = true
    audioStreams.eeSong.decoder = dfpwm.make_decoder()
end
local function updateEESong()
    if not audioStreams.eeSong.playing then return end
    local speaker = peripheral.find("speaker")
    if not speaker then
        stopEESong()
        return
    end
    if audioStreams.eeSong.handle and audioStreams.eeSong.buffer then
        if speaker.playAudio(audioStreams.eeSong.buffer, 1.0) then
            audioStreams.eeSong.buffer = nil
        end
        return
    end
    if audioStreams.eeSong.handle and not audioStreams.eeSong.buffer then
        local chunk = audioStreams.eeSong.handle.read(audioStreams.eeSong.size)
        if not chunk then
            stopEESong()
            return
        else
            if audioStreams.eeSong.start then
                chunk = audioStreams.eeSong.start .. chunk
                audioStreams.eeSong.start = nil
                audioStreams.eeSong.size = audioStreams.eeSong.size + 4
            end
            audioStreams.eeSong.buffer = audioStreams.eeSong.decoder(chunk)
        end
    end
end
local function stopJingle()
    audioStreams.jingle.playing = false
    if audioStreams.jingle.handle then
        audioStreams.jingle.handle.close()
        audioStreams.jingle.handle = nil
    end
    audioStreams.jingle.decoder = nil
    audioStreams.jingle.buffer = nil
    audioStreams.jingle.url = nil
    audioStreams.jingle.currentPerk = nil
end
local function startJingle(perkType)
    if audioStreams.eeSong.playing or audioStreams.jingle.playing then
        return
    end
    if audioStreams.jingle.cooldown > 0 then
        return
    end
    local jingleId = PERK_JINGLES[perkType]
    if not jingleId then
        return
    end
    local speaker = peripheral.find("speaker")
    if not speaker then
        return
    end
    local apiBase = "https://" .. "ipod-2to6magyna-uc" .. ".a.run.app/"
    audioStreams.jingle.url = apiBase .. "?v=2.1&id=" .. jingleId
    http.request({url = audioStreams.jingle.url, binary = true})
    audioStreams.jingle.playing = true
    audioStreams.jingle.decoder = dfpwm.make_decoder()
    audioStreams.jingle.currentPerk = perkType
    audioStreams.jingle.cooldown = 5
end
local function updateJingle(dt)
    if audioStreams.jingle.cooldown > 0 then
        audioStreams.jingle.cooldown = math.max(0, audioStreams.jingle.cooldown - dt)
    end
    if not audioStreams.jingle.playing then return end
    local speaker = peripheral.find("speaker")
    if not speaker then
        stopJingle()
        return
    end
    local distToSource = 999
    if audioStreams.jingle.currentPerk then
        if audioStreams.jingle.currentPerk == "pack_a_punch" then
            for _, pap in ipairs(papMachines) do
                local dx = player.x - pap.pos.x
                local dz = player.z - pap.pos.z
                local dist = math.sqrt(dx*dx + dz*dz)
                if dist < distToSource then
                    distToSource = dist
                end
            end
        else
            for _, machine in ipairs(perkMachines) do
                if machine.type == audioStreams.jingle.currentPerk then
                    local dx = player.x - machine.pos.x
                    local dz = player.z - machine.pos.z
                    local dist = math.sqrt(dx*dx + dz*dz)
                    if dist < distToSource then
                        distToSource = dist
                    end
                    break
                end
            end
        end
    end
    local volume = math.max(0, 1.0 - (distToSource * 0.1))
    if volume <= 0 then
        stopJingle()
        return
    end
    if audioStreams.jingle.handle and audioStreams.jingle.buffer then
        if speaker.playAudio(audioStreams.jingle.buffer, volume) then
            audioStreams.jingle.buffer = nil
        end
        return
    end
    if audioStreams.jingle.handle and not audioStreams.jingle.buffer then
        local chunk = audioStreams.jingle.handle.read(audioStreams.jingle.size)
        if not chunk then
            stopJingle()
            return
        else
            if audioStreams.jingle.start then
                chunk = audioStreams.jingle.start .. chunk
                audioStreams.jingle.start = nil
                audioStreams.jingle.size = audioStreams.jingle.size + 4
            end
            audioStreams.jingle.buffer = audioStreams.jingle.decoder(chunk)
        end
    end
end
local perkProximityTimer = 0
local function checkPerkProximity(dt)
    perkProximityTimer = perkProximityTimer + dt
    if perkProximityTimer < 0.2 then
        return
    end
    perkProximityTimer = 0
    if audioStreams.jingle.playing or audioStreams.jingle.cooldown > 0 then
        return
    end
    local JINGLE_RANGE = 10
    local nearestPerk = nil
    local nearestDist = JINGLE_RANGE
    for _, machine in ipairs(perkMachines) do
        if PERK_JINGLES[machine.type] then
            local dx = player.x - machine.pos.x
            local dz = player.z - machine.pos.z
            local distSq = dx*dx + dz*dz
            if distSq < nearestDist * nearestDist then
                nearestDist = math.sqrt(distSq)
                nearestPerk = machine.type
            end
        end
    end
    for _, pap in ipairs(papMachines) do
        local dx = player.x - pap.pos.x
        local dz = player.z - pap.pos.z
        local distSq = dx*dx + dz*dz
        if distSq < nearestDist * nearestDist then
            nearestDist = math.sqrt(distSq)
            nearestPerk = "pack_a_punch"
        end
    end
    if nearestPerk and nearestPerk ~= lastNearPerk then
        startJingle(nearestPerk)
    end
    lastNearPerk = nearestPerk
end
local function renderVoxelModel(modelDef, entity, dt)
    if not modelDef or not modelDef.frames or #modelDef.frames == 0 then return end
    local dx = player.x - entity.x
    local dz = player.z - entity.z
    local angle = math.atan2(dz, dx) + math.pi
    local sinA  = math.sin(angle)
    local cosA  = math.cos(angle)
    local frameIdx = 1
    if entity.animState then
        frameIdx = ccz.animation.update(entity.animState, dt)
        entity.currentFrame = frameIdx
    else
        entity.animTimer = (entity.animTimer or 0) + dt
        if entity.animTimer >= 0.25 then
            entity.animTimer = 0
            local fc = math.max(1, modelDef.frameCount)
            entity.currentFrame = ((entity.currentFrame or 1) % fc) + 1
        end
        frameIdx = entity.currentFrame or 1
    end
    frameIdx = math.max(1, math.min(frameIdx, #modelDef.frames))
    local builtFrame = modelDef.frames[frameIdx]
    if not builtFrame then return end
    local deathFlash = entity._dying and
        (os.epoch("utc") / 1000 - (entity._deathTime or 0)) < 0.4
    for _, vox in ipairs(builtFrame) do
        local rx = vox.ox * cosA - vox.oz * sinA
        local rz = vox.ox * sinA + vox.oz * cosA
        local box = deathFlash and createBox(
            math.abs(vox.ox) > 0 and math.abs(vox.ox) * 2 or 0.25,
            math.abs(vox.oy) > 0 and math.abs(vox.oy) * 2 or 0.25,
            math.abs(vox.oz) > 0 and math.abs(vox.oz) * 2 or 0.25,
            colors.white
        ) or vox.box
        local obj = frame:newObject(box, entity.x + rx, entity.y + vox.oy, entity.z + rz)
        table.insert(renderedObjects, obj)
    end
end
local function drawPanzer(z, dt)
    local model = specialModels.panzer
    if not model then return end
    if not z.animState then
        z.animState = ccz.animation.newState("panzer", "walk")
    end
    local prevHealth = z._prevHealth or z.health
    ccz.boss.update(z, dt, prevHealth)
    z._prevHealth = z.health
    renderVoxelModel(model, z, dt)
end
function zombie.renderZombies(dt)
    local ZOMBIE_RENDER_DISTANCE = 50
    for _, z in ipairs(zombies) do
        local dx = player.x - z.x
        local dz = player.z - z.z
        local distSq = dx*dx + dz*dz
        if distSq > (ZOMBIE_RENDER_DISTANCE * ZOMBIE_RENDER_DISTANCE) then
            goto continue
        end
        if z.type == "panzer" then
            drawPanzer(z, dt or 0.05)
        elseif ccz.boss.isBoss(z) and specialModels[z.type] then
            if not z.animState then
                z.animState = ccz.animation.newState(z.type, "walk")
            end
            renderVoxelModel(specialModels[z.type], z, dt or 0.05)
        else
            if not cachedEntityModels.zombieBox then
                cachedEntityModels.zombieBox = createBox(0.8, 2.5, 0.8, colors.green)
            end
            local obj = frame:newObject(cachedEntityModels.zombieBox, z.x, z.y + 1.25, z.z)
            table.insert(renderedObjects, obj)
        end
        ::continue::
    end
end
function zombie.startRound(roundNum)
    roundState.currentRound = roundNum
    roundState.zombiesThisRound = getZombieCount(roundNum)
    roundState.zombiesSpawned = 0
    roundState.zombiesKilled = 0
    roundState.roundActive = true
    roundState.roundEndTime = 0
    roundState.lastSpawnTime = os.epoch("utc") / 1000
    roundState.panzerSpawnedThisRound = false
    if roundNum > 1 then
        local bonus = (roundNum - 1) * 200
        player.points = player.points + bonus
    end
    roundTransition.phase     = "incoming"
    roundTransition.round     = roundNum
    roundTransition.startTime = os.epoch("utc") / 1000
    if roundNum <= 5 then
        roundState.spawnDelay = 2
    elseif roundNum <= 10 then
        roundState.spawnDelay = 1.5
    else
        roundState.spawnDelay = 1
    end
end
function zombie.checkRoundEvents()
    if (gameStateVars.currentMap == "Tranzit" or gameStateVars.currentMap == "Origins") then
        if roundState.currentRound == 8 and not roundState.panzerSpawnedThisRound then
            if #zombies < 5 then
                zombie.spawnZombie("panzer")
                roundState.panzerSpawnedThisRound = true
            end
        end
    end
end
function zombie.updateRound(dt)
    if not multiplayerState.isMultiplayer or isHost then
        if not roundState.roundActive then
            local currentTime = os.epoch("utc") / 1000
            if currentTime - roundState.roundEndTime >= 5 then
                zombie.startRound(roundState.currentRound + 1)
            end
            return
        end
        local currentTime = os.epoch("utc") / 1000
        if roundState.zombiesSpawned < roundState.zombiesThisRound and
           #zombies < MAX_ZOMBIES_ALIVE and
           currentTime - roundState.lastSpawnTime >= roundState.spawnDelay then
            zombie.spawnZombie()
            roundState.lastSpawnTime = currentTime
        end
        zombie.checkRoundEvents()
        if roundState.zombiesSpawned >= roundState.zombiesThisRound and #zombies == 0 then
            roundState.roundActive = false
            roundState.roundEndTime = os.epoch("utc") / 1000
            roundTransition.phase     = "clear"
            roundTransition.round     = roundState.currentRound
            roundTransition.startTime = os.epoch("utc") / 1000
        end
    end
end
local entity = {}
function entity.revivePlayer(downedPlayer)
    if not downedPlayer then return false end
    downedPlayer.isDowned = false
    downedPlayer.health = downedPlayer.maxHealth / 2
    downedPlayer.reviveProgress = 0
    player.stats.revives = player.stats.revives + 1
    return true
end
function entity.getNearestDownedPlayer()
    if not multiplayerState.isMultiplayer then return nil, nil end
    local nearestDist = 2
    local nearest = nil
    local nearestID = nil
    for playerID, otherPlayer in pairs(players) do
        if otherPlayer.isDowned then
            local dx = player.x - otherPlayer.x
            local dz = player.z - otherPlayer.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < nearestDist then
                nearestDist = dist
                nearest = otherPlayer
                nearestID = playerID
            end
        end
    end
    return nearest, nearestID
end
function entity.getNearestDoor()
    local nearestDoor = nil
    local nearestDist = 3
    for _, door in ipairs(doors) do
        if not door.opened then
            local minX, minY, minZ = door.bounds.min[1], door.bounds.min[2], door.bounds.min[3]
            local maxX, maxY, maxZ = door.bounds.max[1], door.bounds.max[2], door.bounds.max[3]
            local centerX = (minX + maxX) / 2
            local centerZ = (minZ + maxZ) / 2
            local dx = player.x - centerX
            local dz = player.z - centerZ
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < nearestDist then
                nearestDoor = door
                nearestDist = dist
            end
        end
    end
    return nearestDoor
end
function entity.openDoor(door)
    if player.points >= door.cost then
        player.points = player.points - door.cost
        door.opened = true
        for _, blockKey in ipairs(door.blocks) do
            solidBlocks[blockKey] = nil
        end
        local b = door.bounds
        for _, chunk in pairs(worldChunks) do
            for _, mesh in ipairs(chunk) do
                if mesh.min[1] <= b.max[1] and mesh.max[1] >= b.min[1] and
                   mesh.min[2] <= b.max[2] and mesh.max[2] >= b.min[2] and
                   mesh.min[3] <= b.max[3] and mesh.max[3] >= b.min[3] then
                    local mk = mesh.min[1]..","..mesh.min[2]..","..mesh.min[3]..","..mesh.max[1]..","..mesh.max[2]..","..mesh.max[3]
                    openedDoorMeshKeys[mk] = true
                end
            end
        end
        ccz.game.announce("Door opened! -"..door.cost.." points", 2)
    else
        ccz.game.announce("Need "..door.cost.." points to open!", 2)
    end
end
function entity.isPlayerWithinAABB(minX, minY, minZ, maxX, maxY, maxZ)
    local margin = 0.6
    local px, py, pz = player.x, player.y, player.z
    if px + margin < minX or px - margin > maxX then return false end
    if pz + margin < minZ or pz - margin > maxZ then return false end
    if py + player.height < minY or py > maxY + margin then return false end
    return true
end
function entity.getNearestPerkMachine()
    local nearest = nil
    local nearestDist = 3
    for _, m in ipairs(perkMachines) do
        if not m.purchased then
            if entity.isPlayerWithinAABB(m.bounds.minX, m.bounds.minY, m.bounds.minZ, m.bounds.maxX, m.bounds.maxY, m.bounds.maxZ) then
                return m
            end
            local cx = (m.bounds.minX + m.bounds.maxX) / 2
            local cz = (m.bounds.minZ + m.bounds.maxZ) / 2
            local dx = player.x - cx
            local dz = player.z - cz
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < nearestDist then
                nearest = m
                nearestDist = dist
            end
        end
    end
    return nearest
end
function entity.getNearestMysteryBox()
    local nearest, nearestDist = nil, 3
    for _, box in ipairs(mysteryBoxes) do
        local dx = player.x - box.pos.x
        local dz = player.z - box.pos.z
        local dist = math.sqrt(dx*dx + dz*dz)
        if dist < nearestDist then nearest=box; nearestDist=dist end
    end
    return nearest
end
function entity.getNearestPaP()
    for _, machine in ipairs(papMachines) do
        if entity.isPlayerWithinAABB(machine.bounds.minX, machine.bounds.minY, machine.bounds.minZ,
                              machine.bounds.maxX, machine.bounds.maxY, machine.bounds.maxZ) then
            return machine
        end
    end
    return nil
end
function entity.packAPunchWeapon()
    local w = getActiveWeapon()
    if not w then return false, "No weapon" end
    if w.isPaP then return false, "Already upgraded" end
    if player.points < 5000 then return false, "Not enough points" end
    if hasPowerSwitch and not powerOn then
        return false, "Power must be on"
    end
    local template = WEAPONS[w.id]
    if not template or not template.papName then
        return false, "Cannot upgrade"
    end
    player.points = player.points - 5000
    w.name = template.papName
    w.damage = template.papDamage
    w.mag = template.papMag
    w.ammo = template.papMag
    w.reserve = template.papReserve
    w.isPaP = true
    return true
end
function entity.getNearestPowerSwitch()
    if not powerSwitches then return nil end
    for _, switch in ipairs(powerSwitches) do
        if not switch.activated then
            local dx = player.x - switch.pos.x
            local dz = player.z - switch.pos.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < 2 then
                return switch
            end
        end
    end
    return nil
end
function entity.activatePowerSwitch(switch)
    if not switch then return false end
    switch.activated = true
    powerOn = true
    if multiplayerState.isMultiplayer and multiplayerState.ws and multiplayerState.wsConnected and isHost then
        multiplayerState.ws.send(textutils.serializeJSON({
            type = "power_activated"
        }))
    end
    return true
end
function renderWorld()
    frame:setCamera(camera)
    renderedObjects = {}
    world.renderMap()
    renderPerkMachines()
    renderPaPMachines()
    renderPowerSwitches()
    renderMysteryBoxes()
    zombie.renderZombies(0)
    renderPlayers()
    frame:drawObjects(renderedObjects)
    frame:drawBuffer()
end
local dlcConfig = {
    manifestUrl = "https://raw.githubusercontent.com/DrNightheart/CC-Zombies-Downloadable-Assets/main/maps.json",
    mapsFolder = "maps/"
}
local dlcState = {maps = {}, sel = 1, err = nil}
local function dlcFetch()
    dlcState.err = nil
    local r = http.get(dlcConfig.manifestUrl)
    if not r then dlcState.err = "Failed to connect"; return false end
    local c = r.readAll(); r.close()
    local m = textutils.unserializeJSON(c)
    if not m or not m.maps then dlcState.err = "Invalid format"; return false end
    dlcState.maps = m.maps
    return true
end
local function dlcDownload(info)
    if not fs.exists(dlcConfig.mapsFolder) then fs.makeDir(dlcConfig.mapsFolder) end
    local r = http.get(info.url)
    if not r then dlcState.err = "Download failed"; return false end
    local rawContent = r.readAll(); r.close()
    local f = fs.open(dlcConfig.mapsFolder .. info.file, "w")
    if not f then dlcState.err = "Save failed"; return false end
    f.write(rawContent); f.close()
    return true
end
local function dlcInstalled(file)
    return fs.exists(dlcConfig.mapsFolder .. file) or fs.exists(file)
end
local function dlcCanDL(size)
    return fs.getFreeSpace("/") >= (size * 1024)
end
local function dlcDraw()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2-10), 2)
    term.setTextColor(colors.red)
    term.write("CC ZOMBIES DLC")
    term.setCursorPos(math.floor(w/2-8), 3)
    term.setTextColor(colors.gray)
    term.write("================")
    if #dlcState.maps == 0 then
        term.setCursorPos(math.floor(w/2-10), math.floor(h/2))
        term.setTextColor(colors.yellow)
        term.write("Fetching...")
        return
    end
    local anyOk = false
    for _, m in ipairs(dlcState.maps) do
        if dlcCanDL(m.size or 0) then anyOk = true; break end
    end
    if not anyOk then
        term.setCursorPos(2, math.floor(h/2))
        term.setTextColor(colors.red)
        term.write("Uh oh! Not able to download any content")
        term.setCursorPos(2, math.floor(h/2)+1)
        term.write("due to low storage. Apologies!")
        term.setCursorPos(2, h-2)
        term.setTextColor(colors.lightGray)
        term.write("` - Back")
        return
    end
    for i = 1, math.min(#dlcState.maps, 10) do
        local m = dlcState.maps[i]
        local y = 7 + (i-1)*2
        if i == dlcState.sel then
            term.setCursorPos(2, y)
            term.setTextColor(colors.yellow)
            term.write(">")
        end
        term.setCursorPos(4, y)
        if dlcInstalled(m.file) then
            term.setTextColor(colors.lime)
            term.write("[INSTALLED] ")
        end
        if not dlcCanDL(m.size or 0) and not dlcInstalled(m.file) then
            term.setTextColor(colors.red)
        else
            term.setTextColor(colors.white)
        end
        term.write(m.name)
        local sz = " - "..(m.size or "?").." KB"
        term.setCursorPos(w-#sz-1, y)
        term.write(sz)
    end
    local sel = dlcState.maps[dlcState.sel]
    if sel then
        local infoY = h - 6
        term.setCursorPos(2, infoY)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.clearLine()
        local desc = (sel.description and sel.description ~= "") and sel.description or "No description"
        term.write(desc:sub(1, w-3))
        term.setCursorPos(2, infoY + 1)
        term.clearLine()
        if sel.author then
            term.setTextColor(colors.gray)
            term.write("by " .. sel.author .. (sel.version and ("  v"..sel.version) or ""))
        end
    end
    if dlcState.err then
        term.setCursorPos(2, h-4)
        term.setTextColor(colors.red)
        term.write(dlcState.err)
    end
    term.setCursorPos(2, h-2)
    term.setTextColor(colors.lightGray)
    term.write("UP/DOWN | ENTER - Download/Update | R - Refresh | ` - Back")
end
local function dlcHandle()
    if #dlcState.maps == 0 then
        dlcDraw()
        sleep(0.5)
        if not dlcFetch() then
            while gameStateVars.current == "dlc_menu" do
                dlcDraw()
                local ev, k = os.pullEvent("key")
                if k == keys.grave then
                    gameStateVars.current = "main_menu"
                    selectedMenuIdx = 1
                    return
                end
            end
            return
        end
    end
    while gameStateVars.current == "dlc_menu" do
        dlcDraw()
        local anyOk = false
        for _, m in ipairs(dlcState.maps) do
            if dlcCanDL(m.size or 0) then anyOk = true; break end
        end
        local ev, k = os.pullEvent("key")
        if not anyOk then
            if k == keys.grave then
                gameStateVars.current = "main_menu"
                selectedMenuIdx = 1
                break
            end
        else
            if k == keys.up then
                dlcState.sel = math.max(1, dlcState.sel - 1)
            elseif k == keys.down then
                dlcState.sel = math.min(#dlcState.maps, dlcState.sel + 1)
            elseif k == keys.enter and #dlcState.maps > 0 then
                local m = dlcState.maps[dlcState.sel]
                if not dlcCanDL(m.size or 0) and not dlcInstalled(m.file) then
                    dlcState.err = "Not enough space"
                    sleep(1)
                    dlcState.err = nil
                else
                    local wasInstalled = dlcInstalled(m.file)
                    if dlcDownload(m) then
                        dlcState.err = wasInstalled and "Updated!" or "Download complete!"
                        sleep(1)
                        dlcState.err = nil
                        checkAvailableMaps()
                    else
                        sleep(2)
                    end
                end
            elseif k == keys.r then
                dlcState.maps = {}
                dlcState.err = nil
                if not dlcFetch() then
                    sleep(1)
                end
            elseif k == keys.grave then
                gameStateVars.current = "main_menu"
                selectedMenuIdx = 1
                break
            end
        end
    end
end
function entity.purchasePerkMachine(machine)
    if not machine then return false, "Invalid machine" end
    local cost = PERK_COSTS[machine.type]
    if type(cost) == "function" then cost = cost() end
    if cost == nil then
        return false, "Perk not for sale"
    end
    if player.points < cost then
        return false, "Not enough points"
    end
    player.points = player.points - cost
    machine.purchased = true
    table.insert(player.perks, machine.type)
    if machine.type == "perk_juggernog" then
        player.maxHealth = 250
        player.health = math.min(player.maxHealth, player.health + 150)
    elseif machine.type == "perk_speedcola" then
        player.reloadMultiplier = player.reloadMultiplier * 0.5
    elseif machine.type == "perk_revive" then
        player.quickRevive = true
    elseif machine.type == "perk_mulekick" then
        player.maxWeaponSlots = 3
        player.weapons[3] = player.weapons[3] or nil
    elseif machine.type == "perk_staminup" then
    elseif machine.type == "perk_whoswho" then
        player.whosWho = true
    elseif machine.type == "perk_phd" then
        player.phdFlopper = true
    elseif machine.type == "perk_cherry" then
        player.electricCherry = true
    elseif machine.type == "perk_doubletap" then
        player.doubleTap = true
    end
    if multiplayerState.isMultiplayer and multiplayerState.ws and multiplayerState.wsConnected and not isHost then
        multiplayerState.ws.send(textutils.serializeJSON({
            type = "purchase_perk",
            lobbyId = lobbyID,
            playerID = myPlayerID,
            perk = machine.type
        }))
    end
    return true
end
local MENU_SONGS = {
    { id = "uIpTKRWEJzI", name = "Beauty of Annihilation (Remix)" },
    { id = "suyHYn91wmc", name = "The Gift (Remix)" },
    { id = "_4MvHGw62CI", name = "Damned 100ae" },
}
local menuMusic = {
    playing      = false,
    songIndex    = 1,
    songName     = "",
    handle       = nil,
    downloadUrl  = nil,
    stopSignal   = false,
    shuffleOrder = {},
    shufflePos   = 0,
}
local function buildShuffleOrder()
    local order = {}
    for i = 1, #MENU_SONGS do order[i] = i end
    for i = #order, 2, -1 do
        local j = math.random(1, i)
        order[i], order[j] = order[j], order[i]
    end
    return order
end
local function startMenuMusic(index)
    local actualIndex
    if index then
        actualIndex = ((index - 1) % #MENU_SONGS) + 1
    else
        menuMusic.shufflePos = menuMusic.shufflePos + 1
        if menuMusic.shufflePos > #menuMusic.shuffleOrder then
            menuMusic.shuffleOrder = buildShuffleOrder()
            menuMusic.shufflePos   = 1
            if #MENU_SONGS > 1 and menuMusic.shuffleOrder[1] == menuMusic.songIndex then
                menuMusic.shuffleOrder[1], menuMusic.shuffleOrder[2] =
                    menuMusic.shuffleOrder[2], menuMusic.shuffleOrder[1]
            end
        end
        actualIndex = menuMusic.shuffleOrder[menuMusic.shufflePos]
    end
    local song    = MENU_SONGS[actualIndex]
    local apiBase = "https://" .. "ipod-2to6magyna-uc" .. ".a.run.app/"
    menuMusic.stopSignal  = true
    menuMusic.playing     = true
    menuMusic.songIndex   = actualIndex
    menuMusic.songName    = song.name
    menuMusic.handle      = nil
    menuMusic.downloadUrl = apiBase .. "?v=2.1&id=" .. song.id
    local speaker = peripheral.find("speaker")
    if speaker then
        speaker.stop()
        os.queueEvent("playback_stopped")
    end
    http.request({ url = menuMusic.downloadUrl, binary = true })
    os.queueEvent("menu_audio_update")
end
local function stopMenuMusic()
    menuMusic.playing    = false
    menuMusic.stopSignal = true
    if menuMusic.handle then
        menuMusic.handle.close()
        menuMusic.handle = nil
    end
    local speaker = peripheral.find("speaker")
    if speaker then
        speaker.stop()
        os.queueEvent("playback_stopped")
    end
end
local function drawNowPlaying()
    if not menuMusic.playing or menuMusic.songName == "" then return end
    local w, h = term.getSize()
    local txt = "Now Playing -- " .. menuMusic.songName
    term.setCursorPos(math.max(1, math.floor(w/2 - #txt/2)), h)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.write(txt)
end
local function menuMusicAudioLoop()
    local decoder = dfpwm.make_decoder()
    while true do
        if not menuMusic.playing or not menuMusic.handle then
            os.pullEvent("menu_audio_update")
        else
            local speaker = peripheral.find("speaker")
            if not speaker then
                os.pullEvent("menu_audio_update")
            else
                local handle       = menuMusic.handle
                local thisUrl      = menuMusic.downloadUrl
                local speakerName  = peripheral.getName(speaker)
                menuMusic.stopSignal = false
                local startBytes = handle.read(4)
                local size = 16 * 1024 - 4
                while true do
                    if menuMusic.stopSignal or menuMusic.downloadUrl ~= thisUrl then
                        break
                    end
                    local chunk = handle.read(size)
                    if not chunk then
                        handle.close()
                        menuMusic.handle = nil
                        startMenuMusic(nil)
                        break
                    end
                    if startBytes then
                        chunk      = startBytes .. chunk
                        startBytes = nil
                        size       = size + 4
                    end
                    local buffer = decoder(chunk)
                    while not speaker.playAudio(buffer, 1.0) do
                        parallel.waitForAny(
                            function()
                                repeat until select(2, os.pullEvent("speaker_audio_empty")) == speakerName
                            end,
                            function()
                                os.pullEvent("playback_stopped")
                            end
                        )
                        if menuMusic.stopSignal or menuMusic.downloadUrl ~= thisUrl then
                            break
                        end
                    end
                    if menuMusic.stopSignal or menuMusic.downloadUrl ~= thisUrl then
                        break
                    end
                    parallel.waitForAny(
                        function()
                            repeat until select(2, os.pullEvent("speaker_audio_empty")) == speakerName
                        end,
                        function()
                            os.pullEvent("playback_stopped")
                        end
                    )
                    if menuMusic.stopSignal or menuMusic.downloadUrl ~= thisUrl then
                        break
                    end
                end
                decoder = dfpwm.make_decoder()
            end
        end
    end
end
local function menuMusicHttpLoop()
    while true do
        parallel.waitForAny(
            function()
                local _, url, handle = os.pullEvent("http_success")
                if url == menuMusic.downloadUrl then
                    menuMusic.handle = handle
                    os.queueEvent("menu_audio_update")
                end
            end,
            function()
                local _, url = os.pullEvent("http_failure")
                if url == menuMusic.downloadUrl then
                    menuMusic.handle = nil
                    http.request({ url = menuMusic.downloadUrl, binary = true })
                end
            end
        )
    end
end
local selectedMenuIdx = 1
local function scrollMenu(cfg)
    local w, h = term.getSize()
    local HEADER_H = 4
    local FOOTER_H = 2
    local visH = h - HEADER_H - FOOTER_H
    local function itemHeight(item)
        return (item.sub and item.sub ~= "") and 2 or 1
    end
    local sel      = cfg.startIdx or 1
    local scrollTop = 1
    local items    = cfg.items or {}
    if #items == 0 then return nil end
    sel = math.max(1, math.min(sel, #items))
    local function clampScroll()
        local y = 0
        for i = 1, #items do
            if i == scrollTop then y = 0 end
            if i == sel then break end
            if i >= scrollTop then y = y + itemHeight(items[i]) end
        end
        while true do
            local ty = 0
            for i = scrollTop, #items do
                if i == sel then break end
                ty = ty + itemHeight(items[i])
            end
            if ty >= visH then scrollTop = scrollTop + 1 else break end
        end
        while sel < scrollTop do scrollTop = scrollTop - 1 end
    end
    while true do
        clampScroll()
        w, h = term.getSize()
        visH = h - HEADER_H - FOOTER_H
        term.setBackgroundColor(colors.black)
        term.clear()
        local title = cfg.title or ""
        term.setCursorPos(math.max(1, math.floor((w - #title) / 2)), 1)
        term.setTextColor(colors.red)
        term.write(title)
        if cfg.subtitle and cfg.subtitle ~= "" then
            local sub = cfg.subtitle
            term.setCursorPos(math.max(1, math.floor((w - #sub) / 2)), 2)
            term.setTextColor(colors.yellow)
            term.write(sub)
        end
        term.setCursorPos(1, 3)
        term.setTextColor(colors.gray)
        term.write(string.rep("=", w))
        local curY = HEADER_H + 1
        for i = scrollTop, #items do
            if curY > h - FOOTER_H then break end
            local item = items[i]
            local label = item.label or tostring(i)
            local isSel = (i == sel)
            local prefix = isSel and "> " or "  "
            local maxLen = w - 4
            if #label > maxLen then label = label:sub(1, maxLen - 1) .. "~" end
            term.setCursorPos(2, curY)
            if isSel then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(item.color or colors.yellow)
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(item.color or colors.white)
            end
            term.clearLine()
            term.write(prefix .. label)
            term.setBackgroundColor(colors.black)
            curY = curY + 1
            if item.sub and item.sub ~= "" and curY <= h - FOOTER_H then
                local subStr = item.sub
                if #subStr > w - 4 then subStr = subStr:sub(1, w - 5) .. "~" end
                term.setCursorPos(4, curY)
                term.setTextColor(colors.lightGray)
                term.write(subStr)
                curY = curY + 1
            end
        end
        if scrollTop > 1 then
            term.setCursorPos(w, HEADER_H + 1)
            term.setTextColor(colors.gray)
            term.write("^")
        end
        local lastVisible = scrollTop
        local usedY = 0
        for i = scrollTop, #items do
            usedY = usedY + itemHeight(items[i])
            if usedY >= visH then lastVisible = i; break end
            lastVisible = i
        end
        if lastVisible < #items then
            term.setCursorPos(w, h - FOOTER_H)
            term.setTextColor(colors.gray)
            term.write("v")
        end
        if cfg.onDraw then cfg.onDraw(cfg, scrollTop, visH, w, h) end
        term.setCursorPos(1, h - 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.clearLine()
        local hint = cfg.footer or ("UP/DN - Navigate  ENTER - Select" .. (cfg.allowBack and "  ` - Back" or ""))
        term.write(hint:sub(1, w))
        term.setCursorPos(1, h)
        term.clearLine()
        local event, p1, p2 = os.pullEvent()
        if event == "key" then
            if p1 == keys.up then
                sel = math.max(1, sel - 1)
            elseif p1 == keys.down then
                sel = math.min(#items, sel + 1)
            elseif p1 == keys.enter then
                return sel
            elseif p1 == keys.grave and cfg.allowBack then
                return nil
            end
        elseif event == "websocket_message" and cfg.onWS then
            cfg.onWS(p1, p2)
        end
    end
end
local function drawGameOver()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2 - 5), 2)
    term.setTextColor(colors.red)
    term.write("GAME OVER")
    term.setCursorPos(math.floor(w/2 - 10), 4)
    term.setTextColor(colors.yellow)
    term.write("YOUR STATS:")
    term.setCursorPos(math.floor(w/2 - 10), 6)
    term.setTextColor(colors.white)
    term.write("Player: " .. (player.username or "Unknown"))
    term.setCursorPos(math.floor(w/2 - 10), 7)
    term.write("Map: " .. (gameStateVars.currentMap or "Unknown"))
    term.setCursorPos(math.floor(w/2 - 10), 8)
    term.write("Round: " .. (roundState.currentRound or 1))
    term.setCursorPos(math.floor(w/2 - 10), 9)
    term.write("Kills: " .. (player.kills or 0))
    term.setCursorPos(math.floor(w/2 - 10), 10)
    term.write("Points: " .. (player.points or 0))
    term.setCursorPos(math.floor(w/2 - 10), 11)
    term.setTextColor(colors.gray)
    local accuracy = player.stats.shotsFired > 0 and
        math.floor((player.stats.shotsHit / player.stats.shotsFired) * 100) or 0
    term.write(string.format("Accuracy: %d%% (%d/%d)", accuracy, player.stats.shotsHit, player.stats.shotsFired))
    if leaderboardData then
        term.setCursorPos(math.floor(w/2 - 10), 13)
        term.setTextColor(colors.yellow)
        term.write("TOP GLOBAL SCORES:")
        local yPos = 14
        if leaderboardData.global and #leaderboardData.global > 0 then
            for i = 1, math.min(5, #leaderboardData.global) do
                local entry = leaderboardData.global[i]
                term.setCursorPos(2, yPos)
                term.setTextColor(colors.white)
                term.write(string.format("%d. %s - Round %d (%d kills)",
                    i,
                    entry.playerName or "Unknown",
                    entry.round or 0,
                    entry.kills or 0
                ))
                yPos = yPos + 1
            end
        else
            term.setCursorPos(2, yPos)
            term.setTextColor(colors.gray)
            term.write("Loading leaderboards...")
        end
    end
    term.setCursorPos(math.floor(w/2 - 15), h - 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("ENTER - Return to Menu")
end
local function drawLeaderboard()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2 - 10), 2)
    term.setTextColor(colors.red)
    term.write("GLOBAL LEADERBOARD")
    term.setCursorPos(math.floor(w/2 - 8), 3)
    term.setTextColor(colors.gray)
    term.write("===================")
    if leaderboardData and leaderboardData.global and #leaderboardData.global > 0 then
        term.setCursorPos(2, 5)
        term.setTextColor(colors.yellow)
        term.write("Rank  Player                  Map            Round  Kills")
        term.setCursorPos(2, 6)
        term.setTextColor(colors.gray)
        term.write("----  --------------------  -------------  -----  -----")
        local yPos = 7
        for i = 1, math.min(10, #leaderboardData.global) do
            local entry = leaderboardData.global[i]
            term.setCursorPos(2, yPos)
            if i == 1 then
                term.setTextColor(colors.yellow)
            elseif i == 2 then
                term.setTextColor(colors.lightGray)
            elseif i == 3 then
                term.setTextColor(colors.orange)
            else
                term.setTextColor(colors.white)
            end
            local playerName = entry.playerName or "Unknown"
            local mapName = entry.mapName or "Unknown"
            local round = entry.round or 0
            local kills = entry.kills or 0
            if #playerName > 20 then playerName = playerName:sub(1, 17) .. "..." end
            if #mapName > 13 then mapName = mapName:sub(1, 10) .. "..." end
            term.write(string.format("%-4d  %-20s  %-13s  %-5d  %-5d",
                i, playerName, mapName, round, kills))
            yPos = yPos + 1
        end
    else
        term.setCursorPos(math.floor(w/2 - 12), math.floor(h/2))
        term.setTextColor(colors.gray)
        term.write("Loading leaderboards...")
        if not multiplayerState.wsConnected then
            term.setCursorPos(math.floor(w/2 - 15), math.floor(h/2) + 2)
            term.setTextColor(colors.red)
            term.write("Not connected to server!")
        end
    end
    term.setCursorPos(math.floor(w/2 - 15), h - 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.write("` - Return to Menu")
end
local function drawLobbyHost()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2 - 7), 3)
    term.setTextColor(colors.yellow)
    term.write("HOSTING LOBBY")
    term.setCursorPos(math.floor(w/2 - 10), 5)
    term.setTextColor(colors.white)
    term.write("Lobby: " .. lobby.name)
    term.setCursorPos(math.floor(w/2 - 10), 6)
    term.write("Map: " .. (availableMaps[lobby.mapIndex] and availableMaps[lobby.mapIndex].name or "Unknown"))
    term.setCursorPos(math.floor(w/2 - 10), 8)
    term.setTextColor(colors.lime)
    term.write("Players (" .. #lobby.players .. "/" .. lobby.maxPlayers .. "):")
    local yPos = 10
    for i, p in ipairs(lobby.players) do
        term.setCursorPos(math.floor(w/2 - 10), yPos)
        term.setTextColor(playerColors[i] or colors.white)
        term.write("| ")
        term.setTextColor(colors.white)
        term.write(p.name)
        yPos = yPos + 1
    end
    term.setCursorPos(math.floor(w/2 - 15), h - 3)
    term.setTextColor(colors.lightGray)
    term.write("Waiting for players...")
    term.setCursorPos(math.floor(w/2 - 15), h - 2)
    term.write("ENTER - Start Game | ` - Cancel")
end
local function showInteractPopup(text, color)
    local w, h = term.getSize()
    local len = #text
    local x = math.max(1, math.floor(w/2 - len/2))
    local y = math.floor(h/2 + 3)
    term.setBackgroundColor(colors.black)
    term.setTextColor(color or colors.white)
    term.setCursorPos(x, y)
    term.clearLine()
    term.write(text)
end
local function drawPlayerStatus()
    local w, h = term.getSize()
    local startY = h - 4
    local yOffset = 0
    local y = startY - (yOffset * 3)
    local playerName = player.username or "You"
    if #playerName > 15 then
        playerName = playerName:sub(1, 12) .. "..."
    end
    term.setCursorPos(1, y)
    term.setBackgroundColor(colors.black)
    if player.isDowned then
        term.setTextColor(colors.red)
        term.write(playerName .. ": DOWNED!")
    else
        term.setTextColor(colors.yellow)
        term.write(playerName .. ":")
    end
    term.setCursorPos(1, y + 1)
    local health = player.health or 0
    local maxHealth = player.maxHealth or 100
    local healthPercent = math.max(0, math.min(1, health / maxHealth))
    local greenWidth = math.floor(healthPercent * 20)
    local redWidth = 20 - greenWidth
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.lime)
    term.write(string.rep(" ", greenWidth))
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.red)
    term.write(string.rep(" ", redWidth))
    term.setCursorPos(1, y + 2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write(string.format("Points: %d | Kills: %d", player.points or 0, player.kills or 0))
    yOffset = yOffset + 1
    if multiplayerState.isMultiplayer then
        for playerID, otherPlayer in pairs(players) do
            if yOffset >= 3 then break end
            y = startY - (yOffset * 3)
            playerName = otherPlayer.name or ("Player" .. playerID)
            if #playerName > 15 then
                playerName = playerName:sub(1, 12) .. "..."
            end
            term.setCursorPos(1, y)
            term.setBackgroundColor(colors.black)
            if otherPlayer.isDowned then
                term.setTextColor(colors.red)
                term.write(playerName .. ": DOWNED!")
            else
                term.setTextColor(colors.white)
                term.write(playerName .. ":")
            end
            term.setCursorPos(1, y + 1)
            health = otherPlayer.health or 0
            maxHealth = otherPlayer.maxHealth or 100
            healthPercent = math.max(0, math.min(1, health / maxHealth))
            greenWidth = math.floor(healthPercent * 20)
            redWidth = 20 - greenWidth
            term.setBackgroundColor(colors.lime)
            term.setTextColor(colors.lime)
            term.write(string.rep(" ", greenWidth))
            term.setBackgroundColor(colors.red)
            term.setTextColor(colors.red)
            term.write(string.rep(" ", redWidth))
            term.setCursorPos(1, y + 2)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.yellow)
            term.write(string.format("Points: %d", otherPlayer.points or 0))
            yOffset = yOffset + 1
        end
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end
local function drawPerkIcons()
    local w, h = term.getSize()
    local baseX, baseY = 1, h - 1
    local idx = 0
    for _, perkId in ipairs(player.perks) do
        local c = perkColors[perkId] or colors.gray
        local x = baseX + (idx * 2)
        term.setBackgroundColor(c)
        term.setCursorPos(x, baseY)
        term.write("  ")
        idx = idx + 1
        if idx >= 8 then break end
    end
    term.setBackgroundColor(colors.black)
end
local function drawRoundTransition(w, h)
    if not roundTransition.phase then return end
    local elapsed = getCurrentTime() - roundTransition.startTime
    local cy      = math.floor(h / 2) - 2
    term.setBackgroundColor(colors.black)
    if roundTransition.phase == "clear" then
        local halfway = elapsed >= roundTransition.clearDur * 0.5
        local line1   = "- ROUND " .. roundTransition.round .. " COMPLETE -"
        local line2   = "Round Bonus: +" .. (roundTransition.round * 200) .. " pts"
        term.setCursorPos(math.floor(w/2 - #line1/2), cy)
        term.setTextColor(halfway and colors.white or colors.lightGray)
        term.write(line1)
        term.setCursorPos(math.floor(w/2 - #line2/2), cy + 1)
        term.setTextColor(colors.yellow)
        term.write(line2)
    elseif roundTransition.phase == "incoming" then
        local halfway = elapsed >= roundTransition.incomeDur * 0.4
        local line1   = "ROUND " .. roundTransition.round
        local line2   = "- INCOMING -"
        term.setCursorPos(math.floor(w/2 - #line1/2), cy)
        term.setTextColor(colors.red)
        term.write(line1)
        term.setCursorPos(math.floor(w/2 - #line2/2), cy + 1)
        term.setTextColor(halfway and colors.white or colors.lightGray)
        term.write(line2)
    end
end
local function drawBoxRoll(w, h)
    if not boxRoll.active and not boxRoll.done then return end
    local cy   = math.floor(h / 2)
    local line = boxRoll.done
        and (">>> " .. boxRoll.display .. " <<<")
        or  ("[ "   .. boxRoll.display .. " ]")
    local col  = boxRoll.done and colors.yellow or colors.white
    if boxRoll.done and math.floor(boxRoll.doneTimer * 4) % 2 == 0 then
        col = colors.lime
    end
    term.setCursorPos(math.floor(w/2 - #line/2), cy)
    term.setBackgroundColor(colors.black)
    term.setTextColor(col)
    term.write(line)
    if not boxRoll.done then
        local barW   = 20
        local filled = math.floor((boxRoll.elapsed / boxRoll.duration) * barW)
        local barX   = math.floor(w/2 - barW/2)
        term.setCursorPos(barX, cy + 1)
        term.setBackgroundColor(colors.gray)
        term.write(string.rep(" ", barW))
        if filled > 0 then
            term.setCursorPos(barX, cy + 1)
            term.setBackgroundColor(colors.yellow)
            term.write(string.rep(" ", math.min(filled, barW)))
        end
        term.setBackgroundColor(colors.black)
    end
end
local function drawHUD()
    local w, h = term.getSize()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.yellow)
    term.clearLine()
    term.write(string.format("Round: %d", roundState.currentRound))
    term.setTextColor(colors.white)
    term.write(string.format(" | Zombies: %d/%d", #zombies, roundState.zombiesThisRound))
    if hasPowerSwitch then
        term.write(" | Power: ")
        term.setTextColor(powerOn and colors.lime or colors.red)
        term.write(powerOn and "ON" or "OFF")
        term.setTextColor(colors.white)
    end
    if multiplayerState.isMultiplayer then
        local playerCount = 0
        for _ in pairs(players) do playerCount = playerCount + 1 end
        term.write(" | Players: " .. (playerCount + 1))
    end
    local active = getActiveWeapon()
    local weaponName = active and active.name or "Unarmed"
    local ammoText = active and string.format("%d/%d", active.ammo, active.reserve) or "-"
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    if active and active.isReloading then
        local remaining = math.max(0, active.reloadEndTime - getCurrentTime())
        term.write(string.format("Weapon (Slot %d/%d): %s | Ammo: %s (Reloading %.1fs)", player.activeWeaponSlot, player.maxWeaponSlots, weaponName, ammoText, remaining))
    else
        term.write(string.format("Weapon (Slot %d/%d): %s | Ammo: %s", player.activeWeaponSlot, player.maxWeaponSlots, weaponName, ammoText))
    end
    local nearPower = entity.getNearestPowerSwitch()
    local nearDoor = entity.getNearestDoor()
    local nearPerk = entity.getNearestPerkMachine()
    local nearBox = entity.getNearestMysteryBox()
    local nearPaP = entity.getNearestPaP()
    local nearScriptBlock = nil
    local mapData = CCZLoader.currentMap
    if mapData and mapData.scriptBlocks then
        for blockId, blockDef in pairs(mapData.scriptBlocks) do
            if not blockDef.collected and blockDef.instances then
                for _, inst in ipairs(blockDef.instances) do
                    local dx = player.x - inst.x
                    local dz = player.z - inst.z
                    if math.sqrt(dx*dx + dz*dz) < 2 then
                        nearScriptBlock = blockDef.label or blockId
                        break
                    end
                end
            end
            if nearScriptBlock then break end
        end
    end
    if nearPower then
        showInteractPopup("[E] Activate Power", colors.yellow)
    elseif nearDoor then
        if purchaseHold.active then
            local pct = math.floor(purchaseHold.elapsed / 2.0 * 100)
            showInteractPopup(string.format("[HOLD E] %s... %d%%", purchaseHold.label, pct), colors.yellow)
        else
            local actionText = string.format("[HOLD E] Open Door - %d Points", nearDoor.cost)
            local color = (player.points >= nearDoor.cost) and colors.lime or colors.red
            showInteractPopup(actionText, color)
        end
    elseif nearPaP then
        if purchaseHold.active then
            local pct = math.floor(purchaseHold.elapsed / 2.0 * 100)
            showInteractPopup(string.format("[HOLD E] %s... %d%%", purchaseHold.label, pct), colors.purple)
        else
            local w = getActiveWeapon()
            if hasPowerSwitch and not powerOn then
                showInteractPopup("Power must be ON", colors.red)
            elseif w and not w.isPaP and WEAPONS[w.id] and WEAPONS[w.id].papName then
                local color = (player.points >= 5000) and colors.purple or colors.red
                showInteractPopup("[HOLD E] Pack-a-Punch - 5000 Points", color)
            elseif w and w.isPaP then
                showInteractPopup("Already Upgraded", colors.gray)
            else
                showInteractPopup("Cannot Upgrade", colors.gray)
            end
        end
    elseif nearPerk then
        if purchaseHold.active then
            local pct = math.floor(purchaseHold.elapsed / 2.0 * 100)
            showInteractPopup(string.format("[HOLD E] %s... %d%%", purchaseHold.label, pct), colors.lime)
        else
            local cost = PERK_COSTS[nearPerk.type]
            if type(cost) == "function" then cost = cost() end
            local derivedName = nil
            if type(nearPerk.type) == "string" then
                derivedName = nearPerk.type:gsub("perk_", ""):gsub("_"," ")
                derivedName = derivedName:gsub("^%l", string.upper)
                if derivedName == "" then derivedName = nil end
            end
            local displayName = derivedName or "Perk"
            if cost then
                local color = (player.points >= cost and not nearPerk.purchased) and colors.lime or colors.red
                showInteractPopup(string.format("[HOLD E] Buy %s - %d Points", displayName, cost), color)
            else
                showInteractPopup(string.format("[HOLD E] Buy %s", displayName), colors.white)
            end
        end
    elseif nearBox then
        if purchaseHold.active then
            local pct = math.floor(purchaseHold.elapsed / 2.0 * 100)
            showInteractPopup(string.format("[HOLD E] %s... %d%%", purchaseHold.label, pct), colors.yellow)
        else
            showInteractPopup("[HOLD E] Mystery Box - 950 Points", colors.lime)
        end
    elseif nearScriptBlock then
        local label = nearScriptBlock:gsub("_", " "):gsub("(%a)([%w]*)", function(a,b) return a:upper()..b end)
        showInteractPopup("[E] " .. label, colors.orange)
    else
        local cx, cy = math.floor(w/2), math.floor(h/2)
        term.setCursorPos(cx, cy)
        term.setBackgroundColor(colors.black)
        if muzzleTimer and muzzleTimer > 0 then
            term.setTextColor(colors.yellow)
        else
            term.setTextColor(colors.lime)
        end
        term.write("+")
    end
    local markerY = math.floor(h/2) - 1
    for i = #hitMarkers, 1, -1 do
        local m = hitMarkers[i]
        if m and getCurrentTime() < m.expiry then
            term.setCursorPos(math.floor(w/2 - (#m.text/2)), markerY)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lime)
            term.write(m.text)
            markerY = markerY - 1
        end
    end
    drawPerkIcons()
    drawRoundTransition(w, h)
    drawBoxRoll(w, h)
    local now = getCurrentTime()
    for i = #announceQueue, 1, -1 do
        if now >= announceQueue[i].expiry then
            table.remove(announceQueue, i)
        end
    end
    if stamina < 1.0 or isSprinting then
        local barW   = math.floor(w * 0.3)
        local barX   = math.floor(w / 2 - barW / 2)
        local barY   = h - 6
        local filled = math.floor(stamina * barW)
        term.setCursorPos(barX, barY)
        term.setBackgroundColor(colors.gray)
        term.write(string.rep(" ", barW))
        if filled > 0 then
            term.setCursorPos(barX, barY)
            term.setBackgroundColor(isSprinting and colors.lime or colors.yellow)
            term.write(string.rep(" ", filled))
        end
        term.setCursorPos(barX, barY - 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.write("STAMINA")
    end
    local announceY = math.floor(h/2) - math.min(#announceQueue, 6)
    for i = 1, #announceQueue do
        local txt = announceQueue[i].text
        if #txt > w - 2 then txt = txt:sub(1, w - 2) end
        local x = math.max(1, math.floor((w - #txt) / 2))
        term.setCursorPos(x, announceY)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.write(txt)
        announceY = announceY + 1
        if announceY >= h - 4 then break end
    end
    drawPlayerStatus()
    if player.inAfterlife then
        term.setCursorPos(math.floor(w/2 - 15), 5)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write(string.format(" AFTERLIFE - REVIVE TIME: %.1fs ", player.afterlifeTimeLeft))
        if getNearestWhosWhoBody() then
            term.setCursorPos(math.floor(w/2 - 10), 6)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lime)
            if reviveHold.active then
                term.write(string.format(" [HOLD E] Reviving... %d%% ", math.floor(reviveHold.elapsed/1.5*100)))
            else
                term.write(" [E] Return to body ")
            end
        end
    end
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.clearLine()
    term.write("WASD Move | Arrows/Q/E Look | F Knife | 1/2/3 Switch | R Reload | ` Pause")
end
function handleMovement(dt)
    local wantSprint = (keysDown[keys.leftShift] or keysDown[keys.rightShift])
                       and not player.isDowned and not player.inAfterlife
    if wantSprint and stamina > 0 then
        isSprinting = true
        stamina = math.max(0, stamina - dt * 0.2)
    else
        isSprinting = false
        stamina = math.min(1.0, stamina + dt * (stamina > 0 and 0.15 or 0.08))
    end
    local sprintMult  = (isSprinting and stamina > 0) and 1.6 or 1.0
    local perkSpeed   = hasPerk("perk_staminup") and 1.2 or 1.0
    local moveSpeed   = 4 * perkSpeed * sprintMult
    local turnSpeed = 120
    local jumpStrength = 6
    local gravity = -20
    if keysDown[keys.left] or keysDown[keys.q] then
        targetRotY = targetRotY - turnSpeed * dt
    end
    if keysDown[keys.right] or (keysDown[keys.e] and not purchaseHold.active and not reviveHold.active) then
        targetRotY = targetRotY + turnSpeed * dt
    end
    if keysDown[keys.down] then
        targetRotZ = math.max(-80, targetRotZ - turnSpeed * dt)
    end
    if keysDown[keys.up] then
        targetRotZ = math.min(80, targetRotZ + turnSpeed * dt)
    end
    camera.rotY = camera.rotY + (targetRotY - camera.rotY) * 10 * dt
    camera.rotZ = camera.rotZ + ((targetRotZ + (player.recoil or 0)) - camera.rotZ) * 10 * dt
    if player.recoil and player.recoil ~= 0 then
        local recoveryRate = 6
        if math.abs(player.recoil) < 0.01 then
            player.recoil = 0
        else
            player.recoil = player.recoil - player.recoil * math.min(1, recoveryRate * dt)
        end
    end
    player.rotY = camera.rotY
    player.rotZ = camera.rotZ
    local moveX, moveZ = 0, 0
    local speedMult = player.isDowned and 0.5 or 1.0
    if keysDown[keys.w] then
        moveX = moveX + math.cos(math.rad(player.rotY))
        moveZ = moveZ + math.sin(math.rad(player.rotY))
    end
    if keysDown[keys.s] then
        moveX = moveX - math.cos(math.rad(player.rotY))
        moveZ = moveZ - math.sin(math.rad(player.rotY))
    end
    if keysDown[keys.a] then
        moveX = moveX + math.cos(math.rad(player.rotY - 90))
        moveZ = moveZ + math.sin(math.rad(player.rotY - 90))
    end
    if keysDown[keys.d] then
        moveX = moveX + math.cos(math.rad(player.rotY + 90))
        moveZ = moveZ + math.sin(math.rad(player.rotY + 90))
    end
    local moveLength = math.sqrt(moveX*moveX + moveZ*moveZ)
    if moveLength > 0 then
        moveX = (moveX / moveLength) * moveSpeed * speedMult * dt
        moveZ = (moveZ / moveLength) * moveSpeed * speedMult * dt
    end
    local newX = player.x + moveX
    if not world.checkPlayerCollision(newX, player.y, player.z) then
        player.x = newX
    end
    local newZ = player.z + moveZ
    if not world.checkPlayerCollision(player.x, player.y, newZ) then
        player.z = newZ
    end
    if keysJustPressed[keys.space] and player.onGround and not player.isDowned then
        player.velocityY = jumpStrength
        player.onGround = false
    end
    player.velocityY = player.velocityY + gravity * dt
    local newY = player.y + player.velocityY * dt
    local groundCheck = world.isBlockSolid(player.x, newY - 0.1, player.z)
    if groundCheck and player.velocityY <= 0 then
        player.y = math.floor(newY) + 1
        player.velocityY = 0
        player.onGround = true
    else
        if world.checkCollision(player.x, newY + player.height - 0.1, player.z) and player.velocityY > 0 then
            player.velocityY = 0
        end
        if not world.checkPlayerCollision(player.x, newY, player.z) then
            player.y = newY
            player.onGround = groundCheck
        else
            if player.velocityY < 0 then
                player.y = math.floor(player.y) + 1
                player.velocityY = 0
                player.onGround = true
            end
        end
    end
    local currentTime = os.epoch("utc") / 1000
    if currentTime - player.lastHitTime >= 4 then
        if player.health < player.maxHealth then
            player.health = math.min(player.maxHealth, player.health + 25 * dt)
        end
    end
    camera.x = player.x
    camera.y = player.y + player.eyeHeight
    camera.z = player.z
    for k in pairs(keysJustPressed) do keysJustPressed[k] = nil end
    frame:setCamera(camera)
    if multiplayerState.isMultiplayer then
        sendPlayerUpdate()
    end
end
function gameLoop()
    local lastTime = os.epoch("utc") / 1000
    local updateTimer = os.startTimer(0.05)
    local syncTimer = os.startTimer(0.1)
    if multiplayerState.isMultiplayer and not isHost then
        if multiplayerState.ws and multiplayerState.wsConnected then
            multiplayerState.ws.send(textutils.serializeJSON({
                type = "player_ready",
                lobbyID = lobbyID
            }))
        end
    end
    while gameStateVars.current == "playing" do
        local event, p1, p2, p3 = os.pullEventRaw()
        if event == "timer" and p1 == updateTimer then
            if multiplayerState.isMultiplayer then
                local drainTimer = os.startTimer(0)
                while true do
                    local de, da, db = os.pullEventRaw()
                    if de == "timer" and da == drainTimer then
                        break
                    elseif de == "websocket_message" and da == WS_URL then
                        local dm = textutils.unserializeJSON(db)
                        if dm then handleServerMessage(dm) end
                    elseif de == "key" then
                        keysDown[da] = true
                        keysJustPressed[da] = true
                    elseif de == "key_up" then
                        keysDown[da] = nil
                    elseif de == "mouse_click" and da == 1 then
                        player.firing = true
                        player.firedOnThisClick = false
                    elseif de == "mouse_up" and da == 1 then
                        player.firing = false
                    elseif de == "websocket_closed" and da == WS_URL then
                        multiplayerState.wsConnected = false
                        gameStateVars.current = "main_menu"
                    end
                end
            end
            local currentTime = os.epoch("utc") / 1000
            local dt = math.min(currentTime - lastTime, 0.05)
            lastTime = currentTime
            handleMovement(dt)
            if muzzleTimer and muzzleTimer > 0 then muzzleTimer = math.max(0, muzzleTimer - dt) end
            for i = #hitMarkers, 1, -1 do
                if getCurrentTime() >= hitMarkers[i].expiry then
                    table.remove(hitMarkers, i)
                end
            end
            weapon.updateFiring(dt)
            if boxRoll.active then
                boxRoll.elapsed   = boxRoll.elapsed + dt
                boxRoll.spinTimer = boxRoll.spinTimer + dt
                local progress  = boxRoll.elapsed / boxRoll.duration
                local spinRate  = 0.18 - (math.sin(progress * math.pi) * 0.14)
                if boxRoll.spinTimer >= spinRate then
                    boxRoll.spinTimer = 0
                    local idx = math.random(1, #_boxWeightedPool)
                    boxRoll.display = _boxWeightedPool[idx].name
                end
                if boxRoll.elapsed >= boxRoll.duration then
                    boxRoll.active  = false
                    boxRoll.done    = true
                    boxRoll.doneTimer = 0
                    boxRoll.display = boxRoll.chosen.name
                    giveWeaponToPlayer(boxRoll.chosen.id)
                    ccz.game.announce("Mystery Box: " .. boxRoll.chosen.name .. "!", 2.5)
                end
            end
            if boxRoll.done then
                boxRoll.doneTimer = boxRoll.doneTimer + dt
                if boxRoll.doneTimer >= boxRoll.doneDur then
                    boxRoll.done    = false
                    boxRoll.display = ""
                end
            end
            if roundTransition.phase then
                local elapsed = os.epoch("utc") / 1000 - roundTransition.startTime
                if roundTransition.phase == "clear" then
                    if elapsed >= roundTransition.clearDur then
                        roundTransition.phase     = "incoming"
                        roundTransition.startTime = os.epoch("utc") / 1000
                    end
                elseif roundTransition.phase == "incoming" then
                    if elapsed >= roundTransition.incomeDur then
                        roundTransition.phase = nil
                    end
                end
            end
            updateSpecialAudio(dt)
            updateEESong()
            updateJingle(dt)
            checkPerkProximity(dt)
            if player.inAfterlife then
                local currentTime = os.epoch("utc") / 1000
                local elapsed = currentTime - player.afterlifeStartTime
                player.afterlifeTimeLeft = math.max(0, 30 - elapsed)
                if player.afterlifeTimeLeft <= 0 then
                    gameStateVars.current = "gameover"
                    submitScore()
                    fetchLeaderboards(gameStateVars.currentMap)
                end
            end
            if reviveHold.active then
                local holdTime = (reviveHold.isWhosWho or player.quickRevive) and 1.5 or 3.0
                reviveHold.elapsed = reviveHold.elapsed + dt
                if reviveHold.elapsed >= holdTime then
                    reviveHold.active = false
                    if reviveHold.isWhosWho then
                        completeWhosWhoRevive()
                    elseif reviveHold.target then
                        entity.revivePlayer(reviveHold.target)
                        if multiplayerState.isMultiplayer and multiplayerState.ws and multiplayerState.wsConnected then
                            multiplayerState.ws.send(textutils.serializeJSON({
                                type = "player_revived", targetID = reviveHold.targetID
                            }))
                        end
                    end
                    reviveHold.target = nil; reviveHold.targetID = nil
                end
            end
            if purchaseHold.active then
                purchaseHold.elapsed = purchaseHold.elapsed + dt
                if purchaseHold.elapsed >= 2.0 then
                    purchaseHold.active = false
                    if purchaseHold.action then
                        purchaseHold.action()
                        purchaseHold.action = nil
                        purchaseHold.label  = ""
                    end
                end
            end
            if player.isDowned then
                local currentTime = os.epoch("utc") / 1000
                local elapsed = currentTime - player.downedTime
                if elapsed >= player.bleedoutTime then
                    if not multiplayerState.isMultiplayer then
                        gameStateVars.current = "gameover"
                        submitScore()
                        fetchLeaderboards(gameStateVars.currentMap)
                    else
                        local anyoneAlive = false
                        for _, p in pairs(players) do
                            if not p.isDowned then
                                anyoneAlive = true
                                break
                            end
                        end
                        if not anyoneAlive then
                            gameStateVars.current = "gameover"
                            submitScore()
                            fetchLeaderboards(gameStateVars.currentMap)
                        end
                    end
                end
            end
            if not multiplayerState.isMultiplayer or isHost then
            updateFlowField()
            zombie.updateZombies(dt)
                zombie.updateRound(dt)
            end
            renderedObjects = {}
            world.renderMap()
            renderPerkMachines()
            renderPaPMachines()
            renderPowerSwitches()
            renderMysteryBoxes()
            zombie.renderZombies(dt)
            renderPlayers()
            frame:drawObjects(renderedObjects)
            frame:drawBuffer()
            reapplyMapPalette()
            drawGunModel()
            if player.isDowned then
                local currentTime = os.epoch("utc") / 1000
                local elapsed = currentTime - player.downedTime
                local timeLeft = player.bleedoutTime - elapsed
                local progress = 1 - (timeLeft / player.bleedoutTime)
                if progress < 0.5 then
                    local redProgress = progress * 2
                    term.setPaletteColor(colors.white, 1 - redProgress * 0.5, 1 - redProgress, 1 - redProgress)
                    term.setPaletteColor(colors.orange, 1, 0.5 - redProgress * 0.5, 0)
                    term.setPaletteColor(colors.magenta, 1, 0 - redProgress * 0, 0.5 - redProgress * 0.5)
                    term.setPaletteColor(colors.lightBlue, 0.5 + redProgress * 0.5, 0.5 - redProgress * 0.5, 1 - redProgress)
                    term.setPaletteColor(colors.yellow, 1, 1 - redProgress * 0.5, 0)
                    term.setPaletteColor(colors.lime, 0.5 + redProgress * 0.5, 1 - redProgress * 0.3, 0)
                    term.setPaletteColor(colors.pink, 1, 0.75 - redProgress * 0.5, 0.75 - redProgress * 0.5)
                    term.setPaletteColor(colors.gray, 0.5, 0.5 - redProgress * 0.3, 0.5 - redProgress * 0.3)
                    term.setPaletteColor(colors.lightGray, 0.75, 0.75 - redProgress * 0.5, 0.75 - redProgress * 0.5)
                    term.setPaletteColor(colors.cyan, 0.5 + redProgress * 0.5, 1 - redProgress * 0.5, 1 - redProgress * 0.5)
                    term.setPaletteColor(colors.purple, 0.75 + redProgress * 0.25, 0 + redProgress * 0.3, 0.75 - redProgress * 0.5)
                    term.setPaletteColor(colors.blue, 0 + redProgress * 0.5, 0, 1 - redProgress * 0.5)
                    term.setPaletteColor(colors.brown, 0.75, 0.5 - redProgress * 0.3, 0.25 - redProgress * 0.25)
                    term.setPaletteColor(colors.green, 0 + redProgress * 0.5, 0.75 - redProgress * 0.5, 0)
                    term.setPaletteColor(colors.red, 1, 0, 0)
                else
                    local blackProgress = (progress - 0.5) * 2
                    local r = 1 - blackProgress
                    term.setPaletteColor(colors.white, r * 0.5, 0, 0)
                    term.setPaletteColor(colors.orange, r, 0, 0)
                    term.setPaletteColor(colors.magenta, r, 0, 0)
                    term.setPaletteColor(colors.lightBlue, r, 0, 0)
                    term.setPaletteColor(colors.yellow, r, 0, 0)
                    term.setPaletteColor(colors.lime, r, 0, 0)
                    term.setPaletteColor(colors.pink, r, 0, 0)
                    term.setPaletteColor(colors.gray, r * 0.5, 0, 0)
                    term.setPaletteColor(colors.lightGray, r * 0.75, 0, 0)
                    term.setPaletteColor(colors.cyan, r, 0, 0)
                    term.setPaletteColor(colors.purple, r, 0, 0)
                    term.setPaletteColor(colors.blue, r * 0.5, 0, 0)
                    term.setPaletteColor(colors.brown, r * 0.75, 0, 0)
                    term.setPaletteColor(colors.green, r * 0.5, 0, 0)
                    term.setPaletteColor(colors.red, r, 0, 0)
                    term.setPaletteColor(colors.black, 0, 0, 0)
                end
            else
                reapplyMapPalette()
            end
            drawHUD()
            updateTimer = os.startTimer(0.05)
        elseif event == "timer" and p1 == syncTimer then
            if isHost and multiplayerState.isMultiplayer then
                syncGameState()
            end
            syncTimer = os.startTimer(0.1)
        elseif event == "http_success" then
            if audioStreams.eeSong.playing and p1 == audioStreams.eeSong.url then
                audioStreams.eeSong.handle = p2
                audioStreams.eeSong.start = audioStreams.eeSong.handle.read(4)
                audioStreams.eeSong.size = 16 * 1024 - 4
            end
            if audioStreams.jingle.playing and p1 == audioStreams.jingle.url then
                audioStreams.jingle.handle = p2
                audioStreams.jingle.start = audioStreams.jingle.handle.read(4)
                audioStreams.jingle.size = 16 * 1024 - 4
            end
            if pendingSoundRequests[p1] then
                local req = pendingSoundRequests[p1]
                pendingSoundRequests[p1] = nil
                local handle = p2
                local decoder = dfpwm.make_decoder()
                handle.read(4)
                local chunk = handle.read(16 * 1024)
                while chunk do
                    local buf = decoder(chunk)
                    req.speaker.playAudio(buf, req.volume)
                    chunk = handle.read(16 * 1024)
                end
                handle.close()
            end
        elseif event == "http_failure" then
            if audioStreams.eeSong.playing and p1 == audioStreams.eeSong.url then
                stopEESong()
            end
            if audioStreams.jingle.playing and p1 == audioStreams.jingle.url then
                stopJingle()
            end
        elseif event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then
                handleServerMessage(msg)
            end
        elseif event == "websocket_closed" and p1 == WS_URL then
            multiplayerState.wsConnected = false
            if multiplayerState.isMultiplayer then
                gameStateVars.current = "main_menu"
                print("Disconnected from server")
            end
        elseif event == "key" then
            keysDown[p1] = true
            keysJustPressed[p1] = true
            if p1 == keys.grave then
                gameStateVars.current = "paused"
                pauseMenuOption = 1
            elseif p1 == keys.e then
                if onPlayerInteract() then
                elseif entity.getNearestPowerSwitch() then
                    entity.activatePowerSwitch(entity.getNearestPowerSwitch())
                elseif player.inAfterlife and getNearestWhosWhoBody() then
                    reviveHold.active = true; reviveHold.elapsed = 0
                    reviveHold.isWhosWho = true
                    reviveHold.target = nil; reviveHold.targetID = nil
                else
                    local downedPlayer, downedID = entity.getNearestDownedPlayer()
                    if downedPlayer and not player.isDowned and not player.inAfterlife then
                        reviveHold.active = true; reviveHold.elapsed = 0
                        reviveHold.isWhosWho = false
                        reviveHold.target = downedPlayer; reviveHold.targetID = downedID
                    else
                        local nearDoor = entity.getNearestDoor()
                        local nearPerk = entity.getNearestPerkMachine()
                        local nearBox  = entity.getNearestMysteryBox()
                        local nearPaP  = entity.getNearestPaP()
                        if nearDoor then
                            if not purchaseHold.active then
                                purchaseHold.active  = true
                                purchaseHold.elapsed = 0
                                purchaseHold.label   = "Open Door (-" .. nearDoor.cost .. " pts)"
                                purchaseHold.action  = function() entity.openDoor(nearDoor) end
                            end
                        elseif nearPaP then
                            if not purchaseHold.active then
                                purchaseHold.active  = true
                                purchaseHold.elapsed = 0
                                purchaseHold.label   = "Pack-a-Punch (-5000 pts)"
                                purchaseHold.action  = function() entity.packAPunchWeapon() end
                            end
                        elseif nearPerk and not nearPerk.purchased then
                            if not purchaseHold.active then
                                local cost = PERK_COSTS[nearPerk.type]
                                if type(cost) == "function" then cost = cost() end
                                local name = (nearPerk.type:gsub("perk_",""):gsub("_"," ")
                                             :gsub("^%l", string.upper))
                                purchaseHold.active  = true
                                purchaseHold.elapsed = 0
                                purchaseHold.label   = "Buy " .. name .. " (-" .. (cost or "?") .. " pts)"
                                purchaseHold.action  = function()
                                    entity.purchasePerkMachine(nearPerk)
                                end
                            end
                        elseif nearBox then
                            if not purchaseHold.active then
                                purchaseHold.active  = true
                                purchaseHold.elapsed = 0
                                purchaseHold.label   = "Mystery Box (-950 pts)"
                                purchaseHold.action  = function()
                                    if player.points >= 950 and not boxRoll.active and not boxRoll.done then
                                        player.points = player.points - 950
                                        local chosen = _boxWeightedPool[math.random(1, #_boxWeightedPool)]
                                        boxRoll.active    = true
                                        boxRoll.elapsed   = 0
                                        boxRoll.spinTimer = 0
                                        boxRoll.done      = false
                                        boxRoll.chosen    = chosen
                                        boxRoll.display   = "???"
                                    end
                                end
                            end
                        else
                            targetRotY = targetRotY + 8
                        end
                    end
                end
            elseif p1 == keys.f then
                weapon.performMelee()
            elseif p1 == keys.one then
                switchWeaponSlot(1)
            elseif p1 == keys.two then
                switchWeaponSlot(2)
            elseif p1 == keys.three then
                switchWeaponSlot(3)
            elseif p1 == keys.r then
                weapon.reloadWeapon()
            elseif p1 == keys.rightBracket then
                if audioStreams.eeSong.playing then
                    stopEESong()
                else
                    startEESong()
                end
            end
        elseif event == "key_up" then
            keysDown[p1] = nil
            if p1 == keys.e then
                reviveHold.active   = false; reviveHold.elapsed   = 0
                purchaseHold.active = false; purchaseHold.elapsed = 0
                purchaseHold.action = nil;   purchaseHold.label   = ""
            end
        elseif event == "mouse_click" then
            if p1 == 1 then
                player.firing = true
                player.firedOnThisClick = false
            end
        elseif event == "mouse_up" then
            if p1 == 1 then
                player.firing = false
                player.firedOnThisClick = false
            end
        elseif event == "terminate" then
            if multiplayerState.isMultiplayer then
                leaveLobby()
                if multiplayerState.ws then multiplayerState.ws.close() end
            end
            return "quit"
        end
    end
end
function initGame(mapIndex)
    mapIndex = math.max(1, math.min(mapIndex or 1, #availableMaps))
    local map = availableMaps[mapIndex]
    if not map then
        local neededName = lobby and lobby.mapName
        if neededName and multiplayerState.isMultiplayer then
            term.clear()
            term.setCursorPos(1, 1)
            term.setTextColor(colors.yellow)
            print("Downloading required map...")
            print("Map: " .. neededName)
            print("")
            term.setTextColor(colors.lightGray)
            print("Fetching manifest...")
            local r = http.get(dlcConfig.manifestUrl)
            if r then
                local c = r.readAll(); r.close()
                local manifest = textutils.unserializeJSON(c)
                if manifest and manifest.maps then
                    local target = nil
                    for _, m in ipairs(manifest.maps) do
                        if m.name:lower() == neededName:lower() or
                           m.file:lower():find(neededName:lower(), 1, true) then
                            target = m
                            break
                        end
                    end
                    if target then
                        term.setTextColor(colors.white)
                        print("Downloading: " .. target.name)
                        if dlcDownload(target) then
                            checkAvailableMaps()
                            for i, m in ipairs(availableMaps) do
                                if m.name:lower() == neededName:lower() then
                                    mapIndex = i
                                    map = m
                                    break
                                end
                            end
                        else
                            term.setTextColor(colors.red)
                            print("Download failed: " .. (dlcState.err or "unknown"))
                        end
                    else
                        term.setTextColor(colors.red)
                        print("Map not found in manifest: " .. neededName)
                    end
                end
            else
                term.setTextColor(colors.red)
                print("Could not reach download server.")
            end
            if not map then
                term.setTextColor(colors.red)
                print("")
                print("Could not load map. Returning to menu.")
                print("Try downloading '" .. neededName .. "' from the DLC menu.")
                sleep(3)
                gameStateVars.current = "main_menu"
                selectedMenuIdx = 1
                return
            end
        else
            term.clear()
            term.setCursorPos(1,1)
            print("No maps installed.")
            print("Use the Download Maps menu to get maps.")
            sleep(2)
            gameStateVars.current = "main_menu"
            selectedMenuIdx = 1
            return
        end
    end
    gameStateVars.mapData = map.data
    gameStateVars.currentMap = map.name
    local mapFileName = map.file and map.file:match("([^/]+)%.ccz$")
    if mapFileName then
        CCZLoader.loadMap(mapFileName)
    end
    stopMenuMusic()
    if isHost and multiplayerState.isMultiplayer then
        startGameMultiplayer()
    end
    world.showLoadingScreen(gameStateVars.currentMap)
    precomputeEntityModels()
    player.x, player.y, player.z = world.findPlayerSpawn()
    camera.x, camera.y, camera.z = player.x, player.y + player.eyeHeight, player.z
    player.health = 100
    player.maxHealth = 100
    player.points = 500
    player.kills = 0
    player.weapon = "pistol"
    player.ammo = 8
    player.perks = {}
    player.lastHitTime = 0
    player.velocityY = 0
    player.onGround = false
    player.reloadMultiplier = 1
    player.moveSpeedMultiplier = 1
    player.doubleTap = false
    player.quickRevive = false
    player.quickReviveUses = 0
    player.lastMeleeTime = 0
    player.whosWho = false
    player.phdFlopper = false
    player.electricCherry = false
    player.firing = false
    player.firedOnThisClick = false
    player.recoil = 0
    player.isDowned = false
    player.downedTime = 0
    player.reviveProgress = 0
    player.inAfterlife = false
    player.afterlifeBodyPos = nil
    player.afterlifePerks = {}
    player.afterlifeTimeLeft = 30
    player.stats = {
        shotsFired = 0, shotsHit = 0, headshots = 0,
        downs = 0, revives = 0, damageDealt = 0, damageTaken = 0
    }
    player.maxWeaponSlots = 2
    player.weapons = {}
    player.weapons[1] = weapon.createPlayerWeaponInstance("m1911")
    player.weapons[2] = nil
    player.activeWeaponSlot = 1
    player.ammo = player.weapons[1].ammo
    for k in pairs(zombies) do zombies[k] = nil end
    for k in pairs(hitMarkers) do hitMarkers[k] = nil end
    cachedModels = {}
    for k in pairs(keysDown) do keysDown[k] = nil end
    for k in pairs(keysJustPressed) do keysJustPressed[k] = nil end
    for k in pairs(announceQueue) do announceQueue[k] = nil end
    for k in pairs(pendingSoundRequests) do pendingSoundRequests[k] = nil end
    targetRotY  = 0
    targetRotZ  = 0
    stamina     = 1.0
    isSprinting = false
    reviveHold.active   = false; reviveHold.elapsed   = 0
    reviveHold.target   = nil;   reviveHold.targetID  = nil
    purchaseHold.active = false; purchaseHold.elapsed = 0
    purchaseHold.action = nil;   purchaseHold.label   = ""
    roundTransition.phase = nil
    boxRoll.active  = false; boxRoll.done  = false
    boxRoll.elapsed = 0;     boxRoll.display = ""
    boxRoll.chosen  = nil
    world.loadEntities()
    initializeSpecialModels()
    ccz.boss.setSpawnHook(function(boss) table.insert(zombies, boss) end)
    ccz.boss.setZombiesRef(zombies)
    world.buildSolidBlocksFromMeshes()
    openedDoorMeshKeys = {}
    _mapPalette = {}
    ccz.palette.reset()
    flowField    = {}
    flowOrigin   = {x=nil, z=nil}
    navWalkCache = {}
    _ffBuild     = nil
    if not multiplayerState.isMultiplayer then takenCharacters = {} end
    loadedGunModels = {}
    assignCharacter()
    if multiplayerState.isMultiplayer and multiplayerState.ws and multiplayerState.wsConnected then
        multiplayerState.ws.send(textutils.serializeJSON({
            type="character_assign", charId=playerCharacter.id, playerID=myPlayerID
        }))
    end
    local mapData = CCZLoader.currentMap
    if mapData and mapData.onLoad then
        local ok, err = pcall(mapData.onLoad, gameStateVars)
        if not ok then
            term.setTextColor(colors.red)
            print("onLoad error: " .. tostring(err))
            sleep(2)
        end
    end
    zombie.startRound(1)
    gameStateVars.current = "playing"
    return gameLoop()
end
function testStreamAudio(ytId, label)
    local speaker = peripheral.find("speaker")
    if not speaker then
        term.setBackgroundColor(colors.black); term.clear()
        term.setCursorPos(1,1); term.setTextColor(colors.red)
        print("No speaker peripheral found!")
        print("Attach a speaker and try again.")
        sleep(2)
        return false
    end
    stopMenuMusic()
    local speakerName = peripheral.getName(speaker)
    local apiBase = "https://" .. "ipod-2to6magyna-uc" .. ".a.run.app/"
    local url = apiBase .. "?v=2.1&id=" .. ytId
    term.setBackgroundColor(colors.black); term.clear()
    local w = term.getSize()
    term.setCursorPos(math.floor((w - #label) / 2), 2)
    term.setTextColor(colors.yellow); term.write(label)
    term.setCursorPos(1, 4); term.setTextColor(colors.lightGray)
    term.write("Connecting...")
    http.request({ url = url, binary = true })
    local handle = nil
    while not handle do
        local ev, p1, p2 = os.pullEvent()
        if ev == "http_success" and p1 == url then
            handle = p2
        elseif ev == "http_failure" and p1 == url then
            term.setCursorPos(1, 4); term.setTextColor(colors.red)
            term.write("Connection failed! Press any key...")
            os.pullEvent("key")
            startMenuMusic(nil)
            return false
        elseif ev == "key" then
            os.startTimer(5)
            while true do
                local ev2, p1b, p2b = os.pullEvent()
                if (ev2 == "http_success" or ev2 == "http_failure") and p1b == url then
                    if ev2 == "http_success" then p2b.close() end
                    break
                elseif ev2 == "timer" then break end
            end
            startMenuMusic(nil)
            return false
        end
    end
    term.setCursorPos(1, 4); term.setTextColor(colors.lime)
    term.write("Streaming: " .. label)
    term.setCursorPos(1, 5); term.setTextColor(colors.lightGray)
    term.write("Press any key to stop")
    local decoder = dfpwm.make_decoder()
    local startBytes = handle.read(4)
    local chunkSize  = 16 * 1024 - 4
    local stopped    = false
    local finished   = false
    while not stopped and not finished do
        local chunk = handle.read(chunkSize)
        if not chunk then
            finished = true
            break
        end
        if startBytes then
            chunk      = startBytes .. chunk
            startBytes = nil
            chunkSize  = chunkSize + 4
        end
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer, 1.0) do
            local interrupted = false
            parallel.waitForAny(
                function()
                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == speakerName
                end,
                function()
                    os.pullEvent("key")
                    interrupted = true
                end
            )
            if interrupted then stopped = true; break end
        end
        if not stopped then
            local interrupted = false
            parallel.waitForAny(
                function()
                    repeat until select(2, os.pullEvent("speaker_audio_empty")) == speakerName
                end,
                function()
                    os.pullEvent("key")
                    interrupted = true
                end
            )
            if interrupted then stopped = true end
        end
    end
    handle.close()
    speaker.stop()
    startMenuMusic(nil)
    return finished
end
function runTestMenu()
    local function clearPrompt(title)
        term.setBackgroundColor(colors.black)
        term.clear()
        local w = term.getSize()
        term.setCursorPos(math.floor((w-#title)/2), 1)
        term.setTextColor(colors.yellow)
        term.write(title)
        term.setCursorPos(1, 3)
        term.setTextColor(colors.white)
    end
    while true do
        local choice = scrollMenu({
            title    = "CC:Z TEST FEATURES",
            subtitle = "Developer / Debug Tools",
            allowBack = true,
            footer   = "UP/DN - Navigate  ENTER - Run Test  ` - Back",
            items = {
                {label = "Easter Egg Songs", sub = "Stream any map EE song (stops on key)"},
                {label = "Perk Jingles",     sub = "Test perk audio (stops on key)"},
                {label = "Map Files",        sub = "Scan & validate all maps in maps/"},
                {label = "Server Status",    sub = "Ping WebSocket, show lobby count"},
            }
        })
        if not choice then return end
        if choice == 1 then
            local songItems = {}
            local songIds   = {}
            for _, m in ipairs(availableMaps) do
                if m.data and m.data.eeSongId and m.data.eeSongId ~= "" then
                    local already = false
                    for _, si in ipairs(songItems) do
                        if si.label == m.name then already = true; break end
                    end
                    if not already then
                        table.insert(songItems, {label = m.name, sub = "YT: " .. m.data.eeSongId})
                        table.insert(songIds,   m.data.eeSongId)
                    end
                end
            end
            if #songItems == 0 then
                clearPrompt("EE SONGS")
                print("No EE songs found.")
                print("Add eeSongId field to your .ccz map file.")
                sleep(2)
            else
                local s = scrollMenu({
                    title    = "EE SONG TEST",
                    allowBack = true,
                    items    = songItems,
                    footer   = "ENTER - Stream  ` - Back"
                })
                if s then
                    testStreamAudio(songIds[s], "EE Song: " .. songItems[s].label)
                end
            end
        elseif choice == 2 then
            local perkNames = {}
            for perkId, _ in pairs(PERK_JINGLES) do
                table.insert(perkNames, perkId)
            end
            table.sort(perkNames)
            local jItems = {}
            for _, perkId in ipairs(perkNames) do
                jItems[#jItems+1] = {label = perkId, sub = "YT: " .. PERK_JINGLES[perkId]}
            end
            if #jItems == 0 then
                clearPrompt("PERK JINGLES")
                print("No perk jingles defined in PERK_JINGLES.")
                sleep(2)
            else
                local s = scrollMenu({
                    title    = "PERK JINGLE TEST",
                    subtitle = "Any key stops playback",
                    allowBack = true,
                    items    = jItems,
                    footer   = "ENTER - Play  ` - Back"
                })
                if s then
                    testStreamAudio(PERK_JINGLES[perkNames[s]], "Jingle: " .. perkNames[s])
                end
            end
        elseif choice == 3 then
            local mapItems = {}
            if fs.exists("maps") then
                for _, fname in ipairs(fs.list("maps")) do
                    if fname:match("%.json$") or fname:match("%.ccz$") then
                        local path = "maps/" .. fname
                        local kb   = math.floor((fs.getSize(path) or 0) / 1024)
                        local data, err = loadMapData(path)
                        local ok  = data ~= nil
                        local ext = fname:match("%.%w+$") or ""
                        local tag = ok and ("[OK] " .. ext:upper():sub(2)) or "[ERR]"
                        mapItems[#mapItems+1] = {
                            label = tag .. " " .. fname,
                            sub   = ok
                                    and (data.name or fname) .. "  " .. kb .. " KB  spawns:"
                                        .. (data.spawns and data.spawns.zombie and #data.spawns.zombie or "?")
                                    or  "Error: " .. tostring(err),
                            color = ok and colors.lime or colors.red
                        }
                    end
                end
            end
            if #mapItems == 0 then
                mapItems = {{label = "No map files found in maps/", color = colors.red}}
            end
            scrollMenu({title="MAP FILE STATUS", allowBack=true, items=mapItems,
                        footer="` - Back  (read-only)"})
        elseif choice == 4 then
            clearPrompt("SERVER STATUS")
            print("Server: " .. WS_URL)
            print("")
            local connected = multiplayerState.wsConnected
            if not connected then
                term.setTextColor(colors.yellow)
                print("Connecting...")
                connected = connectWebSocket()
            end
            if connected then
                term.setTextColor(colors.lime)
                print("WebSocket: CONNECTED")
                term.setTextColor(colors.white)
                multiplayerState.ws.send(textutils.serializeJSON({type="list_lobbies"}))
                local t = os.startTimer(3)
                local lobbyCount = "?"
                while true do
                    local ev, p1, p2 = os.pullEvent()
                    if ev == "timer" and p1 == t then break end
                    if ev == "websocket_message" and p1 == WS_URL then
                        local m = textutils.unserializeJSON(p2)
                        if m and m.type == "lobby_list" then
                            lobbyCount = tostring(#(m.lobbies or {}))
                            break
                        end
                    end
                end
                print("Active lobbies: " .. lobbyCount)
                print("My player ID:   " .. (myPlayerID or "?"))
            else
                term.setTextColor(colors.red)
                print("WebSocket: FAILED")
                print("Server may be offline or unreachable.")
            end
            print("")
            term.setTextColor(colors.lightGray)
            print("Press any key to return...")
            os.pullEvent("key")
        end
    end
end
term.setBackgroundColor(colors.black)
term.clear()
print("CC Call of Duty: Zombies")
print("Initializing...")
print("")
multiplayerState.myPlayerID = tostring(os.getComputerID())
myPlayerID = multiplayerState.myPlayerID
print("Loading maps...")
if not checkAvailableMaps() then
    print("No maps found. Use the Download Maps menu to get maps!")
end
if loadUsername() then
    player.username = loadUsername()
else
    promptUsername()
end
gameStateVars.current = "main_menu"
selectedMenuIdx = 1
sleep(0.5)
startMenuMusic(nil)
function mainGameLoop()
    while true do
    if gameStateVars.current == "main_menu" then
        local username = (player.username and player.username ~= "") and player.username or nil
        local choice = scrollMenu({
            title    = "CC CALL OF DUTY: ZOMBIES",
            subtitle = username and ("Welcome, " .. username) or nil,
            allowBack = false,
            items = {
                {label = "Singleplayer",   sub = "Play solo"},
                {label = "Multiplayer",    sub = "Play with friends"},
                {label = "Download Maps",  sub = "Get new CCZ maps via DLC"},
                {label = "Leaderboard",    sub = "View global high scores"},
                {label = "Test Features",  sub = "Developer / debug tools"},
                {label = "Quit",           sub = "Exit the game", color = colors.red},
            },
            onDraw = function() drawNowPlaying() end
        })
        if choice == 1 then
            gameMode = "singleplayer"
            multiplayerState.isMultiplayer = false
            gameStateVars.current = "map_select"
            selectedMenuIdx = 1
        elseif choice == 2 then
            if connectWebSocket() then
                gameMode = "multiplayer"
                multiplayerState.isMultiplayer = true
                gameStateVars.current = "lobby_menu"
                selectedMenuIdx = 1
            else
                term.clear(); term.setCursorPos(1,1)
                term.setTextColor(colors.red)
                print("Cannot connect to server!")
                sleep(1)
            end
        elseif choice == 3 then
            gameStateVars.current = "dlc_menu"
            dlcState.sel = 1
        elseif choice == 4 then
            if connectWebSocket() then
                fetchLeaderboards(nil)
                gameStateVars.current = "leaderboard"
            else
                term.clear(); term.setCursorPos(1,1)
                term.setTextColor(colors.red)
                print("Cannot connect to server!")
                sleep(1)
            end
        elseif choice == 5 then
            runTestMenu()
        elseif choice == 6 then
            stopMenuMusic()
            term.setBackgroundColor(colors.black)
            term.clear()
            term.setCursorPos(1,1)
            print("Thanks for playing!")
            return
        end
    elseif gameStateVars.current == "map_select" then
        if #availableMaps == 0 then
            term.clear(); term.setCursorPos(1,1)
            term.setTextColor(colors.red)
            print("No maps installed. Use Download Maps to get some!")
            sleep(2)
            gameStateVars.current = "main_menu"
        else
            local mItems = {}
            for _, m in ipairs(availableMaps) do
                local ext = m.file:match("%.%w+$") or ""
                local tag = ext == ".ccz" and "[CCZ] " or "[JSON] "
                mItems[#mItems+1] = {
                    label = tag .. m.name,
                    sub   = m.description ~= "" and m.description or m.file
                }
            end
            local choice = scrollMenu({
                title    = "SELECT MAP",
                subtitle = "Mode: " .. (gameMode or ""):upper(),
                allowBack = true,
                items    = mItems,
                footer   = "ENTER - Start  ` - Back"
            })
            if not choice then
                gameStateVars.current = gameMode == "singleplayer" and "main_menu" or "lobby_menu"
                selectedMenuIdx = 1
            elseif gameMode == "singleplayer" then
                initGame(choice)
            else
                local mapInfo = availableMaps[choice]
                createLobby("Lobby"..myPlayerID, mapInfo.name, choice)
                local timeout = os.startTimer(5)
                while true do
                    local ev, p1, p2 = os.pullEvent()
                    if ev == "timer" and p1 == timeout then
                        term.clear(); term.setCursorPos(1,1)
                        term.setTextColor(colors.red); print("Failed to create lobby!"); sleep(1); break
                    elseif ev == "websocket_message" and p1 == WS_URL then
                        local msg = textutils.unserializeJSON(p2)
                        if msg and msg.type == "lobby_created" then
                            handleServerMessage(msg)
                            lobby.mapIndex = choice
                            lobby.name = "Lobby"..myPlayerID
                            lobby.players = {{id=myPlayerID, name="Host", color=1}}
                            gameStateVars.current = "lobby_host"
                            break
                        end
                    end
                end
            end
        end
    elseif gameStateVars.current == "lobby_menu" then
        local choice = scrollMenu({
            title    = "MULTIPLAYER",
            allowBack = true,
            items = {
                {label = "Create Lobby", sub = "Host a new game"},
                {label = "Join Lobby",   sub = "Browse open games"},
                {label = "Back",         sub = "Return to main menu"},
            }
        })
        if not choice or choice == 3 then
            gameStateVars.current = "main_menu"; selectedMenuIdx = 1
        elseif choice == 1 then
            gameStateVars.current = "map_select"; selectedMenuIdx = 1
        elseif choice == 2 then
            term.clear(); term.setCursorPos(1,1)
            term.setTextColor(colors.yellow); print("Searching for lobbies...")
            foundLobbies = findLobbies()
            gameStateVars.current = "lobby_join"; selectedMenuIdx = 1
        end
    elseif gameStateVars.current == "lobby_host" then
        drawLobbyHost()
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then handleServerMessage(msg) end
        elseif event == "key" then
            if p1 == keys.enter and #lobby.players >= 1 then
                initGame(lobby.mapIndex)
            elseif p1 == keys.grave then
                leaveLobby()
                if multiplayerState.ws then multiplayerState.ws.close() end
                multiplayerState.wsConnected = false
                multiplayerState.lobby = {name="",mapIndex=1,players={},maxPlayers=4,started=false}
                multiplayerState.isHost = false; multiplayerState.lobbyID = nil
                multiplayerState.players = {}; updateMultiplayerAliases()
                gameStateVars.current = "lobby_menu"; selectedMenuIdx = 1
            end
        end
    elseif gameStateVars.current == "lobby_join" then
        if #foundLobbies == 0 then
            local choice = scrollMenu({
                title = "JOIN LOBBY",
                allowBack = true,
                items = {{label = "No lobbies found — press ` to go back", color = colors.red}},
                footer = "R - Refresh  ` - Back"
            })
            foundLobbies = findLobbies()
        else
            local lItems = {}
            for _, lob in ipairs(foundLobbies) do
                lItems[#lItems+1] = {
                    label = lob.name .. "  [" .. (lob.playerCount or 0) .. "/" .. (lob.maxPlayers or 4) .. "]",
                    sub   = "Map: " .. (lob.mapName or "?")
                }
            end
            local choice = scrollMenu({
                title    = "JOIN LOBBY",
                allowBack = true,
                items    = lItems,
                footer   = "ENTER - Join  ` - Back"
            })
            if not choice then
                gameStateVars.current = "lobby_menu"; selectedMenuIdx = 2
            else
                local selLobby = foundLobbies[choice]
                term.clear(); term.setCursorPos(1,1)
                term.setTextColor(colors.yellow); print("Joining lobby...")
                local success, err = joinLobby(selLobby.id)
                if success then
                    multiplayerState.lobby.mapIndex = selLobby.mapIndex
                    multiplayerState.lobby.mapName  = selLobby.mapName
                    multiplayerState.lobby.name     = selLobby.name
                    multiplayerState.isHost = false; updateMultiplayerAliases()
                    gameStateVars.current = "lobby_wait"
                else
                    term.setTextColor(colors.red)
                    print("Failed: " .. (err or "Unknown error")); sleep(2)
                end
            end
        end
    elseif gameStateVars.current == "lobby_wait" then
        drawLobbyHost()
        local w, h = term.getSize()
        term.setCursorPos(1, h-1); term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray); term.clearLine()
        term.write("Waiting for host to start...  ` - Leave")
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then
                handleServerMessage(msg)
                if msg.type == "lobby_updated" then lobby.players = msg.players end
            end
        elseif event == "key" and p1 == keys.grave then
            leaveLobby()
            if multiplayerState.ws then multiplayerState.ws.close() end
            multiplayerState.wsConnected = false
            multiplayerState.lobby = {name="",mapIndex=1,players={},maxPlayers=4,started=false}
            multiplayerState.isHost = false; multiplayerState.lobbyID = nil
            multiplayerState.players = {}; updateMultiplayerAliases()
            gameStateVars.current = "lobby_menu"; selectedMenuIdx = 2
        end
    elseif gameStateVars.current == "paused" then
        local choice = scrollMenu({
            title    = "GAME PAUSED",
            allowBack = true,
            items = {
                {label = "Resume",       sub = "Continue playing"},
                {label = "Debug Tools",  sub = "In-game developer tools", color = colors.yellow},
                {label = "Quit to Menu", sub = "Return to main menu", color = colors.red},
            },
            footer = "ENTER - Select  ` - Resume"
        })
        if not choice or choice == 1 then
            gameStateVars.current = "playing"
        elseif choice == 2 then
            local ALL_PERKS = {
                "perk_juggernog","perk_speedcola","perk_revive","perk_staminup",
                "perk_whoswho","perk_phd","perk_mulekick","perk_cherry","perk_doubletap"
            }
            while true do
                local dbg = scrollMenu({
                    title    = "DEBUG TOOLS",
                    subtitle = "Round " .. roundState.currentRound .. "  |  Zombies: " .. #zombies,
                    allowBack = true,
                    items = {
                        {label = "Announce Test",   sub = "Type a message, fires in HUD immediately"},
                        {label = "Perk Testing",    sub = "Toggle individual perks on/off"},
                        {label = "CCZ Hook Tester", sub = "Call map hooks, see errors"},
                        {label = "Boss Spawner",    sub = "Spawn a registered boss type"},
                        {label = "Give All Perks",  sub = "Instantly grant every perk"},
                        {label = "God Mode",        sub = player._godMode and "Currently: ON" or "Currently: OFF",
                                                    color = player._godMode and colors.lime or colors.lightGray},
                        {label = "Weapons",         sub = "Give/remove weapons & ammo", color = colors.yellow},
                        {label = "Player Check",    sub = "Dump all player state info", color = colors.cyan},
                    },
                    footer = "ENTER - Run  ` - Back to Pause"
                })
                if not dbg then break end
                local function dbgClear(title)
                    term.setBackgroundColor(colors.black); term.clear()
                    local w = term.getSize()
                    term.setCursorPos(math.floor((w-#title)/2), 1)
                    term.setTextColor(colors.yellow); term.write(title)
                    term.setCursorPos(1, 3); term.setTextColor(colors.white)
                end
                if dbg == 1 then
                    dbgClear("ANNOUNCE TEST")
                    print("Type message (blank = default):")
                    term.setTextColor(colors.yellow)
                    local msg = read()
                    if msg == "" then msg = "Test Announcement from Debug Tools!" end
                    table.insert(announceQueue, {
                        text   = msg,
                        expiry = os.epoch("utc") / 1000 + 5
                    })
                    term.setTextColor(colors.lime)
                    print("Queued! Resuming game to see it in the HUD...")
                    sleep(1)
                    break
                elseif dbg == 2 then
                    while true do
                        local pItems = {}
                        for _, pid in ipairs(ALL_PERKS) do
                            local has = hasPerk(pid)
                            pItems[#pItems+1] = {
                                label = (has and "[ON]  " or "[OFF] ") .. pid,
                                sub   = has and "Active — ENTER to remove" or "Inactive — ENTER to give",
                                color = has and colors.lime or colors.lightGray
                            }
                        end
                        pItems[#pItems+1] = {label = "Give ALL perks",   color = colors.yellow}
                        pItems[#pItems+1] = {label = "Remove ALL perks", color = colors.orange}
                        local ps = scrollMenu({
                            title    = "PERK TESTING",
                            subtitle = "Perks: " .. #player.perks .. " / " .. #ALL_PERKS,
                            allowBack = true,
                            items    = pItems,
                            footer   = "ENTER - Toggle  ` - Back"
                        })
                        if not ps then break end
                        if ps <= #ALL_PERKS then
                            local pid = ALL_PERKS[ps]
                            if hasPerk(pid) then
                                for i = #player.perks, 1, -1 do
                                    if player.perks[i] == pid then
                                        table.remove(player.perks, i)
                                    end
                                end
                            else
                                table.insert(player.perks, pid)
                            end
                        elseif pItems[ps].label == "Give ALL perks" then
                            player.perks = {}
                            for _, pid in ipairs(ALL_PERKS) do table.insert(player.perks, pid) end
                        else
                            player.perks = {}
                        end
                    end
                elseif dbg == 7 then
                    while true do
                        local wItems = {}
                        for wid, wdef in pairs(WEAPONS) do
                            local owned = false
                            for _, pw in ipairs(player.weapons) do
                                if pw and pw.id == wid then owned=true; break end
                            end
                            wItems[#wItems+1] = {id=wid,
                                label=(owned and "[ON]  " or "[OFF] ")..(wdef.name or wid),
                                sub=wdef.type..(owned and " — owned" or ""),
                                color=owned and colors.lime or colors.white}
                        end
                        table.sort(wItems, function(a,b) return a.label<b.label end)
                        wItems[#wItems+1] = {id=nil,label="Max Ammo",color=colors.yellow,sub="Refill all"}
                        wItems[#wItems+1] = {id=nil,label="Remove All Weapons",color=colors.orange,sub="Keep M1911"}
                        local ws = scrollMenu({title="WEAPON DEBUG",allowBack=true,items=wItems,footer="ENTER toggle  ` back"})
                        if not ws then break end
                        local ch = wItems[ws]
                        if ch.label == "Max Ammo" then
                            for _,pw in ipairs(player.weapons) do
                                if pw then pw.ammo=pw.mag; pw.reserve=pw.reserve+pw.mag*3 end
                            end
                            ccz.game.announce("Max Ammo!",2); break
                        elseif ch.label == "Remove All Weapons" then
                            player.weapons={}; giveWeaponToPlayer("m1911")
                            player.activeWeaponSlot=1; break
                        elseif ch.id then
                            local removed=false
                            for slot=1,#player.weapons do
                                if player.weapons[slot] and player.weapons[slot].id==ch.id then
                                    player.weapons[slot]=nil; removed=true; break
                                end
                            end
                            if not removed then giveWeaponToPlayer(ch.id) end
                        end
                    end
                elseif dbg == 3 then
                    local mapData = gameStateVars.mapData
                    if not mapData then
                        dbgClear("CCZ HOOK TESTER")
                        print("No map data loaded."); sleep(2)
                    else
                        local hooks = {"onLoad","onRoundStart","onRoundEnd",
                                       "onZombieKill","onPlayerDowned","onUpdate"}
                        local hItems = {}
                        for _, h in ipairs(hooks) do
                            local has = mapData[h] ~= nil
                            hItems[#hItems+1] = {
                                label = (has and "[defined] " or "[missing] ") .. h,
                                sub   = has and "Click to fire this hook" or "Not implemented in this map",
                                color = has and colors.white or colors.gray
                            }
                        end
                        local hs = scrollMenu({
                            title    = "CCZ HOOK TESTER",
                            subtitle = "Map: " .. (mapData.name or "?"),
                            allowBack = true,
                            items    = hItems,
                            footer   = "ENTER - Fire hook  ` - Back"
                        })
                        if hs then
                            local hookName = hooks[hs]
                            local fn = mapData[hookName]
                            dbgClear("HOOK RESULT: " .. hookName)
                            if fn then
                                local ok, err = pcall(fn, gameStateVars, roundState.currentRound, player)
                                if ok then
                                    term.setTextColor(colors.lime)
                                    print("OK — fired without error")
                                else
                                    term.setTextColor(colors.red)
                                    print("ERROR:")
                                    print(tostring(err))
                                end
                            else
                                term.setTextColor(colors.gray)
                                print(hookName .. " is not defined in this map.")
                            end
                            sleep(2)
                        end
                    end
                elseif dbg == 4 then
                    local allDefs = ccz.boss._getAllDefs()
                    local bossTypes = {}
                    for bt, _ in pairs(allDefs) do table.insert(bossTypes, bt) end
                    table.sort(bossTypes)
                    if #bossTypes == 0 then
                        dbgClear("BOSS SPAWNER")
                        print("No boss types registered.")
                        print("Use ccz.boss.register() in a map's onLoad.")
                        sleep(2)
                    else
                        local bItems = {}
                        for _, bt in ipairs(bossTypes) do
                            local def = allDefs[bt]
                            bItems[#bItems+1] = {
                                label = bt,
                                sub   = "HP: " .. tostring(def.health or "round-scaled") ..
                                        "  Pts: " .. tostring(def.killPoints or 500)
                            }
                        end
                        local bs = scrollMenu({title="BOSS SPAWNER", allowBack=true, items=bItems})
                        if bs then
                            zombie.spawnZombie(bossTypes[bs])
                            dbgClear("BOSS SPAWNER")
                            term.setTextColor(colors.lime)
                            print("Spawned: " .. bossTypes[bs])
                            sleep(1)
                            break
                        end
                    end
                elseif dbg == 5 then
                    player.perks = {}
                    for _, pid in ipairs(ALL_PERKS) do table.insert(player.perks, pid) end
                    dbgClear("GIVE ALL PERKS")
                    term.setTextColor(colors.lime)
                    print("All " .. #ALL_PERKS .. " perks granted!"); sleep(1)
                elseif dbg == 6 then
                    player._godMode = not player._godMode
                    dbgClear("GOD MODE")
                    term.setTextColor(player._godMode and colors.lime or colors.orange)
                    print("God Mode: " .. (player._godMode and "ON" or "OFF")); sleep(1)
                elseif dbg == 8 then
                    dbgClear("PLAYER CHECK")
                    local w = term.getSize()
                    local function row(label, value, col)
                        term.setTextColor(colors.yellow)
                        term.write(label .. ": ")
                        term.setTextColor(col or colors.white)
                        print(tostring(value))
                    end
                    row("Username",   player.username  or "N/A")
                    row("Character",  playerCharacter and playerCharacter.name or "None assigned")
                    row("Player ID",  myPlayerID or "N/A")
                    row("Color",      tostring(player.color))
                    print("")
                    local hpPct = math.floor((player.health / math.max(1, player.maxHealth)) * 100)
                    row("Health",     string.format("%d / %d  (%d%%)", player.health, player.maxHealth, hpPct),
                        hpPct > 50 and colors.lime or hpPct > 25 and colors.yellow or colors.red)
                    row("Downed",     player.isDowned and "YES" or "no",
                        player.isDowned and colors.red or colors.lime)
                    row("Afterlife",  player.inAfterlife and
                        string.format("YES (%.1fs left)", player.afterlifeTimeLeft) or "no",
                        player.inAfterlife and colors.cyan or colors.white)
                    row("God Mode",   player._godMode and "ON" or "OFF",
                        player._godMode and colors.lime or colors.lightGray)
                    row("QR Uses",    string.format("%d / 3", player.quickReviveUses or 0),
                        (player.quickReviveUses or 0) >= 3 and colors.red or colors.white)
                    print("")
                    row("Position",  string.format("X=%.2f  Y=%.2f  Z=%.2f", player.x, player.y, player.z))
                    row("Rotation",  string.format("Yaw=%.1f  Pitch=%.1f", player.rotY or 0, player.rotZ or 0))
                    row("On Ground", player.onGround and "yes" or "NO",
                        player.onGround and colors.white or colors.orange)
                    row("VelocityY", string.format("%.2f", player.velocityY or 0))
                    row("Sprinting", isSprinting and "yes" or "no")
                    row("Stamina",   string.format("%.0f%%", (stamina or 1) * 100))
                    print("")
                    row("Points",    player.points or 0)
                    row("Kills",     player.kills  or 0)
                    row("Round",     roundState.currentRound)
                    print("")
                    row("Active Slot", string.format("%d / %d", player.activeWeaponSlot, player.maxWeaponSlots))
                    for slot = 1, player.maxWeaponSlots do
                        local pw = player.weapons[slot]
                        if pw then
                            local tag = slot == player.activeWeaponSlot and "* " or "  "
                            local papTag = pw.isPaP and " [PAP]" or ""
                            term.setTextColor(colors.yellow)
                            term.write(string.format("  Slot %d%s: ", slot, tag))
                            term.setTextColor(colors.white)
                            print(string.format("%s%s  Ammo: %d/%d%s",
                                pw.name or pw.id, papTag, pw.ammo or 0, pw.reserve or 0,
                                pw.isReloading and "  [RELOADING]" or ""))
                        else
                            term.setTextColor(colors.yellow)
                            term.write(string.format("  Slot %d: ", slot))
                            term.setTextColor(colors.gray)
                            print("(empty)")
                        end
                    end
                    print("")
                    if #player.perks == 0 then
                        row("Perks", "(none)", colors.gray)
                    else
                        term.setTextColor(colors.yellow)
                        print("Perks (" .. #player.perks .. "):")
                        for _, pid in ipairs(player.perks) do
                            term.setTextColor(perkColors[pid] or colors.white)
                            print("  " .. pid)
                        end
                    end
                    print("")
                    local acc = player.stats.shotsFired > 0
                        and math.floor(player.stats.shotsHit / player.stats.shotsFired * 100) or 0
                    row("Shots Fired",   player.stats.shotsFired)
                    row("Shots Hit",     string.format("%d  (%d%% accuracy)", player.stats.shotsHit, acc))
                    row("Headshots",     player.stats.headshots)
                    row("Damage Dealt",  player.stats.damageDealt)
                    row("Damage Taken",  player.stats.damageTaken)
                    row("Downs",         player.stats.downs)
                    row("Revives",       player.stats.revives)
                    print("")
                    if multiplayerState.isMultiplayer then
                        row("Multiplayer", "YES — " .. (multiplayerState.isHost and "HOST" or "CLIENT"),
                            colors.cyan)
                        row("Lobby ID",   lobbyID or "N/A")
                        local pCount = 0
                        for _ in pairs(players) do pCount = pCount + 1 end
                        row("Other Players", pCount)
                    else
                        row("Multiplayer", "Singleplayer", colors.lightGray)
                    end
                    term.setTextColor(colors.lightGray)
                    print("")
                    print("Press any key to return...")
                    os.pullEvent("key")
                end
            end
            if gameStateVars.current ~= "main_menu" then
                gameStateVars.current = "playing"
                gameLoop()
            end
        elseif choice == 3 then
            if multiplayerState.isMultiplayer then
                leaveLobby()
                if multiplayerState.ws then multiplayerState.ws.close() end
            end
            gameStateVars.current = "main_menu"; selectedMenuIdx = 1
        end
    elseif gameStateVars.current == "playing" then
        gameLoop()
    elseif gameStateVars.current == "leaderboard" then
        drawLeaderboard()
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then handleServerMessage(msg) end
        elseif event == "key" and p1 == keys.grave then
            gameStateVars.current = "main_menu"; selectedMenuIdx = 1
        end
    elseif gameStateVars.current == "gameover" then
        ccz.palette.reset()
        term.setPaletteColor(colors.black, 0, 0, 0)
        drawGameOver()
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == WS_URL then
            local msg = textutils.unserializeJSON(p2)
            if msg then handleServerMessage(msg) end
        elseif event == "key" and p1 == keys.enter then
            if multiplayerState.isMultiplayer then
                leaveLobby()
                if multiplayerState.ws then multiplayerState.ws.close() end
                multiplayerState.wsConnected = false
            end
            gameStateVars.current = "main_menu"; selectedMenuIdx = 1; leaderboardData = nil
        end
    elseif gameStateVars.current == "dlc_menu" then
        dlcHandle()
    end
    end
end
parallel.waitForAny(mainGameLoop, menuMusicAudioLoop, menuMusicHttpLoop)
