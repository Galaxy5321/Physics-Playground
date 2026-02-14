local DiscordPresence = require("discord_presence")
local DiscordPresenceConfig = require("discord_presence_config")

function love.load()
    WINDOW_W, WINDOW_H = 1280, 720
    fullscreen = false
    DT = 0

    love.window.setMode(WINDOW_W, WINDOW_H, {
        resizable = true,
        vsync = false,
        minwidth = 800,
        minheight = 600
    })


    love.window.setTitle("Physics Playground")

    mouseJoint = nil

    selecting = false
    selectStartX = 0
    selectStartY = 0
    selectEndX = 0
    selectEndY = 0

    selectedObjects = {}

    -- Tools
    TOOL_SELECT = 1
    TOOL_MOVE   = 2
    TOOL_BALL   = 3
    TOOL_BOX    = 4
    TOOL_DRAG   = 5
    TOOL_FREEZE = 6
    TOOL_MAGNET = 7
    TOOL_WELD   = 8
    TOOL_SPRING = 9
    TOOL_ROPE   = 10

    currentTool = TOOL_SELECT

    dragForce = 10000

    magnetStrength = 1500
    magnetRadius = 150
    magnetMode = "attract" -- or "repel"

    rotateSpeed = 10 * 10000
    originalRS = rotateSpeed
    qDown = false
    eDown = false

    -- Properties panel
    PROPS_W = 200
    PROPS_H = 300
    PROPS_X = WINDOW_W - PROPS_W - 10
    PROPS_Y = WINDOW_H - PROPS_H - 10

    propsScroll = 0
    PROPERTY_PANEL_W = 280
    PROPERTY_ROW_H = 28
    PROPS_SCROLL_SPEED = 30

    hexColorInput = ""
    hexColorActive = false
    hexBoxX, hexBoxY, hexBoxW, hexBoxH = 0,0,0,0

    draggingGroup = false
    dragOffset = {}

    -- Shape Tools
    dragging = false
    dragStartX, dragStartY = 0, 0
    dragEndX, dragEndY = 0, 0

    -- Camera
    camX, camY = 0, 0
    panning = false
    panStartX, panStartY = 0, 0
    camStartX, camStartY = 0, 0

    -- Camera Zoom
    camScale = 1
    ZOOM_MIN = 0.10
    ZOOM_MAX = 3
    ZOOM_SPEED = 0.1

    timeScale = 1
    paused = false

    inSlowMotion = false
    slowMotionIcon = love.graphics.newImage("textures/Slow motion icon.png")
    slowMotionMod = 0.5

    outLimits = false

    -- Game States
    STATE_MENU = "menu"
    STATE_WORLD = "world"
    STATE_LOAD = "load"
    STATE_SETTINGS = "settings"

    gameState = STATE_MENU

    settings = {
        -- Audio
        masterVolume = 1.0,

        -- Display
        fullscreen = false,
        vsync = true,

        -- Editor
        showGrid = true,
        autoSaveInterval = 120,
        slowMotionModifier = 0.5,

        -- Grid tuning
        gridSize = 64,
        gridFadeZoom = 0.15,
    }

    activeNumberInput = nil   -- id string
    numberInputText = ""
    numberInputBindings = {}

    SETTINGS_FILE = "settings.lua"
    CONTROLS_FILE = "controls.lua"
    LOG_DIR = "logs"
    LOG_FILE = LOG_DIR .. "/latest.log"
    
    SAVE_DIR = "saves/"
    love.filesystem.createDirectory(SAVE_DIR)

    currentWorldName = nil   -- like "my_world_1.lua"
    isNamingWorld = false
    worldNameInput = ""
    hoveredSaveIndex = nil

    AUTO_SAVE_INTERVAL = 60 -- seconds
    autoSaveTimer = 0

    -- Grid stuff
    GRID_SIZE = 32
    GRID_COLOR = {1,1,1,0.08}

    -- Load Menu stuff
    loadMenuScroll = 0
    LOAD_ROW_HEIGHT = 34
    settingsScroll = 0

    lastClickTime = 0
    DOUBLE_CLICK_TIME = 0.35
    lastClickedFile = nil

    loadSearch = ""

    saveCache = {} -- { filename, meta }

    buttonAnim = buttonAnim or {}

    uiConsumedClick = false

    -- Main menu stuff
    menuWorld = nil
    menuObjects = {}
    menuSpawnTimer = 0
    menuGroundBody = nil
    menuGroundShape = nil
    menuGroundFixture = nil

    -- Particles
    impactParticles = {}
    weldParticles = {}

    -- Copy and paste stuff
    copiedObjectData = nil
    clipboard = {}
    propertyClipboard = nil
    
    -- flash
    flashTimer = 0
    flashColor = {0, 1, 0} -- default green
    flashDuration = 0.25

    -- Controls helper
    controlHints = getDefaultControlHints()
    controls = getDefaultControls()
    rebindingAction = nil
    showTesterHUD = false
    hideUI = false
    tutorialSkipped = false
    lastWeldParticleTime = -10

    joints = {}
    jointLinkStart = nil -- { obj, ax, ay }
    selectedJoint = nil
    springFrequency = 4.0
    springDamping = 0.35
    weldMode = "point" -- "point" or "edge"
    weldRigidity = "soft" -- "soft" or "hard"
    edgeWeldDrag = {
        active = false,
        obj = nil,
        originalType = nil,
        offsetX = 0,
        offsetY = 0,
        candidate = nil,
        ax = 0, ay = 0,
        bx = 0, by = 0,
        dist = math.huge,
    }
    EDGE_WELD_HOVER_DIST = 40
    EDGE_WELD_SNAP_DIST = 8
    SECRET_CODES = {
        { id = "konami", action = "random_drop", sequence = {"up", "up", "down", "down", "left", "right", "left", "right", "b", "a"} },
        { id = "party", action = "party", sequence = {"p", "a", "r", "t", "y"} },
        { id = "boom", action = "boom", sequence = {"b", "o", "o", "m"} },
        { id = "tiny", action = "tiny", sequence = {"t", "i", "n", "y"} },
        { id = "hud", action = "hud", sequence = {"h", "u", "d"} },
    }
    secretCodeProgress = {
        konami = 1,
        party = 1,
        boom = 1,
        tiny = 1,
        hud = 1,
    }

    undoStack = {}
    redoStack = {}
    MAX_HISTORY = 60
    historySuspended = false
    historyToastText = nil
    historyToastTimer = 0

    -- Resize Handles
    resizeState = {
        active = false,
        obj = nil,
        handle = nil,
        startMouseX = 0,
        startMouseY = 0,
        startW = 0,
        startH = 0
    }

    HANDLE_SIZE = 12
    hoveredHandle = nil
    activeHandle = nil


    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)

    bodies = {}

    -- Ground
    ground = {}
    ground.body = love.physics.newBody(world, 400, 2550, "static")
    ground.shape = love.physics.newRectangleShape(80000, 4000)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)

    -- Functions that run on start
    loadSettings()
    loadControls()
    initUISfx()
    local rpcOk = DiscordPresence.init(DiscordPresenceConfig)
    initMenuWorld()

    love.filesystem.createDirectory(LOG_DIR)
    love.filesystem.write(LOG_FILE, "")
    local lvMajor, lvMinor, lvRevision, lvCodename = love.getVersion()
    logLine(string.format(
        "Session started | LOVE %d.%d.%d (%s) | window=%dx%d | platform=%s",
        lvMajor, lvMinor, lvRevision, tostring(lvCodename),
        WINDOW_W, WINDOW_H, tostring(love.system.getOS())
    ))
    logLine("Discord RPC status: " .. (rpcOk and "initialized" or "disabled/unavailable"))

    love.audio.setVolume(settings.masterVolume or 1)
    love.window.setFullscreen(settings.fullscreen or false)
    love.window.setVSync(settings.vsync and 1 or 0)

    AUTO_SAVE_INTERVAL = settings.autoSaveInterval or 120

    world:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

function love.update(dt)
    local scaledDt = dt * timeScale
    DT = scaledDt
    world:update(scaledDt)
    pruneJoints()
    if edgeWeldDrag.active then
        updateEdgeWeldCandidate()
    end
    if historyToastTimer > 0 then
        historyToastTimer = math.max(0, historyToastTimer - dt)
    end

    -- Rotation Logic/Tool
    if #selectedObjects > 0 then
        local rotateDir = 0
        if qDown then rotateDir = rotateDir + 1 end
        if eDown then rotateDir = rotateDir - 1 end

        if rotateDir ~= 0 then
            rotateSpeed = rotateSpeed + math.rad(1)
            local forcedDelta = rotateDir * rotateSpeed * 0.00002 * scaledDt

            if currentTool == TOOL_MOVE then
                rotateSelectedGroupForced(forcedDelta)
            else
                for _, obj in ipairs(selectedObjects) do
                    local body = obj.body
                    body:applyTorque(rotateDir * rotateSpeed)
                end
            end
        end
    end

    -- Auto save timer
    if gameState == STATE_WORLD and currentWorldName then
        autoSaveTimer = autoSaveTimer + dt

        if autoSaveTimer >= AUTO_SAVE_INTERVAL then
            autoSaveTimer = 0
            saveWorld("saves/" .. currentWorldName)
            logInfo("Auto-saved: " .. tostring(currentWorldName))
        end
    end

    -- Magnet Tool
    if currentTool == TOOL_MAGNET and love.mouse.isDown(1) then
        local sx, sy = love.mouse.getPosition()
        local mx, my = screenToWorld(sx, sy)

        for _, obj in ipairs(bodies) do
            local ox, oy = obj.body:getPosition()

            local dx = mx - ox
            local dy = my - oy
            local dist = math.sqrt(dx*dx + dy*dy)

            if dist > 1 and dist < magnetRadius then
                local nx = dx / dist
                local ny = dy / dist

                local falloff = 1 - (dist / magnetRadius)

                local force = magnetStrength * falloff

                -- REPEL = flip direction
                if magnetMode == "repel" then
                    force = -force
                end

                obj.body:applyForce(nx * force, ny * force)
            end
        end
    end

    if gameState == STATE_MENU and menuWorld then
        menuWorld:update(dt)

        menuSpawnTimer = menuSpawnTimer - dt
        if menuSpawnTimer <= 0 then
            spawnMenuObject()
            menuSpawnTimer = 0.4
        end

        -- Keep menu visuals and physics in sync; remove off-screen / dead bodies.
        for i = #menuObjects, 1, -1 do
            local obj = menuObjects[i]
            local body = obj and obj.body
            local remove = false

            if (not body) or body:isDestroyed() then
                remove = true
            else
                local bx, by = body:getPosition()
                if by > WINDOW_H + 250 or bx < -250 or bx > WINDOW_W + 250 then
                    remove = true
                end
            end

            if remove then
                if body and not body:isDestroyed() then
                    body:destroy()
                end
                table.remove(menuObjects, i)
            end
        end
    end

    DiscordPresence.update({
        gameState = gameState,
        currentTool = currentTool,
        paused = paused,
        worldName = currentWorldName,
        objectCount = #bodies,
        jointCount = #joints,
    })

    local PARTICLE_GRAVITY = 1400

    for i = #impactParticles, 1, -1 do
        local p = impactParticles[i]

        -- Gravity
        p.vy = p.vy + PARTICLE_GRAVITY * scaledDt

        -- Move
        p.x = p.x + p.vx * scaledDt
        p.y = p.y + p.vy * scaledDt

        -- Fade
        p.life = p.life - scaledDt
        p.alpha = math.max(0, p.life)

        if p.life <= 0 then
            table.remove(impactParticles, i)
        end
    end

    for i = #weldParticles, 1, -1 do
        local p = weldParticles[i]
        p.vy = p.vy + 1000 * scaledDt
        p.x = p.x + p.vx * scaledDt
        p.y = p.y + p.vy * scaledDt
        p.life = p.life - scaledDt
        if p.life <= 0 then
            table.remove(weldParticles, i)
        end
    end

    -- Flash thing
    for _, obj in ipairs(bodies) do
        if obj.flashTimer and obj.flashTimer > 0 then
            obj.flashTimer = math.max(0, obj.flashTimer - dt)
        end
    end

    -- Resize Handles
    if resizeState.active and currentTool == TOOL_SELECT then
        local mx,my = screenToWorld(love.mouse.getPosition())

        local dx = mx - resizeState.startMouseX
        local dy = my - resizeState.startMouseY

        local speed = 1
        if love.keyboard.isDown("lshift","rshift") then speed = 0.2 end
        if love.keyboard.isDown("lctrl","rctrl") then speed = 3 end

        if resizeState.obj and resizeState.obj.shapeType == "ball" then
            local newRadius = resizeState.startW + dx*speed
            newRadius = math.max(5, newRadius)
            resizeObject(resizeState.obj, newRadius, newRadius)
        else
            local angle = resizeState.obj and resizeState.obj.body:getAngle() or 0
            -- Transform drag delta into object-local space so rotated boxes resize naturally.
            local localDX = dx * math.cos(angle) + dy * math.sin(angle)
            local localDY = -dx * math.sin(angle) + dy * math.cos(angle)

            local newW = resizeState.startW
            local newH = resizeState.startH

            if resizeState.handle == "br" then
                newW = newW + localDX*speed*2
                newH = newH + localDY*speed*2
            elseif resizeState.handle == "tr" then
                newW = newW + localDX*speed*2
                newH = newH - localDY*speed*2
            elseif resizeState.handle == "bl" then
                newW = newW - localDX*speed*2
                newH = newH + localDY*speed*2
            elseif resizeState.handle == "tl" then
                newW = newW - localDX*speed*2
                newH = newH - localDY*speed*2
            end

            newW = math.max(10,newW)
            newH = math.max(10,newH)

            resizeObject(resizeState.obj,newW,newH)
        end
    end

end

function love.resize(w, h)
    WINDOW_W = w
    WINDOW_H = h
    PROPS_X = WINDOW_W - PROPS_W - 10
    PROPS_Y = WINDOW_H - PROPS_H - 10
    if menuGroundBody and not menuGroundBody:isDestroyed() then
        menuGroundBody:setPosition(WINDOW_W / 2, WINDOW_H + 20)
        if menuGroundFixture and not menuGroundFixture:isDestroyed() then
            menuGroundFixture:destroy()
        end
        if menuGroundShape then
            menuGroundShape:release()
        end
        menuGroundShape = love.physics.newRectangleShape(WINDOW_W, 40)
        menuGroundFixture = love.physics.newFixture(menuGroundBody, menuGroundShape)
    end
end

function love.draw()
    uiButtons = {}
    numberInputBindings = {}
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) -- dark gray

    -- =====================
    -- MENU (SCREEN SPACE)
    -- =====================
    if gameState == STATE_MENU then
        drawMainMenu()
        return
    end

    if gameState == STATE_LOAD then
        drawLoadMenu()
        return
    end

    if gameState == STATE_SETTINGS then
        drawSettingsMenu()
        return
    end

    -- =====================
    -- WORLD (WORLD SPACE)
    -- =====================
    love.graphics.push()
    love.graphics.translate(camX, camY)
    love.graphics.scale(camScale)

    drawGrid()
    

    love.graphics.setColor(0.05, 0.05, 0.05)
    drawBody(ground)

    for _, obj in ipairs(bodies) do
        -- Always draw real color
        local r, g, b = obj.color[1], obj.color[2], obj.color[3]

        if obj.flashTimer and obj.flashTimer > 0 then
            local t = obj.flashTimer / obj.flashDuration
            local fr, fg, fb = obj.flashColor[1], obj.flashColor[2], obj.flashColor[3]

            -- Lerp toward flash color
            r = r + (fr - r) * t
            g = g + (fg - g) * t
            b = b + (fb - b) * t
        end

        love.graphics.setColor(r, g, b)

        drawBody(obj)

        -- Draw outline if selected
        if obj.selected then
            drawSelectionOutline(obj)
            if currentTool == TOOL_SELECT then
                drawResizeHandles(obj)
            end
        end
    end

    if currentTool == TOOL_SELECT then
        local sx, sy = love.mouse.getPosition()
        local mx, my = screenToWorld(sx, sy)
        local hoveredObj = getObjectAtPoint(mx, my) or getObjectNearPoint(mx, my, 10 / camScale)
        if hoveredObj and not hoveredObj.selected then
            love.graphics.setColor(0.2, 1.0, 1.0, 0.9)
            love.graphics.setLineWidth(1.5 / camScale)
            if hoveredObj.shape:typeOf("CircleShape") then
                local x, y = hoveredObj.body:getPosition()
                love.graphics.circle("line", x, y, hoveredObj.shape:getRadius() + 3 / camScale)
            else
                love.graphics.polygon("line", hoveredObj.body:getWorldPoints(hoveredObj.shape:getPoints()))
            end
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1,1,1,1)
        end
    end

    -- Magnet Tool
    if currentTool == TOOL_MAGNET then
        local sx, sy = love.mouse.getPosition()
        local mx, my = screenToWorld(sx, sy)

        love.graphics.setColor(0, 1, 1, 0.25)
        love.graphics.circle("fill", mx, my, magnetRadius)

        love.graphics.setColor(0, 1, 1, 0.8)
        love.graphics.circle("line", mx, my, magnetRadius)

        love.graphics.setColor(1,1,1,1)
    end

    if isJointTool(currentTool) then
        drawPendingJointPreview()
    end

    if edgeWeldDrag.active then
        drawEdgeWeldPreview()
    end

    -- Selection box
    if selecting then
        local x = selectStartX
        local y = selectStartY
        local w = selectEndX - selectStartX
        local h = selectEndY - selectStartY

        love.graphics.setColor(0, 1, 1, 0.3)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(0, 1, 1)
        love.graphics.rectangle("line", x, y, w, h)
    end

    if dragging then
        local x = math.min(dragStartX, dragEndX)
        local y = math.min(dragStartY, dragEndY)
        local w = math.abs(dragEndX - dragStartX)
        local h = math.abs(dragEndY - dragStartY)


        local cx = (dragStartX + dragEndX) / 2
        local cy = (dragStartY + dragEndY) / 2
                
        if currentTool == TOOL_BOX then
            love.graphics.setColor(0, 0.5, 1, 0.3)
            love.graphics.rectangle("fill", x, y, w, h)
            love.graphics.setColor(0, 0.5, 1)
            love.graphics.rectangle("line", x, y, w, h)

        elseif currentTool == TOOL_BALL then
            local radius = math.sqrt(w*w + h*h) / 2
            love.graphics.setColor(0, 0.5, 1, 0.3)
            love.graphics.circle("fill", cx, cy, radius)
            love.graphics.setColor(0, 0.5, 1)
            love.graphics.circle("line", cx, cy, radius)
        end
    end

    for _, p in ipairs(impactParticles) do
        local r = p.radius or 3  -- fallback radius

        love.graphics.setColor(1,1,1, p.alpha and (p.alpha * 0.6) or 0.6)
        love.graphics.circle("fill", p.x, p.y, r)
    end

    for _, p in ipairs(weldParticles) do
        local t = math.max(0, p.life / p.maxLife)
        local r = (p.radius or 2) * (0.5 + t)
        love.graphics.setColor(1.0, 0.85, 0.2, 0.85 * t)
        love.graphics.circle("fill", p.x, p.y, r)
    end
    -- Keep joints/links on top of bodies and particles for visibility/selection.
    drawJointLinks()
    love.graphics.setColor(1,1,1,1)

    love.graphics.pop()

    -- =====================
    -- UI (SCREEN SPACE)
    -- =====================
    if not hideUI then
        drawUI()
    end

    local hint = getNextHint()
    if hint and not hideUI then
        local t = love.timer.getTime()
        local pulse = 0.5 + math.sin(t * 3) * 0.1

        local bx = 20
        local by = WINDOW_H - 90
        local bw = 460
        local bh = 52

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle("fill", bx+3, by+4, bw, bh, 12, 12)

        -- Background (glass style)
        love.graphics.setColor(0.1, 0.15, 0.2, 0.85)
        love.graphics.rectangle("fill", bx, by, bw, bh, 12, 12)

        -- Glow border
        love.graphics.setColor(0, 1, 1, pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, bw, bh, 12, 12)

        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(hint, bx, by + 14, bw, "center")

        drawButton("Skip Tutorial", bx + bw - 130, by + bh - 30, 118, 22, function()
            completeTutorialHints()
        end, { theme = "danger" })
    end

    -- Saving World UI
    if isNamingWorld then
        -- Dark overlay
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", 0,0, WINDOW_W, WINDOW_H)

        local w, h = 400, 120
        local x = (WINDOW_W - w)/2
        local y = (WINDOW_H - h)/2

        love.graphics.setColor(0.15,0.15,0.15)
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("line", x, y, w, h)

        love.graphics.printf("Enter World Name:", x, y + 15, w, "center")

        -- Textbox
        love.graphics.rectangle("line", x+40, y+60, w-80, 30)
        love.graphics.print(worldNameInput .. "_", x+50, y+65)
    end

    if hideUI then
        love.graphics.setColor(0.05, 0.08, 0.12, 0.78)
        love.graphics.rectangle("fill", WINDOW_W - 198, WINDOW_H - 34, 188, 24, 6, 6)
        love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.55)
        love.graphics.rectangle("line", WINDOW_W - 198, WINDOW_H - 34, 188, 24, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("Press TAB to show UI", WINDOW_W - 188, WINDOW_H - 28)
    end

end

function love.mousepressed(x, y, button)
    uiConsumedClick = false
    -- Middle mouse = pan camera
    if button == 3 then
        controlHints.pan = true
        panning = true
        panStartX, panStartY = x, y
        camStartX, camStartY = camX, camY
        return
    end

    if button ~= 1 then return end

    -- UI click FIRST (screen space)
    for _, btn in ipairs(uiButtons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            playUISfx("click", 1.0, 1.0)
            btn.onClick()
            uiConsumedClick = true
            return
        end
    end

    -- Clicking anywhere else exits numeric text-entry mode.
    activeNumberInput = nil

    -- =====================
    -- Load Menu Double Click
    -- =====================
    if gameState == STATE_LOAD and button == 1 then
        local panelW = math.floor(WINDOW_W * 0.65)
        local panelH = math.floor(WINDOW_H * 0.75)
        local panelX = math.floor((WINDOW_W - panelW) / 2)
        local panelY = math.floor((WINDOW_H - panelH) / 2)

        local listX = panelX + 30
        local listY = panelY + 140
        local listW = panelW - 60
        local rowH = LOAD_ROW_HEIGHT
        local viewH = panelH - 180

        local files = {}

        for _, entry in ipairs(saveCache) do
            local name = entry.file:lower()
            if loadSearch == "" or name:find(loadSearch:lower(), 1, true) then
                table.insert(files, entry.file)
            end
        end

        
        for i, file in ipairs(files) do
            local rx = listX
            local ry = listY + (i-1) * LOAD_ROW_HEIGHT + loadMenuScroll
            local rw = listW
            local rh = rowH

            if x >= rx and x <= rx+rw and y >= ry and y <= ry+rh then
                local now = love.timer.getTime()

                if lastClickedFile == file and (now - lastClickTime) <= DOUBLE_CLICK_TIME then
                    -- DOUBLE CLICK → LOAD
                    playUISfx("click", 1.08, 1.0)
                    local worldDir = getWorldDir(file)
                    loadWorld(worldDir .. "world.lua")

                    currentWorldName = file
                    autoSaveTimer = 0
                    gameState = STATE_WORLD
                    logLine("State -> world (loaded from menu): " .. tostring(file))

                    lastClickedFile = nil
                    lastClickTime = 0
                    uiConsumedClick = true
                    return
                else
                    -- SINGLE CLICK (select row)
                    playUISfx("tick", 1.0, 0.9)
                    lastClickedFile = file
                    lastClickTime = now
                    uiConsumedClick = true
                    return
                end
            end
            

        end

        -- Clicked empty space -> clear selection
        lastClickedFile = nil
        lastClickTime = 0
    end
    
    -- Hex color focus (SCREEN SPACE)
    if x >= hexBoxX and x <= hexBoxX + hexBoxW and
    y >= hexBoxY and y <= hexBoxY + hexBoxH then
        hexColorActive = true
        playUISfx("tick", 1.15, 0.8)
        uiConsumedClick = true
        return
    else
        hexColorActive = false
    end

    -- ⛔ UI CONSUMED = NO WORLD INPUT
    if uiConsumedClick then
        return
    end

    if x >= PROPS_X and x <= PROPS_X + PROPS_W and
       y >= PROPS_Y and y <= PROPS_Y + PROPS_H then
        playUISfx("tick", 1.0, 0.7)
        uiConsumedClick = true
        return
    end

    local wx, wy = screenToWorld(x, y)

    if currentTool == TOOL_WELD and weldMode == "edge" then
        local obj = getObjectAtPoint(wx, wy)
        if obj then
            controlHints.weld = true
            clearAllSelection()
            beginEdgeWeldDrag(obj, wx, wy)
        else
            cancelEdgeWeldDrag()
        end
        return
    end

    if handleJointToolClick(wx, wy) then
        if currentTool == TOOL_WELD then controlHints.weld = true end
        if currentTool == TOOL_SPRING then controlHints.spring = true end
        if currentTool == TOOL_ROPE then controlHints.rope = true end
        return
    end

    if currentTool == TOOL_SELECT then
        local ctrl = love.keyboard.isDown("lctrl", "rctrl")
        local joint = getJointAtPoint(wx, wy, 14 / camScale)
        if joint then
            selectJoint(joint)
            return
        end

        local obj = getObjectAtPoint(wx, wy)
        if not obj then
            obj = getObjectNearPoint(wx, wy, 10 / camScale)
        end

        if obj then
            -- Click select object
            obj.originalType = obj.body:getType()
            selectObject(obj, ctrl)
        else

            -- Box select
            selectedJoint = nil
            selecting = true
            selectStartX, selectStartY = wx, wy
            selectEndX, selectEndY = wx, wy

            if uiConsumedClick then
                return
            end
            if not ctrl then
                clearAllSelection()
            end
        end

    elseif currentTool == TOOL_MOVE then
        if #selectedObjects > 0 then
            pushUndoState()
            draggingGroup = true
            dragOffset = {}
            for _, obj in ipairs(selectedObjects) do
                local bx, by = obj.body:getPosition()
                dragOffset[obj] = { x = bx - wx, y = by - wy }
                obj.originalType = obj.body:getType()
                obj.body:setType("kinematic")
            end
        end

    elseif currentTool == TOOL_DRAG then
        local obj = getObjectAtPoint(wx, wy)
        if obj then
            mouseJoint = love.physics.newMouseJoint(obj.body, wx, wy)
            mouseJoint:setMaxForce(dragForce)
        end
    
    elseif currentTool == TOOL_FREEZE then
        local obj = getObjectAtPoint(wx, wy)
        if obj then
            pushUndoState()
            toggleFreeze(obj)
        end
    end

    if currentTool == TOOL_BOX or currentTool == TOOL_BALL then
        dragging = true
        dragStartX, dragStartY = wx, wy
        dragEndX, dragEndY = wx, wy
    end

    if button == 1 and #selectedObjects == 1 then
        local obj = selectedObjects[1]
        local handles = getResizeHandles(obj)

        local mx,my = screenToWorld(x,y)
        local hitRadius = (HANDLE_SIZE / camScale)

        for _,hnd in ipairs(handles) do
            local dx = mx - hnd[1]
            local dy = my - hnd[2]
            if (dx * dx + dy * dy) <= (hitRadius * hitRadius) then
                pushUndoState()
                resizeState.active = true
                resizeState.obj = obj
                resizeState.handle = hnd[3]
                resizeState.startMouseX = mx
                resizeState.startMouseY = my
                resizeState.startW = obj.shapeType == "ball" and obj.radius or obj.width
                resizeState.startH = obj.shapeType == "ball" and obj.radius or obj.height
                return
            end
        end
    end

end

function love.mousemoved(x, y)
    -- Camera pan
    if panning then
        camX = camStartX + (x - panStartX)
        camY = camStartY + (y - panStartY)
        return
    end

    local wx, wy = screenToWorld(x, y)

    if edgeWeldDrag.active and edgeWeldDrag.obj and edgeWeldDrag.obj.body and not edgeWeldDrag.obj.body:isDestroyed() then
        edgeWeldDrag.obj.body:setPosition(wx + edgeWeldDrag.offsetX, wy + edgeWeldDrag.offsetY)
        edgeWeldDrag.obj.body:setLinearVelocity(0, 0)
        edgeWeldDrag.obj.body:setAngularVelocity(0)
        updateEdgeWeldCandidate()
        return
    end

    if selecting then
        selectEndX, selectEndY = wx, wy
    end

    if draggingGroup then
        for _, obj in ipairs(selectedObjects) do
            local off = dragOffset[obj]
            obj.body:setPosition(wx + off.x, wy + off.y)
            obj.body:setLinearVelocity(0, 0)
            obj.body:setAngularVelocity(0)
        end
    end

    if mouseJoint then
        mouseJoint:setTarget(wx, wy)
    end

    if dragging then
        dragEndX, dragEndY = wx, wy
    end
end

function love.mousereleased(x, y, button)
    if button == 3 then
        panning = false
        return
    end

    if button ~= 1 then return end

    local wx, wy = screenToWorld(x, y)

    if edgeWeldDrag.active then
        endEdgeWeldDrag()
        return
    end

    if draggingGroup then
        for _, obj in ipairs(selectedObjects) do
            if obj.body and not obj.body:isDestroyed() then
                local restoreType = obj.originalType
                if restoreType == nil then
                    restoreType = obj.frozen and "static" or "dynamic"
                end
                obj.body:setType(restoreType)
            end
        end
        draggingGroup = false
    end

    if selecting then
        selecting = false
        selectEndX, selectEndY = wx, wy
        doSelection()
    end

    if mouseJoint then
        mouseJoint:destroy()
        mouseJoint = nil
    end

    if dragging then
        dragging = false
        dragEndX, dragEndY = wx, wy

        local cx = (dragStartX + dragEndX) / 2
        local cy = (dragStartY + dragEndY) / 2

        local w = math.abs(dragEndX - dragStartX)
        local h = math.abs(dragEndY - dragStartY)

        if currentTool == TOOL_BOX then
            if w > 5 and h > 5 then
                pushUndoState()
                spawnBox(cx, cy, w, h)
                logLine(string.format("Spawned box @ %.1f, %.1f size=%.1fx%.1f", cx, cy, w, h))
            end
        elseif currentTool == TOOL_BALL then
            local radius = math.sqrt(w*w + h*h) / 2
            if radius > 5 then
                pushUndoState()
                spawnBall(cx, cy, radius)
                logLine(string.format("Spawned ball @ %.1f, %.1f r=%.1f", cx, cy, radius))
            end
        end
    end

    -- Resize Handles
    if button == 1 then
        resizeState.active = false
    end
end

function love.wheelmoved(dx, dy)
    if dy == 0 then return end

    -- LOAD MENU SCROLL ONLY
    if gameState == STATE_LOAD then
        loadMenuScroll = loadMenuScroll + dy * 20
        return
    end

    if gameState == STATE_SETTINGS then
        settingsScroll = settingsScroll + dy * 28
        return
    end

    controlHints.zoom = true
    local mx, my = love.mouse.getPosition()
    local wx, wy = screenToWorld(mx, my)

    local ctrl  = love.keyboard.isDown("lctrl", "rctrl")
    local shift = love.keyboard.isDown("lshift", "rshift")
    local alt   = love.keyboard.isDown("lalt", "ralt")

    -- =========================
    -- MAGNET TOOL MODIFIERS
    -- =========================
    if currentTool == TOOL_MAGNET then
        local radiusStep   = 15
        local strengthStep = 1000
        local modeStep     = 1

        if ctrl then
            magnetRadius = magnetRadius + dy * radiusStep
            magnetRadius = math.max(20, math.min(600, magnetRadius))
            controlHints.magnetRadius = true
            return
        end

        if shift then
            magnetStrength = magnetStrength + dy * strengthStep
            magnetStrength = math.max(0, math.min(800000, magnetStrength))
            controlHints.magnetStrength = true
            return
        end

        -- ALT scroll = toggle attract / repel
        if alt then
            if dy > 0 then
                magnetMode = "attract"
            else
                magnetMode = "repel"
            end
            return
        end
    end

    -- Properties panel scroll
    local mx, my = love.mouse.getPosition()
    if mx >= PROPS_X and mx <= PROPS_X + PROPS_W and
    my >= PROPS_Y and my <= PROPS_Y + PROPS_H then
        propsScroll = propsScroll + dy * PROPS_SCROLL_SPEED
        return
    end

    -- =========================
    -- WORLD ZOOM (DEFAULT)
    -- =========================
    local oldScale = camScale
    camScale = math.max(ZOOM_MIN,
            math.min(ZOOM_MAX, camScale + dy * ZOOM_SPEED))

    camX = mx - wx * camScale
    camY = my - wy * camScale
end

function love.keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    local shift = love.keyboard.isDown("lshift", "rshift")

    if key == controls.toggle_ui then
        hideUI = not hideUI
        logLine("Toggle UI: " .. tostring(hideUI and "hidden" or "visible"))
        return
    end

    if key == "f1" then
        showTesterHUD = not showTesterHUD
        logLine("Tester HUD: " .. tostring(showTesterHUD and "enabled" or "disabled"))
        return
    end

    if rebindingAction then
        if key == "escape" then
            rebindingAction = nil
            return
        end
        controls[rebindingAction] = key
        saveControls()
        rebindingAction = nil
        return
    end

    if ctrl and key == controls.undo and not shift then
        undoAction()
        return
    end
    if ctrl and (key == controls.redo or (shift and key == controls.undo)) then
        redoAction()
        return
    end

    if activeNumberInput then
        if key == "backspace" then
            numberInputText = numberInputText:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            commitActiveNumberInput()
        elseif key == "escape" then
            activeNumberInput = nil
        end
        return
    end
    if not isNamingWorld and not hexColorActive and gameState ~= STATE_LOAD then
        handleSecretCodeInput(key)
    end

    -- Reset Zoom
    if key == controls.reset_zoom then
        camScale = 1
        camX, camY = 0, 0
    end

    -- Tools
    if key == controls.tool_select then currentTool = TOOL_SELECT controlHints.select = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_move then currentTool = TOOL_MOVE controlHints.move = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_ball then currentTool = TOOL_BALL controlHints.ball = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_box then currentTool = TOOL_BOX controlHints.box = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_drag then currentTool = TOOL_DRAG controlHints.drag = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_freeze then currentTool = TOOL_FREEZE controlHints.Freeze = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_magnet then currentTool = TOOL_MAGNET controlHints.magnet = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_weld then currentTool = TOOL_WELD controlHints.weld = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_spring then currentTool = TOOL_SPRING controlHints.spring = true jointLinkStart = nil cancelEdgeWeldDrag() end
    if key == controls.tool_rope then currentTool = TOOL_ROPE controlHints.rope = true jointLinkStart = nil cancelEdgeWeldDrag() end

    if key == controls.weld_mode_toggle and currentTool == TOOL_WELD then
        weldMode = (weldMode == "point") and "edge" or "point"
    end

    -- Remove Selected Objects
    if key == controls.delete_selected then
        deleteCurrentSelection()
    end

    -- Pauses the time
    if key == controls.pause then
        controlHints.pause = true
        if not paused then
            timeScale = 0.0
            paused = true
        else
            timeScale = 1.0
            paused = false
        end
    end

    -- Increase and decrease drag force
    if key == "n" then
        controlHints.dragForce = true
        dragForce = dragForce + 1000
        if mouseJoint then
            mouseJoint:setMaxForce(dragForce)
        end
    end

    if key == "m" then
        controlHints.dragForce = true
        dragForce = dragForce - 1000
        if mouseJoint then
            mouseJoint:setMaxForce(dragForce)
        end
    end

    -- Toggle Fullscreen
    if key == "f11" then
        if not fullscreen then
            love.window.setFullscreen(true)
            fullscreen = true
        else
            love.window.setFullscreen(false)
            fullscreen = false
        end
    end

    -- Rotate selected objects with Q / E
    if #selectedObjects > 0 then
        if key == "q" then
            controlHints.rotate = true
            qDown = true
        end

        if key == "e" then
            controlHints.rotate = true
            eDown = true
        end
    end

    if key == controls.slowmo then
        controlHints.slowmo = true
        if not inSlowMotion then
            timeScale = slowMotionMod
            inSlowMotion = true
        else
            timeScale = 1.0
            inSlowMotion = false
        end
    end

    -- Save a world
    if key == "f5" then
        if not currentWorldName then
            -- First save ever → ask for name
            isNamingWorld = true
            worldNameInput = ""
        else
            -- Normal save → overwrite
            saveWorld(SAVE_DIR .. currentWorldName)
            autoSaveTimer = 0
        end
    end

    -- Pause the game
    if key == "escape" then
        cancelEdgeWeldDrag()
        gameState = STATE_MENU
        initMenuWorld()
        logLine("State -> menu (escape)")
    end

    -- Saving Name Input
    if isNamingWorld then
        if key == "backspace" then
            worldNameInput = worldNameInput:sub(1, -2)
            return
        end

        if key == "return" or key == "kpenter" then
            if worldNameInput ~= "" then
                currentWorldName = worldNameInput
                saveWorld(SAVE_DIR .. currentWorldName)
                isNamingWorld = false
            end
            return
        end

        if key == "escape" then
            isNamingWorld = false
            return
        end
    end

    if gameState == STATE_LOAD then
        if key == "backspace" then
            loadSearch = loadSearch:sub(1, -2)
            return
        end
    end

    if hexColorActive then
        if key == "backspace" then
            hexColorInput = hexColorInput:sub(1, -2)
        end
    end

    -- Copy and paste
    if ctrl and not shift and key == "c" then
        controlHints.copy = true
        copySelectedObjects()
    end

    if ctrl and not shift and key == "v" then
        controlHints.paste = true
        local sx, sy = love.mouse.getPosition()
        local mx, my = screenToWorld(sx, sy)
        pasteObjectsAt(mx, my)
    end

    -- Copy and paste Properties

    if ctrl and shift and key == "c" then
        controlHints.copy = true
        copySelectedProperties()
    end

    if ctrl and shift and key == "v" then
        controlHints.paste = true
        pastePropertiesToSelected()
    end
end

function love.keyreleased(key)
    if key == "q" then
        rotateSpeed = originalRS
        qDown = false
    end

    if key == "e" then
        rotateSpeed = originalRS
        eDown = false
    end
end

function love.textinput(t)
    if isNamingWorld then
        worldNameInput = worldNameInput .. t
    end

    if gameState == STATE_LOAD then
        loadSearch = loadSearch .. t
    end

    if hexColorActive then
        if #hexColorInput < 7 then
            hexColorInput = hexColorInput .. t
        end
    end

    if activeNumberInput then
        if t:match("[%d%.%-]") then
            numberInputText = numberInputText .. t
        end
    end
end

function beginContact(a, b, coll)
    -- optional
end

function postSolve(a, b, coll, normalImpulse, tangentImpulse)
    if normalImpulse < 500 then return end

    local x1, y1, x2, y2 = coll:getPositions()
    local x, y

    -- Pick a valid contact point
    if x1 and y1 then
        x, y = x1, y1
    elseif x2 and y2 then
        x, y = x2, y2
    else
        return -- no valid position
    end

    local nx, ny = coll:getNormal()

    -- Normalize impulse to a sane 0.5 - 2.0 range
    local power = math.min(normalImpulse / 800, 2)

    spawnImpactParticles(x, y, nx, ny, power)
end

-- =========================
-- Helpers
-- =========================

function spawnBall(x, y, radius)
    local obj = {}
    obj.body = love.physics.newBody(world, x, y, "dynamic")
    obj.shape = love.physics.newCircleShape(radius)
    obj.fixture = love.physics.newFixture(obj.body, obj.shape, 1)
    obj.fixture:setRestitution(0.6)
    obj.fixture:setFriction(0.4)
    obj.originalType = "dynamic"
    obj.fixture:setDensity(1.0)
    obj.body:resetMassData()

    obj.radius = radius
    obj.shapeType = "ball"
    obj.collisionsEnabled = true

    obj.color = {1, 1, 1}
    table.insert(bodies, obj)
end

function spawnBox(x, y, w, h)
    local body = love.physics.newBody(world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(w, h)
    local fixture = love.physics.newFixture(body, shape, 1)

    local obj = {
        body = body,
        shape = shape,
        fixture = fixture,

        width = w,
        height = h,
        shapeType = "box",
        collisionsEnabled = true,
        color = {1, 1, 1}
    }

    table.insert(bodies, obj)
end

function getObjectAtPoint(x, y)
    for i = #bodies, 1, -1 do
        local obj = bodies[i]
        if obj.fixture:testPoint(x, y) then
            return obj
        end
    end
    return nil
end

function getObjectNearPoint(x, y, pad)
    pad = pad or 0
    for i = #bodies, 1, -1 do
        local obj = bodies[i]

        if obj.shapeType == "ball" then
            local bx, by = obj.body:getPosition()
            local r = obj.radius or obj.shape:getRadius()
            local dx = x - bx
            local dy = y - by
            if (dx * dx + dy * dy) <= (r + pad) * (r + pad) then
                return obj
            end
        elseif obj.shapeType == "box" then
            local lx, ly = obj.body:getLocalPoint(x, y)
            local hw = (obj.width or 1) * 0.5
            local hh = (obj.height or 1) * 0.5
            if math.abs(lx) <= hw + pad and math.abs(ly) <= hh + pad then
                return obj
            end
        end
    end
    return nil
end

function isJointTool(tool)
    return tool == TOOL_WELD or tool == TOOL_SPRING or tool == TOOL_ROPE
end

local function closestPointOnSegment(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local ab2 = abx * abx + aby * aby
    if ab2 <= 0.000001 then
        return ax, ay
    end
    local t = (apx * abx + apy * aby) / ab2
    t = math.max(0, math.min(1, t))
    return ax + abx * t, ay + aby * t
end

local function distPointSeg2(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local ab2 = abx * abx + aby * aby
    if ab2 <= 0.000001 then
        return apx * apx + apy * apy
    end

    local t = (apx * abx + apy * aby) / ab2
    t = math.max(0, math.min(1, t))

    local cx = ax + abx * t
    local cy = ay + aby * t
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy
end

local function getBoxCorners(obj)
    local hw = (obj.width or 1) * 0.5
    local hh = (obj.height or 1) * 0.5
    local body = obj.body
    return {
        { body:getWorldPoint(-hw, -hh) },
        { body:getWorldPoint(hw, -hh) },
        { body:getWorldPoint(hw, hh) },
        { body:getWorldPoint(-hw, hh) },
    }
end

local function closestPointOnBoxPerimeter(obj, wx, wy)
    local body = obj.body
    local lx, ly = body:getLocalPoint(wx, wy)
    local hw = (obj.width or 1) * 0.5
    local hh = (obj.height or 1) * 0.5

    local inside = math.abs(lx) <= hw and math.abs(ly) <= hh

    local clx, cly
    if inside then
        local dx = hw - math.abs(lx)
        local dy = hh - math.abs(ly)
        if dx < dy then
            clx = (lx >= 0) and hw or -hw
            cly = ly
        else
            clx = lx
            cly = (ly >= 0) and hh or -hh
        end
    else
        clx = math.max(-hw, math.min(hw, lx))
        cly = math.max(-hh, math.min(hh, ly))
        if math.abs(clx) < hw and math.abs(cly) < hh then
            local dx = hw - math.abs(clx)
            local dy = hh - math.abs(cly)
            if dx < dy then
                clx = (lx >= 0) and hw or -hw
            else
                cly = (ly >= 0) and hh or -hh
            end
        end
    end

    return body:getWorldPoint(clx, cly)
end

local function buildSpringPolyline(ax, ay, bx, by, coils, amp)
    coils = coils or 10
    amp = amp or 6

    local points = {}
    local dx = bx - ax
    local dy = by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return {ax, ay, bx, by}
    end

    local nx = -dy / len
    local ny = dx / len

    table.insert(points, ax)
    table.insert(points, ay)

    for i = 1, coils * 2 - 1 do
        local t = i / (coils * 2)
        local px = ax + dx * t
        local py = ay + dy * t
        local s = (i % 2 == 0) and -1 or 1
        px = px + nx * amp * s
        py = py + ny * amp * s
        table.insert(points, px)
        table.insert(points, py)
    end

    table.insert(points, bx)
    table.insert(points, by)
    return points
end

local function getSpringVisualParams(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    local len = math.sqrt(dx * dx + dy * dy)

    local zoom = camScale or 1
    local clampedZoom = math.max(0.38, math.min(1.0, zoom))
    local screenAmp = 6 * clampedZoom
    local amp = screenAmp / math.max(0.001, zoom)
    amp = math.min(amp, math.max(2, len * 0.18))

    local coils = math.floor(len / 34)
    coils = math.max(6, math.min(14, coils))
    return coils, amp
end

local function buildRopePolyline(ax, ay, bx, by, maxLength, segs)
    segs = segs or 16
    maxLength = maxLength or math.sqrt((bx - ax)^2 + (by - ay)^2)

    local dx = bx - ax
    local dy = by - ay
    local direct = math.sqrt(dx * dx + dy * dy)
    local slack = math.max(0, maxLength - direct)
    local sag = math.min(140, slack * 0.65)
    local mx = (ax + bx) * 0.5
    local my = (ay + by) * 0.5 + sag

    local points = {}
    for i = 0, segs do
        local t = i / segs
        local omt = 1 - t
        local px = omt * omt * ax + 2 * omt * t * mx + t * t * bx
        local py = omt * omt * ay + 2 * omt * t * my + t * t * by
        table.insert(points, px)
        table.insert(points, py)
    end
    return points
end

local function closestSurfacePointToward(obj, tx, ty)
    local body = obj.body
    local cx, cy = body:getPosition()
    local shape = obj.shape

    if shape:typeOf("CircleShape") then
        local r = obj.radius or shape:getRadius()
        local dx = tx - cx
        local dy = ty - cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.001 then
            return cx + r, cy
        end
        return cx + (dx / len) * r, cy + (dy / len) * r
    end

    if obj.shapeType == "box" then
        local lx, ly = body:getLocalPoint(tx, ty)
        local hw = (obj.width or 10) * 0.5
        local hh = (obj.height or 10) * 0.5
        local sx = (math.abs(lx) > 0.0001) and (hw / math.abs(lx)) or math.huge
        local sy = (math.abs(ly) > 0.0001) and (hh / math.abs(ly)) or math.huge
        local s = math.min(sx, sy)
        if s == math.huge then
            return body:getWorldPoint(hw, 0)
        end
        return body:getWorldPoint(lx * s, ly * s)
    end

    return cx, cy
end

local function getClosestEdgePair(objA, objB)
    if not objA or not objB then return nil end
    if not objA.body or not objB.body then return nil end
    if objA.body:isDestroyed() or objB.body:isDestroyed() then return nil end

    local aCircle = objA.shape and objA.shape:typeOf("CircleShape")
    local bCircle = objB.shape and objB.shape:typeOf("CircleShape")
    local aBox = objA.shapeType == "box"
    local bBox = objB.shapeType == "box"

    local ax, ay, bx, by

    if aCircle and bCircle then
        local acx, acy = objA.body:getPosition()
        local bcx, bcy = objB.body:getPosition()
        ax, ay = closestSurfacePointToward(objA, bcx, bcy)
        bx, by = closestSurfacePointToward(objB, acx, acy)
    elseif aBox and bCircle then
        local bcx, bcy = objB.body:getPosition()
        ax, ay = closestPointOnBoxPerimeter(objA, bcx, bcy)
        bx, by = closestSurfacePointToward(objB, ax, ay)
    elseif aCircle and bBox then
        local acx, acy = objA.body:getPosition()
        bx, by = closestPointOnBoxPerimeter(objB, acx, acy)
        ax, ay = closestSurfacePointToward(objA, bx, by)
    elseif aBox and bBox then
        local best = nil
        local bestD2 = math.huge
        local cornersA = getBoxCorners(objA)
        local cornersB = getBoxCorners(objB)

        for _, c in ipairs(cornersA) do
            local px, py = c[1], c[2]
            local qx, qy = closestPointOnBoxPerimeter(objB, px, py)
            local dx, dy = qx - px, qy - py
            local d2 = dx * dx + dy * dy
            if d2 < bestD2 then
                bestD2 = d2
                best = {px, py, qx, qy}
            end
        end

        for _, c in ipairs(cornersB) do
            local qx, qy = c[1], c[2]
            local px, py = closestPointOnBoxPerimeter(objA, qx, qy)
            local dx, dy = qx - px, qy - py
            local d2 = dx * dx + dy * dy
            if d2 < bestD2 then
                bestD2 = d2
                best = {px, py, qx, qy}
            end
        end

        if best then
            ax, ay, bx, by = best[1], best[2], best[3], best[4]
        end
    else
        local acx, acy = objA.body:getPosition()
        local bcx, bcy = objB.body:getPosition()
        ax, ay = closestSurfacePointToward(objA, bcx, bcy)
        bx, by = closestSurfacePointToward(objB, acx, acy)
    end

    if not ax or not bx then return nil end
    local dx, dy = bx - ax, by - ay
    local dist = math.sqrt(dx * dx + dy * dy)
    return ax, ay, bx, by, dist
end

function updateEdgeWeldCandidate()
    if not edgeWeldDrag.active or not edgeWeldDrag.obj then
        edgeWeldDrag.candidate = nil
        edgeWeldDrag.dist = math.huge
        return
    end

    local bestObj = nil
    local best = nil
    local bestDist = math.huge

    for _, other in ipairs(bodies) do
        if other ~= edgeWeldDrag.obj and other.body and not other.body:isDestroyed() then
            local ax, ay, bx, by, dist = getClosestEdgePair(edgeWeldDrag.obj, other)
            if ax and dist < bestDist then
                bestDist = dist
                bestObj = other
                best = {ax=ax, ay=ay, bx=bx, by=by}
            end
        end
    end

    edgeWeldDrag.candidate = bestObj
    edgeWeldDrag.dist = bestDist
    if best then
        edgeWeldDrag.ax, edgeWeldDrag.ay = best.ax, best.ay
        edgeWeldDrag.bx, edgeWeldDrag.by = best.bx, best.by
    end
end

function beginEdgeWeldDrag(obj, wx, wy)
    if not obj then return end
    pushUndoState()
    edgeWeldDrag.active = true
    edgeWeldDrag.obj = obj
    edgeWeldDrag.originalType = obj.body:getType()
    edgeWeldDrag.offsetX = obj.body:getX() - wx
    edgeWeldDrag.offsetY = obj.body:getY() - wy
    edgeWeldDrag.candidate = nil
    edgeWeldDrag.dist = math.huge
    obj.body:setType("kinematic")
    obj.body:setLinearVelocity(0, 0)
    obj.body:setAngularVelocity(0)
    updateEdgeWeldCandidate()
end

function endEdgeWeldDrag()
    if not edgeWeldDrag.active then return end

    local dragged = edgeWeldDrag.obj
    local candidate = edgeWeldDrag.candidate
    local dist = edgeWeldDrag.dist or math.huge

    if dragged and candidate and dist <= EDGE_WELD_SNAP_DIST then
        -- Snap dragged object flush to the candidate edge before welding.
        local snapDX = edgeWeldDrag.bx - edgeWeldDrag.ax
        local snapDY = edgeWeldDrag.by - edgeWeldDrag.ay
        dragged.body:setPosition(dragged.body:getX() + snapDX, dragged.body:getY() + snapDY)
        dragged.body:setLinearVelocity(0, 0)
        dragged.body:setAngularVelocity(0)
        updateEdgeWeldCandidate()

        local created = createJointLink(
            "weld",
            dragged,
            candidate,
            edgeWeldDrag.ax,
            edgeWeldDrag.ay,
            edgeWeldDrag.bx,
            edgeWeldDrag.by,
            {
                weldMode = "edge",
                weldRigidity = weldRigidity,
                edgeAx = edgeWeldDrag.ax,
                edgeAy = edgeWeldDrag.ay,
                edgeBx = edgeWeldDrag.bx,
                edgeBy = edgeWeldDrag.by,
            }
        )
        if created then
            selectedJoint = created
        end
    end

    if dragged and dragged.body and not dragged.body:isDestroyed() then
        dragged.body:setType(edgeWeldDrag.originalType or "dynamic")
    end

    edgeWeldDrag.active = false
    edgeWeldDrag.obj = nil
    edgeWeldDrag.candidate = nil
    edgeWeldDrag.dist = math.huge
end

function cancelEdgeWeldDrag()
    if not edgeWeldDrag.active then return end

    local dragged = edgeWeldDrag.obj
    if dragged and dragged.body and not dragged.body:isDestroyed() then
        dragged.body:setType(edgeWeldDrag.originalType or "dynamic")
    end

    edgeWeldDrag.active = false
    edgeWeldDrag.obj = nil
    edgeWeldDrag.candidate = nil
    edgeWeldDrag.dist = math.huge
end

function getJointAtPoint(x, y, maxDist)
    maxDist = maxDist or (14 / camScale)
    local maxDist2 = maxDist * maxDist

    for i = #joints, 1, -1 do
        local link = joints[i]
        if link.joint and not link.joint:isDestroyed() then
            local ax, ay, bx, by = link.joint:getAnchors()
            local hit = false

            if link.kind == "spring" then
                local pts = buildSpringPolyline(ax, ay, bx, by, 10, 6 / camScale)
                for p = 1, #pts - 2, 2 do
                    if distPointSeg2(x, y, pts[p], pts[p+1], pts[p+2], pts[p+3]) <= maxDist2 then
                        hit = true
                        break
                    end
                end
            elseif link.kind == "rope" then
                local pts = buildRopePolyline(ax, ay, bx, by, link.maxLength, 16)
                for p = 1, #pts - 2, 2 do
                    if distPointSeg2(x, y, pts[p], pts[p+1], pts[p+2], pts[p+3]) <= maxDist2 then
                        hit = true
                        break
                    end
                end
            else
                hit = distPointSeg2(x, y, ax, ay, bx, by) <= maxDist2
            end

            if hit then
                return link
            end
        end
    end

    return nil
end

function selectJoint(link)
    selectedJoint = link
    clearAllSelection()
    resizeState.active = false
end

function pruneJoints()
    for i = #joints, 1, -1 do
        local link = joints[i]
        local bad = (not link.joint)
            or link.joint:isDestroyed()
            or (link.extraJoint and link.extraJoint:isDestroyed())
            or (not link.objA) or (not link.objB)
            or (not link.objA.body) or (not link.objB.body)
            or link.objA.body:isDestroyed()
            or link.objB.body:isDestroyed()

        if bad then
            if selectedJoint == link then
                selectedJoint = nil
            end
            table.remove(joints, i)
        end
    end
end

local function normalizeWeldRigidity(value)
    return (value == "hard") and "hard" or "soft"
end

local function computeAuxWeldAnchor(objA, objB, ax, ay)
    local acx, acy = objA.body:getPosition()
    local bcx, bcy = objB.body:getPosition()
    local dx, dy = bcx - acx, bcy - acy
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        dx, dy, len = 1, 0, 1
    end
    dx, dy = dx / len, dy / len
    local px, py = -dy, dx
    local offset = math.max(8, math.min(36, len * 0.12))
    return ax + px * offset, ay + py * offset
end

function createJointLink(kind, objA, objB, ax, ay, bx, by, opts)
    if not objA or not objB or objA == objB then return nil end
    if not objA.body or not objB.body then return nil end
    if objA.body:isDestroyed() or objB.body:isDestroyed() then return nil end

    opts = opts or {}
    local joint
    local extraJoint = nil

    local selectedWeldMode = opts.weldMode or weldMode
    local selectedWeldRigidity = normalizeWeldRigidity(opts.weldRigidity or weldRigidity)

    if kind == "weld" then
        if selectedWeldMode == "edge" then
            local pax, pay, pbx, pby
            if opts.edgeAx and opts.edgeAy and opts.edgeBx and opts.edgeBy then
                pax, pay = opts.edgeAx, opts.edgeAy
                pbx, pby = opts.edgeBx, opts.edgeBy
            else
                local acx, acy = objA.body:getPosition()
                local bcx, bcy = objB.body:getPosition()
                pax, pay = closestSurfacePointToward(objA, bcx, bcy)
                pbx, pby = closestSurfacePointToward(objB, acx, acy)
            end
            ax = (pax + pbx) * 0.5
            ay = (pay + pby) * 0.5
            bx, by = ax, ay
        end
        joint = love.physics.newWeldJoint(objA.body, objB.body, ax, ay, true)
        if selectedWeldRigidity == "hard" then
            local hx, hy = computeAuxWeldAnchor(objA, objB, ax, ay)
            extraJoint = love.physics.newWeldJoint(objA.body, objB.body, hx, hy, true)
        end
        if not historySuspended and not opts.silent then
            spawnWeldParticles(ax, ay, selectedWeldRigidity == "hard" and 1.15 or 0.9)
        end
    elseif kind == "spring" then
        joint = love.physics.newDistanceJoint(objA.body, objB.body, ax, ay, bx, by, true)
        local freq = opts.frequency or springFrequency
        local damp = opts.damping or springDamping
        joint:setFrequency(freq)
        joint:setDampingRatio(damp)
    elseif kind == "rope" then
        local maxLength = opts.maxLength or math.sqrt((bx - ax)^2 + (by - ay)^2)
        maxLength = math.max(10, maxLength)
        joint = love.physics.newRopeJoint(objA.body, objB.body, ax, ay, bx, by, maxLength, true)
    else
        return nil
    end

    local link = {
        kind = kind,
        joint = joint,
        objA = objA,
        objB = objB,
        weldMode = selectedWeldMode,
        weldRigidity = selectedWeldRigidity,
        extraJoint = extraJoint,
        frequency = opts.frequency or springFrequency,
        damping = opts.damping or springDamping,
        maxLength = opts.maxLength,
    }
    if kind == "rope" then
        link.maxLength = opts.maxLength or math.sqrt((bx - ax)^2 + (by - ay)^2)
    end

    table.insert(joints, link)
    return link
end

function handleJointToolClick(wx, wy)
    if not isJointTool(currentTool) then return false end

    local obj = getObjectAtPoint(wx, wy)
    if not obj then
        jointLinkStart = nil
        return true
    end

    if not jointLinkStart then
        selectedJoint = nil
        clearAllSelection()
        jointLinkStart = { obj = obj, ax = wx, ay = wy }
        return true
    end

    if jointLinkStart.obj == obj then
        -- Re-click same object updates the anchor.
        jointLinkStart.ax = wx
        jointLinkStart.ay = wy
        return true
    end

    local kind = "weld"
    if currentTool == TOOL_SPRING then kind = "spring" end
    if currentTool == TOOL_ROPE then kind = "rope" end

    local opts = nil
    if kind == "weld" then
        opts = { weldMode = weldMode, weldRigidity = weldRigidity }
    elseif kind == "spring" then
        opts = { frequency = springFrequency, damping = springDamping }
    end

    pushUndoState()
    local created = createJointLink(kind, jointLinkStart.obj, obj, jointLinkStart.ax, jointLinkStart.ay, wx, wy, opts)
    if created then
        selectedJoint = created
    end
    jointLinkStart = nil
    return true
end

function doSelection()
    selectedJoint = nil
    local ctrl = love.keyboard.isDown("lctrl", "rctrl")

    local minX = math.min(selectStartX, selectEndX)
    local maxX = math.max(selectStartX, selectEndX)
    local minY = math.min(selectStartY, selectEndY)
    local maxY = math.max(selectStartY, selectEndY)

    for _, obj in ipairs(bodies) do
        local bx, by = obj.body:getPosition()

        if bx >= minX and bx <= maxX and
           by >= minY and by <= maxY then

            if not isSelected(obj) then
                obj.selected = true
                table.insert(selectedObjects, obj)
            end
        end
    end
end


function isSelected(obj)
    for i, o in ipairs(selectedObjects) do
        if o == obj then
            return true, i
        end
    end
    return false, nil
end

function clearAllSelection()
    for _, obj in ipairs(bodies) do
        obj.selected = false
    end
    selectedObjects = {}
end

function selectObject(obj, additive)
    selectedJoint = nil
    local isSel, index = isSelected(obj)

    if additive then
        -- TOGGLE
        if isSel then
            obj.selected = false
            table.remove(selectedObjects, index)
        else
            obj.selected = true
            table.insert(selectedObjects, obj)
        end
    else
        -- REPLACE
        clearAllSelection()
        obj.selected = true
        selectedObjects = { obj }
    end
end

function resizeObject(obj, newW, newH)
    local body = obj.body

    local x, y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local av = body:getAngularVelocity()
    local restitution = obj.fixture:getRestitution()
    local friction = obj.fixture:getFriction()
    local density = obj.fixture:getDensity()
    local isSensor = obj.fixture:isSensor()

    -- destroy old fixture
    obj.fixture:destroy()

    -- rebuild shape
    if obj.shapeType == "box" then
        obj.width = newW
        obj.height = newH
        obj.shape = love.physics.newRectangleShape(newW, newH)

    elseif obj.shapeType == "ball" then
        obj.radius = newW -- use width as diameter/radius input
        obj.shape = love.physics.newCircleShape(newW)
    end

    obj.fixture = love.physics.newFixture(body, obj.shape, density)

    -- restore physics settings
    obj.fixture:setRestitution(restitution)
    obj.fixture:setFriction(friction)
    obj.fixture:setDensity(density)
    obj.fixture:setSensor(isSensor)
    obj.collisionsEnabled = not isSensor

    body:resetMassData()
    body:setPosition(x,y)
    body:setLinearVelocity(vx,vy)
    body:setAngularVelocity(av)
end

-- =========================
-- UI Theme + SFX
-- =========================

UI_ACCENT = {0.78, 0.45, 1.0}
UI_ACCENT_SOFT = {0.58, 0.32, 0.86}
UI_ACCENT_LIGHT = {0.93, 0.85, 1.0}

uiSfx = {}

local function makeToneSource(freq, duration, amplitude)
    local sampleRate = 44100
    local samples = math.max(1, math.floor(sampleRate * duration))
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local env = 1.0 - (i / samples)
        local value = math.sin(2 * math.pi * freq * t) * amplitude * env
        data:setSample(i, value)
    end
    return love.audio.newSource(data, "static")
end

function initUISfx()
    uiSfx.click = makeToneSource(760, 0.04, 0.5)
    uiSfx.tick = makeToneSource(520, 0.03, 0.4)
end

function playUISfx(kind, pitch, gain)
    local src = uiSfx[kind]
    if not src then return end
    local s = src:clone()
    s:setPitch(pitch or 1.0)
    s:setVolume(math.min(1.0, (gain or 1.0) * 0.8))
    s:play()
end

BUTTON_THEME = {
    normal = {
        bg = {0.11, 0.14, 0.19},
        hover = {0.18, 0.24, 0.32},
        border = {UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3]},
        text = {0.94, 0.97, 1.0}
    },
    active = {
        bg = {0.29, 0.16, 0.44},
        hover = {0.39, 0.21, 0.58},
        border = {UI_ACCENT_LIGHT[1], UI_ACCENT_LIGHT[2], UI_ACCENT_LIGHT[3]},
        text = {1.0, 1.0, 1.0}
    },
    danger = {
        bg = {0.45, 0.12, 0.12},
        hover = {0.72, 0.2, 0.2},
        border = {1.0, 0.62, 0.62},
        text = {1.0, 0.95, 0.95}
    },
    disabled = {
        bg = {0.12, 0.12, 0.13},
        hover = {0.12, 0.12, 0.13},
        border = {0.3, 0.3, 0.33},
        text = {0.55, 0.56, 0.6}
    }
}

local function mixf(a, b, t)
    return a + (b - a) * t
end

function drawButton(text, x, y, w, h, onClick, style)
    style = style or {}

    local theme = BUTTON_THEME[style.theme or "normal"]

    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x and mx <= x + w and
                    my >= y and my <= y + h

    local isDisabled = style.disabled
    local isActive   = style.active

    local bg     = theme.bg
    local hover  = theme.hover
    local border = theme.border
    local textCol= theme.text

    if isActive then
        bg    = BUTTON_THEME.active.bg
        hover = BUTTON_THEME.active.hover
    end

    if isDisabled then
        bg     = BUTTON_THEME.disabled.bg
        hover  = BUTTON_THEME.disabled.hover
        border = BUTTON_THEME.disabled.border
        textCol= BUTTON_THEME.disabled.text
    end

    -- Button ID for animation
    local id = tostring(x) .. ":" .. tostring(y) .. ":" .. text
    buttonAnim[id] = buttonAnim[id] or 0

    -- Smooth hover animation (lerp)
    local target = hovered and 1 or 0
    buttonAnim[id] = buttonAnim[id] + (target - buttonAnim[id]) * 0.2
    local a = buttonAnim[id] -- 0..1
    local pressed = (hovered and love.mouse.isDown(1) and not isDisabled) and 1 or 0

    -- Slight grow on hover + tiny press offset
    local grow = 1.5 * a
    local bx = x - grow
    local by = y - grow + pressed
    local bw = w + grow*2
    local bh = h + grow*2

    table.insert(uiButtons, {
        x=bx,y=by,w=bw,h=bh,
        onClick = (isDisabled and nil or onClick)
    })

    -- Shadow
    love.graphics.setColor(0, 0, 0, isDisabled and 0.18 or 0.35)
    love.graphics.rectangle("fill", bx + 1, by + 2, bw, bh, 6, 6)

    -- Glow (behind button)
    if hovered and not isDisabled then
        love.graphics.setColor(hover[1], hover[2], hover[3], 0.22 * a)
        love.graphics.rectangle("fill", bx - 2, by - 2, bw + 4, bh + 4, 7, 7)
    end

    -- Background
    local col = {
        mixf(bg[1], hover[1], a),
        mixf(bg[2], hover[2], a),
        mixf(bg[3], hover[3], a)
    }

    love.graphics.setColor(col[1], col[2], col[3], 0.98)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.04 + 0.08 * a)
    love.graphics.rectangle("fill", bx + 1, by + 1, bw - 2, math.max(2, bh * 0.35), 6, 6)

    -- Border
    local borderA = isDisabled and 0.35 or (0.45 + 0.4 * a)
    love.graphics.setColor(border[1], border[2], border[3], borderA)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)

    if isActive and not isDisabled then
        love.graphics.setColor(0.72, 0.96, 1.0, 0.9)
        love.graphics.rectangle("fill", bx + 2, by + bh - 3, bw - 4, 2, 2, 2)
    end

    -- Text
    love.graphics.setColor(textCol)
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local textH = font:getHeight()

    local textX = math.floor(bx + (bw - textW) / 2)
    local textY = math.floor(by + (bh - textH) / 2)

    love.graphics.print(text, textX, textY)
end

function drawPanel(x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h, 8, 8)
    love.graphics.setColor(0.08, 0.1, 0.14, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.04)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, math.max(8, h * 0.22), 8, 8)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.35)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
end

function drawSectionHeader(text, x, y, w)
    love.graphics.setColor(0.95, 0.98, 1.0, 0.96)
    love.graphics.print(text, x, y)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.45)
    love.graphics.rectangle("fill", x, y + 17, 20, 2, 2, 2)
    love.graphics.setColor(1,1,1,0.12)
    love.graphics.line(x, y + 18, x + w, y + 18)
end

function drawDividerSoft(x, y, w)
    love.graphics.setColor(1,1,1,0.07)
    love.graphics.line(x, y, x + w, y)
    love.graphics.setColor(0,0,0,0.18)
    love.graphics.line(x, y + 1, x + w, y + 1)
end

function getPrimarySelected()
    if #selectedObjects > 0 then
        return selectedObjects[1]
    end
    return nil
end

function rotateSelectedGroupForced(deltaAngle)
    if #selectedObjects == 0 or deltaAngle == 0 then return end

    local cx, cy = 0, 0
    for _, obj in ipairs(selectedObjects) do
        local bx, by = obj.body:getPosition()
        cx = cx + bx
        cy = cy + by
    end
    cx = cx / #selectedObjects
    cy = cy / #selectedObjects

    local c = math.cos(deltaAngle)
    local s = math.sin(deltaAngle)

    for _, obj in ipairs(selectedObjects) do
        local body = obj.body
        local bx, by = body:getPosition()
        local rx = bx - cx
        local ry = by - cy
        local nx = cx + rx * c - ry * s
        local ny = cy + rx * s + ry * c

        body:setPosition(nx, ny)
        body:setAngle(body:getAngle() + deltaAngle)
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    end
end

function drawPropertyRow(label, value, min, max, x, y, w)
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x and mx <= x + w and
                    my >= y and my <= y + PROPERTY_ROW_H

    -- Background
    if hovered then
        love.graphics.setColor(0.18, 0.18, 0.22)
    else
        love.graphics.setColor(0.12, 0.12, 0.16)
    end
    love.graphics.rectangle("fill", x, y, w, PROPERTY_ROW_H)

    -- Value bar
    local t = 0
    if max > min then
        t = (value - min) / (max - min)
        t = math.max(0, math.min(1, t))
    end

    love.graphics.setColor(0.25, 0.45, 0.9, 0.6)
    love.graphics.rectangle("fill", x, y + PROPERTY_ROW_H - 6, w * t, 6)

    -- Text
    love.graphics.setColor(1,1,1)
    love.graphics.print(label, x + 8, y + 6)

    local valueText = string.format("%.2f", value)
    local tw = love.graphics.getFont():getWidth(valueText)
    love.graphics.print(valueText, x + w - tw - 8, y + 6)
end

function isMultiSelected()
    return #selectedObjects > 1
end

function commitActiveNumberInput()
    if not activeNumberInput then return false end

    local binding = numberInputBindings and numberInputBindings[activeNumberInput]
    if not binding then
        activeNumberInput = nil
        return false
    end

    local num = tonumber(numberInputText)
    if num then
        num = math.max(binding.min, math.min(binding.max, num))
        binding.onChange(num)
    end
    activeNumberInput = nil
    return true
end

function drawSliderRow(label, x, y, w, value, min, max, onChange, id)
    local mx, my = love.mouse.getPosition()
    numberInputBindings[id] = { min = min, max = max, onChange = onChange }

    local rowH = 26
    local sliderY = y + 14
    local sliderH = 6
    local sliderX = x
    local sliderW = w - 80
    local hoveredSlider = mx >= sliderX and mx <= sliderX + sliderW and
        my >= sliderY - 6 and my <= sliderY + sliderH + 6

    -- Slider background
    love.graphics.setColor(0.12, 0.15, 0.2, hoveredSlider and 0.95 or 0.85)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderW, sliderH, 3,3)
    love.graphics.setColor(1,1,1,0.08)
    love.graphics.rectangle("line", sliderX, sliderY, sliderW, sliderH, 3,3)

    -- Slider fill
    local t = (value - min) / (max - min)
    t = math.max(0, math.min(1, t))

    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.95)
    love.graphics.rectangle("fill", sliderX, sliderY, sliderW * t, sliderH, 3,3)
    local knobX = sliderX + sliderW * t
    love.graphics.setColor(0.92, 0.98, 1.0, 0.95)
    love.graphics.rectangle("fill", knobX - 4, sliderY - 3, 8, sliderH + 6, 3, 3)

    -- Dragging
    if love.mouse.isDown(1) and
       hoveredSlider and
       activeNumberInput == nil then

        local nt = (mx - sliderX) / sliderW
        local nv = min + nt * (max - min)
        onChange(nv)
    end

    -- Label
    love.graphics.setColor(1,1,1)
    love.graphics.print(label, x, y - 2)

    -- ===== VALUE BOX (CLICK TO TYPE) =====
    local valueBoxX = x + w - 70
    local valueBoxW = 70

    local hoveredValue =
        mx >= valueBoxX and mx <= valueBoxX + valueBoxW and
        my >= y - 2 and my <= y + rowH

    local isActive = activeNumberInput == id

    -- Box
    if isActive then
        love.graphics.setColor(0.18, 0.33, 0.58)
    elseif hoveredValue then
        love.graphics.setColor(0.16, 0.2, 0.28)
    else
        love.graphics.setColor(0.1, 0.12, 0.16)
    end

    love.graphics.rectangle("fill", valueBoxX, y - 2, valueBoxW, rowH, 4,4)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], isActive and 0.75 or 0.3)
    love.graphics.rectangle("line", valueBoxX, y - 2, valueBoxW, rowH, 4,4)

    -- Click to activate
    if hoveredValue and love.mouse.isDown(1) and not isActive then
        activeNumberInput = id
        numberInputText = tostring(math.floor(value * 100) / 100)
    end

    -- Text
    love.graphics.setColor(1,1,1)
    local displayText = isActive and numberInputText or string.format("%.2f", value)
    love.graphics.printf(displayText, valueBoxX, y + 3, valueBoxW, "center")

end

function drawPropertiesPanel()
    local x = PROPS_X
    local y = PROPS_Y
    local w = PROPS_W
    local h = PROPS_H

    drawPanel(x, y, w, h)

    -- Title
    love.graphics.setColor(0.95, 0.98, 1.0)
    love.graphics.print("Properties", x+12, y+8)

    -- Subtle title underline
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.35)
    love.graphics.line(x+10, y+26, x+w-10, y+26)
    love.graphics.setColor(1,1,1,1)


    -- Out of Limits Toggle (NOT SCROLLING)
    drawToggleButton("Out of Limits", x+10, y-30, 180, 22, outLimits, function(v)
        outLimits = v
    end)

    if selectedJoint and (not selectedJoint.joint or selectedJoint.joint:isDestroyed()) then
        selectedJoint = nil
    end

    if selectedJoint then
        local clipY = y + 30
        local clipH = h - 40

        love.graphics.setScissor(x, clipY, w, clipH)
        local cy = clipY + 10 + propsScroll

        local function drawSection(title)
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.print(title, x+10, cy)
            love.graphics.setColor(1,1,1,0.15)
            love.graphics.line(x+10, cy+18, x+w-10, cy+18)
            love.graphics.setColor(1,1,1,1)
            cy = cy + 26
        end

        local function drawDivider()
            love.graphics.setColor(1,1,1,0.08)
            love.graphics.rectangle("fill", x+10, cy, w-20, 1)
            love.graphics.setColor(1,1,1,1)
            cy = cy + 12
        end

        drawSection("Joint")
        love.graphics.setColor(0.8, 0.9, 1.0)
        love.graphics.print("Type: " .. selectedJoint.kind, x+15, cy)
        cy = cy + 20
        if selectedJoint.kind == "weld" then
            love.graphics.print("Mode: " .. (selectedJoint.weldMode or "point"), x+15, cy)
            cy = cy + 20
            love.graphics.print("Rigidity: " .. (selectedJoint.weldRigidity or "soft"), x+15, cy)
            cy = cy + 20
        end

        drawDivider()
        drawSection("Settings")

        if selectedJoint.kind == "spring" then
            drawSliderRow("Frequency", x+15, cy, w-30,
                selectedJoint.frequency or springFrequency, 0.1, 20,
                function(v)
                    selectedJoint.frequency = v
                    if selectedJoint.joint and not selectedJoint.joint:isDestroyed() then
                        selectedJoint.joint:setFrequency(v)
                    end
                end, "joint_frequency")
            cy = cy + 34

            drawSliderRow("Damping", x+15, cy, w-30,
                selectedJoint.damping or springDamping, 0, 1,
                function(v)
                    selectedJoint.damping = v
                    if selectedJoint.joint and not selectedJoint.joint:isDestroyed() then
                        selectedJoint.joint:setDampingRatio(v)
                    end
                end, "joint_damping")
            cy = cy + 34
        elseif selectedJoint.kind == "rope" then
            local len = selectedJoint.maxLength
            if (not len) and selectedJoint.joint and not selectedJoint.joint:isDestroyed() then
                local ax, ay, bx, by = selectedJoint.joint:getAnchors()
                len = math.sqrt((bx - ax)^2 + (by - ay)^2)
                selectedJoint.maxLength = len
            end

            drawSliderRow("Max Length", x+15, cy, w-30,
                len or 100, 10, 2000,
                function(v)
                    selectedJoint.maxLength = v
                    if selectedJoint.joint and not selectedJoint.joint:isDestroyed() then
                        if selectedJoint.joint.setMaxLength then
                            selectedJoint.joint:setMaxLength(v)
                        elseif selectedJoint.objA and selectedJoint.objB then
                            local ax, ay, bx, by = selectedJoint.joint:getAnchors()
                            selectedJoint.joint:destroy()
                            selectedJoint.joint = love.physics.newRopeJoint(
                                selectedJoint.objA.body,
                                selectedJoint.objB.body,
                                ax, ay, bx, by, v, true
                            )
                        end
                    end
                end, "joint_maxlen")
            cy = cy + 34
        else
            love.graphics.setColor(1,1,1,0.7)
            love.graphics.print("Weld has no runtime tuning.", x+15, cy)
            love.graphics.setColor(1,1,1,1)
            cy = cy + 24
        end

        cy = cy + 8
        drawDivider()
        drawSection("Danger Zone")

        drawButton("Delete Joint", x+15, cy, w-30, 28, function()
            deleteJoint(selectedJoint)
        end, { theme = "danger" })
        cy = cy + 40

        love.graphics.setScissor()

        local contentHeight = cy - (clipY + propsScroll)
        local maxScroll = math.max(0, contentHeight - clipH)
        propsScroll = math.min(0, math.max(-maxScroll, propsScroll))

        if contentHeight > clipH then
            local barH = clipH * (clipH / contentHeight)
            local t = -propsScroll / maxScroll
            local barY = clipY + t * (clipH - barH)
            love.graphics.setColor(1,1,1,0.2)
            love.graphics.rectangle("fill", x+w-6, barY, 4, barH)
            love.graphics.setColor(1,1,1,1)
        end
        return
    end

    if #selectedObjects == 0 then
        love.graphics.setColor(1,1,1,0.7)
        love.graphics.print("No selection", x+10, y+40)
        love.graphics.setColor(1,1,1,1)
        return
    end

    -- =====================
    -- SCROLL CLIP AREA
    -- =====================
    local clipY = y + 30
    local clipH = h - 40

    love.graphics.setScissor(x, clipY, w, clipH)

    local cy = clipY + 10 + propsScroll

    -- Helpers
    local function drawSection(title)
        love.graphics.setColor(1,1,1,0.9)
        love.graphics.print(title, x+10, cy)
        love.graphics.setColor(1,1,1,0.15)
        love.graphics.line(x+10, cy+18, x+w-10, cy+18)
        love.graphics.setColor(1,1,1,1)
        cy = cy + 26
    end

    local function drawDivider()
        love.graphics.setColor(1,1,1,0.08)
        love.graphics.rectangle("fill", x+10, cy, w-20, 1)
        love.graphics.setColor(1,1,1,1)
        cy = cy + 12
    end

    local function forAllSelected(fn)
        for _, obj in ipairs(selectedObjects) do
            fn(obj)
        end
    end

    -- MULTI INFO
    if #selectedObjects > 1 then
        love.graphics.setColor(1,1,1,0.75)
        love.graphics.print("Selected: "..#selectedObjects, x+10, cy)
        love.graphics.setColor(1,1,1,1)
        cy = cy + 20
    end

    -- =====================
    -- STATE
    -- =====================
    drawSection("State")

    local anyFrozen = selectedObjects[1].frozen == true

    drawToggleButton("Frozen", x+15, cy, w-30, 22, anyFrozen, function(v)
        forAllSelected(function(obj)
            obj.frozen = v
            if v then
                obj.body:setType("static")
                obj.originalType = "static"
                obj.body:setLinearVelocity(0,0)
                obj.body:setAngularVelocity(0)
            else
                obj.body:setType("dynamic")
                obj.originalType = "dynamic"
            end
        end)
    end)

    cy = cy + 32

    local collisionsEnabled = selectedObjects[1].collisionsEnabled ~= false
    drawToggleButton("Collisions", x+15, cy, w-30, 22, collisionsEnabled, function(v)
        forAllSelected(function(obj)
            obj.collisionsEnabled = v
            if obj.fixture and not obj.fixture:isDestroyed() then
                obj.fixture:setSensor(not v)
            end
        end)
    end)

    cy = cy + 32
    drawDivider()

    -- =====================
    -- PHYSICS
    -- =====================
    drawSection("Physics")

    local function getPrecision(step)
        if love.keyboard.isDown("lshift", "rshift") then
            return 0.01
        elseif love.keyboard.isDown("lctrl", "rctrl") then
            return step * 10
        else
            return step
        end
    end

    local function drawStepper(label, getter, setter, step, minVal, maxVal)
        -- Row background
        love.graphics.setColor(0.11, 0.11, 0.15)
        love.graphics.rectangle("fill", x+10, cy-2, w-20, 26, 4, 4)
        love.graphics.setColor(1,1,1)

        -- LIVE VALUE (from first selected)
        local liveValue = getter(selectedObjects[1])
        local valueText = string.format("%.2f", liveValue)

        -- Label
        love.graphics.setColor(1,1,1)
        love.graphics.print(label, x+15, cy)

        -- Live number (right side)
        local vw = love.graphics.getFont():getWidth(valueText)
        love.graphics.setColor(0.8, 0.9, 1)
        love.graphics.print(valueText, x+w-100-vw, cy)

        love.graphics.setColor(1,1,1)

        -- Minus
        drawButton("-", x+w-90, cy, 22, 22, function()
            local precision = getPrecision(step)

            forAllSelected(function(obj)
                local v = getter(obj) - precision
                if minVal then v = math.max(minVal, v) end
                setter(obj, v)
            end)
        end)


        -- Plus
        drawButton("+", x+w-60, cy, 22, 22, function()
            local precision = getPrecision(step)

            forAllSelected(function(obj)
                local v = getter(obj) + precision
                if not outLimits and maxVal then v = math.min(maxVal, v) end
                setter(obj, v)
            end)
        end)

        cy = cy + 28
    end

    drawStepper("Bounce",
        function(o) return o.fixture:getRestitution() end,
        function(o,v) o.fixture:setRestitution(v) end,
        0.1, 0, 1)

    drawStepper("Friction",
        function(o) return o.fixture:getFriction() end,
        function(o,v) o.fixture:setFriction(v) end,
        0.1, 0, 1)

    drawStepper("Density",
        function(o) return o.fixture:getDensity() end,
        function(o,v) setObjectDensity(o,v) end,
        0.1, 0.1, nil)

    cy = cy + 10
    drawDivider()

    -- =====================
    -- COLOR
    -- =====================
    drawSection("Color")

    local ref = selectedObjects[1]

    if not hexColorActive then
        hexColorInput = rgb01ToHex(ref.color[1], ref.color[2], ref.color[3])
    end

    love.graphics.setColor(ref.color)
    love.graphics.rectangle("fill", x+15, cy, 26, 26)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", x+15, cy, 26, 26)

    cy = cy + 36

    local function adjustColor(i, delta)
        forAllSelected(function(obj)
            obj.color[i] = math.max(0, math.min(1, obj.color[i] + delta))
        end)
    end

    local labels = {"R","G","B"}
    for i=1,3 do
        love.graphics.print(labels[i], x+15, cy)
        love.graphics.print(fmtColor(ref.color[i]), x+50, cy)

        drawButton("-", x+w-120, cy, 22, 22, function()
            adjustColor(i, -0.05)
        end)

        drawButton("+", x+w-90, cy, 22, 22, function()
            adjustColor(i, 0.05)
        end)

        cy = cy + 28
    end

    cy = cy + 10
    drawDivider()
    cy = cy + 6

    -- =====================
    -- HEX COLOR INPUT
    -- =====================
    love.graphics.setColor(1,1,1,0.8)
    love.graphics.print("Hex Color", x+15, cy)

    local boxX = x + 15
    local boxY = cy + 20
    local boxW = w - 30
    local boxH = 26
    hexBoxX = boxX
    hexBoxY = boxY
    hexBoxW = boxW
    hexBoxH = boxH


    local mx, my = love.mouse.getPosition()
    local hovered = mx >= boxX and mx <= boxX + boxW and
                    my >= boxY and my <= boxY + boxH

    -- Box bg
    if hovered or hexColorActive then
        love.graphics.setColor(0.18,0.18,0.25)
    else
        love.graphics.setColor(0.12,0.12,0.16)
    end
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4, 4)

    -- Border
    love.graphics.setColor(1,1,1,0.15)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4, 4)

    -- Text
    love.graphics.setColor(1,1,1)
    local displayText = hexColorInput
    if hexColorActive then
        displayText = displayText .. "_"
    end
    love.graphics.print(displayText, boxX + 8, boxY + 6)

    -- Apply button
    drawButton("Apply", boxX + boxW - 70, boxY, 60, boxH, function()
        local r,g,b = hexToRGB01(hexColorInput)
        if r then
            for _, obj in ipairs(selectedObjects) do
                obj.color[1] = r
                obj.color[2] = g
                obj.color[3] = b
            end
        end
    end)

    cy = cy + 60


    -- =====================
    -- DANGER
    -- =====================
    drawSection("Danger Zone")

    drawButton("Delete Selected", x+15, cy, w-30, 28, function()
        deleteSelectedObjects()
    end, { theme = "danger" })

    cy = cy + 40

    -- =====================
    -- END SCROLL CONTENT
    -- =====================
    love.graphics.setScissor()

    -- =====================
    -- SCROLL LIMITS + BAR
    -- =====================
    local contentHeight = cy - (clipY + propsScroll)
    local maxScroll = math.max(0, contentHeight - clipH)

    propsScroll = math.min(0, math.max(-maxScroll, propsScroll))

    -- Scrollbar
    if contentHeight > clipH then
        local barH = clipH * (clipH / contentHeight)
        local t = -propsScroll / maxScroll
        local barY = clipY + t * (clipH - barH)

        love.graphics.setColor(1,1,1,0.2)
        love.graphics.rectangle("fill", x+w-6, barY, 4, barH)
        love.graphics.setColor(1,1,1,1)
    end
end

function fmtColor(v)
    return string.format("%.2f", v)
end

function rgb01ToHex(r,g,b)
    return string.format("#%02X%02X%02X",
        math.floor(r*255),
        math.floor(g*255),
        math.floor(b*255)
    )
end

function hexToRGB01(hex)
    hex = hex:gsub("#","")
    if #hex ~= 6 then return nil end

    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)

    if not r or not g or not b then return nil end

    return r/255, g/255, b/255
end

function drawToolsPanel()
    -- Tools
    ToolButtonY = WINDOW_H - 30

    addToolButton("Select", 10, ToolButtonY, TOOL_SELECT, function ()
        currentTool = TOOL_SELECT
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Move", 80, ToolButtonY, TOOL_MOVE, function ()
        currentTool = TOOL_MOVE
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Ball", 150, ToolButtonY, TOOL_BALL, function ()
        currentTool = TOOL_BALL
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Box", 220, ToolButtonY, TOOL_BOX, function ()
        currentTool = TOOL_BOX
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Drag", 290, ToolButtonY, TOOL_DRAG, function ()
        currentTool = TOOL_DRAG
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Freeze", 360, ToolButtonY, TOOL_FREEZE, function ()
        currentTool = TOOL_FREEZE
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Magnet", 430, ToolButtonY, TOOL_MAGNET, function ()
        currentTool = TOOL_MAGNET
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Weld", 500, ToolButtonY, TOOL_WELD, function ()
        currentTool = TOOL_WELD
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Spring", 570, ToolButtonY, TOOL_SPRING, function ()
        currentTool = TOOL_SPRING
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    addToolButton("Rope", 640, ToolButtonY, TOOL_ROPE, function ()
        currentTool = TOOL_ROPE
        jointLinkStart = nil
        cancelEdgeWeldDrag()
    end)

    -- Tool Properties
    ToolPropY = ToolButtonY - 30

    if currentTool == TOOL_MAGNET then
        love.graphics.print("Strength: " .. string.format("%.2f", magnetStrength), 10, ToolPropY - 20)
        love.graphics.print("Radius: " .. string.format("%.2f", magnetRadius), 10, ToolPropY)
        love.graphics.print("Mode: " .. magnetMode, 10, ToolPropY - 40)
    end

    if currentTool == TOOL_DRAG then
        love.graphics.print("Drag: " .. dragForce, 10, ToolPropY)
    end

    if currentTool == TOOL_SPRING then
        love.graphics.print("Freq: " .. string.format("%.2f", springFrequency), 10, ToolPropY - 20)
        love.graphics.print("Damping: " .. string.format("%.2f", springDamping), 10, ToolPropY)
    end

    if currentTool == TOOL_WELD then
        drawButton("Point Weld", 10, ToolPropY - 24, 92, 22, function()
            weldMode = "point"
        end, { active = weldMode == "point" })

        drawButton("Edge Weld", 108, ToolPropY - 24, 88, 22, function()
            weldMode = "edge"
        end, { active = weldMode == "edge" })

        drawButton("Soft", 10, ToolPropY + 2, 60, 20, function()
            weldRigidity = "soft"
        end, { active = weldRigidity == "soft" })

        drawButton("WELD", 74, ToolPropY + 2, 68, 20, function()
            weldRigidity = "hard"
        end, { active = weldRigidity == "hard" })
        love.graphics.print("X toggles weld mode", 200, ToolPropY - 20)
    end

    if isJointTool(currentTool) then
        local msg
        if currentTool == TOOL_WELD and weldMode == "edge" then
            msg = edgeWeldDrag.active and "Release near edge to weld" or "Drag body into another edge"
        else
            msg = jointLinkStart and "Pick second body..." or "Click first body..."
        end
        if currentTool == TOOL_WELD then
            msg = msg .. "  |  Rigidity: " .. weldRigidity
        end
        love.graphics.print(msg, 10, ToolPropY - 40)
    end
end

function addToolButton(text, x, y, toolId, onClick)
    local font = love.graphics.getFont()
    local w = math.max(60, font:getWidth(text) + 16)
    local h = 30

    drawButton("", x, y, w, h, onClick, {
        active = (currentTool == toolId)
    })

    local textW = font:getWidth(text)
    local textH = font:getHeight()

    local textX = math.floor(x + (w - textW) / 2 + 0.5)
    local textY = math.floor(y + (h - textH) / 2 + 0.5)

    love.graphics.setColor(1,1,1)
    love.graphics.print(text, textX, textY)
end

function drawToggleButton(label, x, y, w, h, value, onToggle)
    local text = label .. ": " .. (value and "ON" or "OFF")

    drawButton(text, x, y, w, h, function()
        onToggle(not value)
    end, {
        active = value
    })
end

function setObjectDensity(obj, density)
    obj.fixture:setDensity(density)
    obj.body:resetMassData() -- IMPORTANT: recalculates mass + inertia
end

function deleteObject(obj)
    if obj.body and not obj.body:isDestroyed() then
        flash(obj, {1, 1, 0.2}, 0.15)
        
        obj.body:destroy()
    end
end

function removeObjectFromList(obj)
    for i = #bodies, 1, -1 do
        if bodies[i] == obj then
            table.remove(bodies, i)
            break
        end
    end
end

function deleteSelectedObjects()
    if #selectedObjects == 0 then return end
    local removedCount = #selectedObjects
    pushUndoState()
    for _, obj in ipairs(selectedObjects) do
        deleteObject(obj)
        removeObjectFromList(obj)
    end
    selectedObjects = {}
    pruneJoints()
    if jointLinkStart and (not jointLinkStart.obj or jointLinkStart.obj.body:isDestroyed()) then
        jointLinkStart = nil
    end
    logLine("Deleted selected objects: " .. tostring(removedCount))
end

function deleteJoint(link, skipHistory)
    if not link then return end
    if not skipHistory then
        pushUndoState()
    end
    if link.extraJoint and not link.extraJoint:isDestroyed() then
        link.extraJoint:destroy()
    end
    if link.joint and not link.joint:isDestroyed() then
        link.joint:destroy()
    end

    for i = #joints, 1, -1 do
        if joints[i] == link then
            table.remove(joints, i)
            break
        end
    end

    if selectedJoint == link then
        selectedJoint = nil
    end
end

function deleteCurrentSelection()
    if selectedJoint then
        deleteJoint(selectedJoint, false)
        return
    end

    deleteSelectedObjects()
end

function clearSelectionOf(obj)
    -- Remove from selectedObjects
    for i = #selectedObjects, 1, -1 do
        if selectedObjects[i] == obj then
            table.remove(selectedObjects, i)
        end
    end
end

function screenToWorld(x, y)
    return (x - camX) / camScale,
           (y - camY) / camScale
end

function worldToScreen(wx, wy)
    local sx = (wx - camX) * camScale + WINDOW_W / 2
    local sy = (wy - camY) * camScale + WINDOW_H / 2
    return sx, sy
end

function drawSelectionOutline(obj)
    local r, g, b = obj.color[1], obj.color[2], obj.color[3]

    -- Perceived brightness for auto contrast
    local brightness = 0.2126*r + 0.7152*g + 0.0722*b

    local outlineColor
    if brightness > 0.6 then
        outlineColor = {0, 0, 0}   -- black glow for bright objects
    else
        outlineColor = {1, 1, 1}   -- white glow for dark objects
    end

    local body = obj.body
    local shape = obj.shape

    -- Glow passes (soft outer)
    for i = 3, 1, -1 do
        local alpha = 0.15 * i
        love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], alpha)
        love.graphics.setLineWidth(4 + i * 2)

        if shape:typeOf("CircleShape") then
            local x, y = body:getPosition()
            love.graphics.circle("line", x, y, shape:getRadius() + 2 + i*2)
        else
            love.graphics.polygon(
                "line",
                body:getWorldPoints(shape:getPoints())
            )
        end
    end

    -- Sharp inner outline
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(2)

    if shape:typeOf("CircleShape") then
        local x, y = body:getPosition()
        love.graphics.circle("line", x, y, shape:getRadius() + 1)
    else
        love.graphics.polygon(
            "line",
            body:getWorldPoints(shape:getPoints())
        )
    end

    -- Reset
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
end

function drawJointLinks()
    for _, link in ipairs(joints) do
        if link.joint and not link.joint:isDestroyed() then
            local ax, ay, bx, by = link.joint:getAnchors()
            local selected = (selectedJoint == link)

            if link.kind == "weld" then
                local rigidity = normalizeWeldRigidity(link.weldRigidity)
                local alpha = selected and 1.0 or 0.92
                local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 7)
                love.graphics.setColor(1.0, 0.45, 0.08, 0.45 * pulse)
                love.graphics.setLineWidth((selected and 10 or 7) / camScale)
                love.graphics.line(ax, ay, bx, by)
                love.graphics.setColor(1.0, 0.88, 0.25, alpha)
                love.graphics.setLineWidth((selected and 5 or 3) / camScale)
                love.graphics.line(ax, ay, bx, by)
                local mx, my = (ax + bx) * 0.5, (ay + by) * 0.5
                love.graphics.setColor(1.0, 0.95, 0.6, 0.95)
                love.graphics.circle("fill", ax, ay, 4.5 / camScale)
                love.graphics.circle("fill", bx, by, 4.5 / camScale)
                love.graphics.setColor(0.95, 0.95, 0.95, alpha)
                love.graphics.rectangle("fill", mx - (5 / camScale), my - (5 / camScale), 10 / camScale, 10 / camScale)
                love.graphics.setColor(1.0, 0.5, 0.12, 0.9)
                love.graphics.rectangle("line", mx - (8 / camScale), my - (8 / camScale), 16 / camScale, 16 / camScale)
                if rigidity == "hard" then
                    local dx, dy = bx - ax, by - ay
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0.001 then
                        local nx, ny = -dy / len, dx / len
                        local brace = 6 / camScale
                        love.graphics.setColor(1.0, 0.9, 0.45, 0.95)
                        love.graphics.setLineWidth((selected and 3 or 2) / camScale)
                        love.graphics.line(ax + nx * brace, ay + ny * brace, bx + nx * brace, by + ny * brace)
                        love.graphics.line(ax - nx * brace, ay - ny * brace, bx - nx * brace, by - ny * brace)
                    end
                else
                    local ring = (9 + 2 * math.sin(love.timer.getTime() * 5)) / camScale
                    love.graphics.setColor(1.0, 0.85, 0.25, selected and 0.85 or 0.55)
                    love.graphics.setLineWidth((selected and 2.5 or 1.5) / camScale)
                    love.graphics.circle("line", mx, my, ring)
                end
            elseif link.kind == "spring" then
                local coils, amp = getSpringVisualParams(ax, ay, bx, by)
                local pts = buildSpringPolyline(ax, ay, bx, by, coils, amp)
                love.graphics.setColor(0, 0, 0, selected and 0.35 or 0.24)
                love.graphics.setLineWidth((selected and 6 or 4) / camScale)
                love.graphics.line(pts)
                love.graphics.setColor(0.2, 1, 0.45, selected and 1.0 or 0.9)
                love.graphics.setLineWidth((selected and 4 or 2) / camScale)
                love.graphics.line(pts)
                love.graphics.setColor(0.8, 1, 0.85, 0.9)
                love.graphics.circle("fill", ax, ay, 2.5 / camScale)
                love.graphics.circle("fill", bx, by, 2.5 / camScale)
            elseif link.kind == "rope" then
                local pts = buildRopePolyline(ax, ay, bx, by, link.maxLength, 16)
                love.graphics.setColor(0.88, 0.9, 1.0, selected and 1.0 or 0.85)
                love.graphics.setLineWidth((selected and 4 or 2) / camScale)
                love.graphics.line(pts)
                love.graphics.setColor(0.95, 0.95, 1, 0.9)
                love.graphics.circle("fill", ax, ay, 2.5 / camScale)
                love.graphics.circle("fill", bx, by, 2.5 / camScale)
            end
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function drawPendingJointPreview()
    if edgeWeldDrag.active then return end
    if not jointLinkStart or not jointLinkStart.obj then return end
    if not jointLinkStart.obj.body or jointLinkStart.obj.body:isDestroyed() then
        jointLinkStart = nil
        return
    end

    local sx, sy = love.mouse.getPosition()
    local mx, my = screenToWorld(sx, sy)
    local ax, ay = jointLinkStart.ax, jointLinkStart.ay

    if currentTool == TOOL_WELD then
        love.graphics.setColor(1, 0.8, 0.2, 0.95)
    elseif currentTool == TOOL_SPRING then
        love.graphics.setColor(0.2, 1, 0.45, 0.95)
    elseif currentTool == TOOL_ROPE then
        love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
    end

    love.graphics.setLineWidth(2 / camScale)
    if currentTool == TOOL_WELD and weldMode == "edge" then
        local target = getObjectAtPoint(mx, my)
        if target and target ~= jointLinkStart.obj then
            local acx, acy = jointLinkStart.obj.body:getPosition()
            local bcx, bcy = target.body:getPosition()
            local pax, pay = closestSurfacePointToward(jointLinkStart.obj, bcx, bcy)
            local pbx, pby = closestSurfacePointToward(target, acx, acy)
            local wx, wy = (pax + pbx) * 0.5, (pay + pby) * 0.5
            love.graphics.line(pax, pay, wx, wy)
            love.graphics.line(wx, wy, pbx, pby)
            love.graphics.rectangle("fill", wx - (4 / camScale), wy - (4 / camScale), 8 / camScale, 8 / camScale)
        else
            love.graphics.line(ax, ay, mx, my)
        end
    elseif currentTool == TOOL_SPRING then
        local coils, amp = getSpringVisualParams(ax, ay, mx, my)
        local pts = buildSpringPolyline(ax, ay, mx, my, coils, amp)
        love.graphics.line(pts)
    elseif currentTool == TOOL_ROPE then
        local previewLen = math.sqrt((mx - ax)^2 + (my - ay)^2)
        local pts = buildRopePolyline(ax, ay, mx, my, previewLen, 16)
        love.graphics.line(pts)
    else
        love.graphics.line(ax, ay, mx, my)
    end
    if currentTool == TOOL_WELD then
        love.graphics.rectangle("fill", ax - (4 / camScale), ay - (4 / camScale), 8 / camScale, 8 / camScale)
        love.graphics.rectangle("line", mx - (4 / camScale), my - (4 / camScale), 8 / camScale, 8 / camScale)
    else
        love.graphics.circle("fill", ax, ay, 4 / camScale)
        love.graphics.circle("line", mx, my, 4 / camScale)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function drawEdgeWeldPreview()
    if not edgeWeldDrag.active then return end
    if not edgeWeldDrag.obj or not edgeWeldDrag.obj.body then return end
    if edgeWeldDrag.obj.body:isDestroyed() then return end

    if not edgeWeldDrag.candidate or edgeWeldDrag.dist == math.huge then
        return
    end

    local ax, ay = edgeWeldDrag.ax, edgeWeldDrag.ay
    local bx, by = edgeWeldDrag.bx, edgeWeldDrag.by
    local mx, my = (ax + bx) * 0.5, (ay + by) * 0.5

    local near = edgeWeldDrag.dist <= EDGE_WELD_HOVER_DIST
    local snap = edgeWeldDrag.dist <= EDGE_WELD_SNAP_DIST
    if not near then return end

    if snap then
        love.graphics.setColor(1, 0.9, 0.2, 0.95)
    else
        love.graphics.setColor(0.2, 1, 0.95, 0.9)
    end
    love.graphics.setLineWidth((snap and 4 or 2) / camScale)
    love.graphics.line(ax, ay, bx, by)
    love.graphics.rectangle("line", ax - (6 / camScale), ay - (6 / camScale), 12 / camScale, 12 / camScale)
    love.graphics.rectangle("line", bx - (6 / camScale), by - (6 / camScale), 12 / camScale, 12 / camScale)
    local center = (snap and 5 or 3) / camScale
    love.graphics.rectangle("fill", mx - center, my - center, center * 2, center * 2)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("%.1f", edgeWeldDrag.dist), mx + 8 / camScale, my - 10 / camScale)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function copySelectedObjects()
    clipboard = {}

    if #selectedObjects == 0 then return end

    -- Use first selected as reference
    local refX, refY = selectedObjects[1].body:getPosition()

    for _, obj in ipairs(selectedObjects) do
        local body = obj.body
        local shape = obj.shape

        local bx, by = body:getPosition()

        local entry = {
            relX = bx - refX,
            relY = by - refY,

            color = {obj.color[1], obj.color[2], obj.color[3]},
            angle = body:getAngle(),

            restitution = obj.fixture:getRestitution(),
            friction    = obj.fixture:getFriction(),
            density     = obj.fixture:getDensity(),
            collisionsEnabled = obj.collisionsEnabled ~= false,
        }

        if shape:typeOf("CircleShape") then
            entry.type = "circle"
            entry.radius = shape:getRadius()
        elseif obj.shapeType == "box" then
            entry.type = "box"
            entry.width  = obj.width
            entry.height = obj.height
        else
            entry.type = "polygon"
            entry.points = {shape:getPoints()}
        end


        flash(obj, {0, 1, 0}, 0.25)
        table.insert(clipboard, entry)
    end

    print("Copied", #clipboard, "objects")
end

function pasteObjectsAt(x, y)
    if #clipboard == 0 then return end
    pushUndoState()

    clearAllSelection()

    for _, data in ipairs(clipboard) do
        local body = love.physics.newBody(world,
            x + data.relX,
            y + data.relY,
            "dynamic"
        )

        body:setAngle(data.angle)

        local shape
        if data.type == "circle" then
            shape = love.physics.newCircleShape(data.radius)
        elseif data.type == "box" then
            shape = love.physics.newRectangleShape(
                data.width,
                data.height
            )
        else
            shape = love.physics.newPolygonShape(data.points)
        end

        local fix = love.physics.newFixture(body, shape, data.density or 1)
        fix:setRestitution(data.restitution or 0.3)
        fix:setFriction(data.friction or 0.5)
        local collisionsEnabled = (data.collisionsEnabled ~= false)
        fix:setSensor(not collisionsEnabled)

        local obj = {
            body = body,
            shape = shape,
            fixture = fix,
            color = {data.color[1], data.color[2], data.color[3]},
            selected = true,
            collisionsEnabled = collisionsEnabled,

            shapeType = data.type,
            width  = data.width,
            height = data.height,
            radius = data.radius,
        }


        flash(obj, {0.2, 0.6, 1}, 0.25)
        table.insert(bodies, obj)
        table.insert(selectedObjects, obj)      
    end
end

function copySelectedProperties()
    if #selectedObjects == 0 then return end

    local obj = selectedObjects[1]

    propertyClipboard = {
        restitution = obj.fixture:getRestitution(),
        friction    = obj.fixture:getFriction(),
        density     = obj.fixture:getDensity(),
        collisionsEnabled = obj.collisionsEnabled ~= false,
        color       = {obj.color[1], obj.color[2], obj.color[3]},
    }

    -- Flash green feedback
    for _, o in ipairs(selectedObjects) do
        flash(obj, {0, 1, 0}, 0.25)
    end

    print("Copied properties")
end

function pastePropertiesToSelected()
    if not propertyClipboard then return end
    if #selectedObjects == 0 then return end
    pushUndoState()

    for _, obj in ipairs(selectedObjects) do
        obj.fixture:setRestitution(propertyClipboard.restitution)
        obj.fixture:setFriction(propertyClipboard.friction)
        obj.fixture:setDensity(propertyClipboard.density)
        obj.collisionsEnabled = propertyClipboard.collisionsEnabled ~= false
        obj.fixture:setSensor(not obj.collisionsEnabled)

        obj.color[1] = propertyClipboard.color[1]
        obj.color[2] = propertyClipboard.color[2]
        obj.color[3] = propertyClipboard.color[3]

        flash(obj, {0.2, 0.6, 1}, 0.25)
    end

    print("Pasted properties")
end

function drawUI()
    -- Tool UI
    local toolName = {
        [TOOL_SELECT] = "Select",
        [TOOL_MOVE] = "Move",
        [TOOL_BALL] = "Spawn Ball",
        [TOOL_BOX] = "Spawn Box",
        [TOOL_DRAG] = "Drag",
        [TOOL_FREEZE] = "Freeze",
        [TOOL_MAGNET] = "Magnet",
        [TOOL_WELD] = "Weld",
        [TOOL_SPRING] = "Spring",
        [TOOL_ROPE] = "Rope"
    }

    love.graphics.setColor(0.04, 0.07, 0.11, 0.82)
    love.graphics.rectangle("fill", 6, 6, 240, 92, 9, 9)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.42)
    love.graphics.rectangle("line", 6, 6, 240, 92, 9, 9)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", 8, 8, 236, 20, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 14, 12)
    love.graphics.setColor(0.92, 0.97, 1.0)
    love.graphics.print("Tool: " .. toolName[currentTool], 14, 40)

    -- Controls, slow motion, tools, properties
    drawPropertiesPanel()
    drawToolsPanel()

    drawButton("", WINDOW_W / 2, 10, 30, 30, function ()
        if not inSlowMotion then
            timeScale = slowMotionMod
            inSlowMotion = true
        else
            timeScale = 1.0
            inSlowMotion = false
        end
    end, {
        active = inSlowMotion
    })

    love.graphics.draw(slowMotionIcon, (WINDOW_W / 2) - 3, 10, 0, 0.03, 0.03)

    -- Current world Name
    if currentWorldName then
        love.graphics.print("World: " .. currentWorldName, 14, 60)
    else
        love.graphics.print("World: (unsaved)", 14, 60)
    end

    if currentWorldName then
        local t = math.floor(AUTO_SAVE_INTERVAL - autoSaveTimer)
        love.graphics.print("Auto-save in: " .. t .. "s", 14, 78)
        local pulse = 0.45 + 0.55 * math.abs(math.sin(love.timer.getTime() * 2.4))
        local urgent = t <= 5
        if urgent then
            love.graphics.setColor(1.0, 0.28, 0.28, 0.55 + 0.4 * pulse)
        else
            love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.35 + 0.4 * pulse)
        end
        love.graphics.circle("fill", 132, 85, 4)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Status chips
    local chipY = 10
    local function chipWidth(text)
        return love.graphics.getFont():getWidth(text) + 16
    end
    local function drawChip(text, x, y)
        local fw = love.graphics.getFont():getWidth(text)
        local fh = love.graphics.getFont():getHeight()
        local w = fw + 16
        local h = fh + 8
        love.graphics.setColor(0.07, 0.1, 0.16, 0.92)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.55)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.setColor(1, 1, 1, 0.07)
        love.graphics.rectangle("fill", x + 1, y + 1, w - 2, 6, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, x + 8, y + 4)
        return w
    end

    local x = WINDOW_W - 10
    local redoText = "Redo: " .. tostring(#redoStack)
    local undoText = "Undo: " .. tostring(#undoStack)
    x = x - chipWidth(redoText)
    drawChip("Redo: " .. tostring(#redoStack), x, chipY)
    x = x - 8
    x = x - chipWidth(undoText)
    drawChip(undoText, x, chipY)

    if historyToastTimer > 0 and historyToastText then
        local alpha = math.min(1, historyToastTimer / 0.2)
        local text = historyToastText .. " (" .. tostring(#undoStack) .. "/" .. tostring(#redoStack) .. ")"
        local fw = love.graphics.getFont():getWidth(text)
        local fh = love.graphics.getFont():getHeight()
        local w = fw + 24
        local h = fh + 12
        local tx = (WINDOW_W - w) * 0.5
        local ty = 46
        love.graphics.setColor(0.04, 0.08, 0.12, 0.9 * alpha)
        love.graphics.rectangle("fill", tx, ty, w, h, 10, 10)
        love.graphics.setColor(0.4, 0.95, 0.8, 0.9 * alpha)
        love.graphics.rectangle("line", tx, ty, w, h, 10, 10)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(text, tx + 12, ty + 6)
    end

    if showTesterHUD then
        local objectCount = #bodies
        local jointCount = #joints
        local selectedCount = #selectedObjects
        local mem = collectgarbage("count") / 1024
        local lines = {
            "TESTER HUD (F1)",
            "Objects: " .. objectCount,
            "Joints: " .. jointCount,
            "Selected Objects: " .. selectedCount,
            "Selected Joint: " .. tostring(selectedJoint and selectedJoint.kind or "none"),
            "Undo/Redo: " .. tostring(#undoStack) .. " / " .. tostring(#redoStack),
            "Tool: " .. tostring(toolName[currentTool] or "?"),
            string.format("Mem: %.1f MB", mem),
        }

        local pad = 10
        local lineH = love.graphics.getFont():getHeight() + 2
        local w = 0
        for _, s in ipairs(lines) do
            w = math.max(w, love.graphics.getFont():getWidth(s))
        end
        local h = (#lines * lineH) + pad * 2
        local x = 10
        local y = 110
        love.graphics.setColor(0.03, 0.05, 0.08, 0.86)
        love.graphics.rectangle("fill", x, y, w + pad * 2, h, 8, 8)
        love.graphics.setColor(0.4, 0.95, 0.8, 0.55)
        love.graphics.rectangle("line", x, y, w + pad * 2, h, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        for i, s in ipairs(lines) do
            love.graphics.print(s, x + pad, y + pad + (i - 1) * lineH)
        end
    end

end

function drawMainMenu()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    local cx = WINDOW_W / 2
    local cy = WINDOW_H / 2

    -- Draw physics background
    for _, obj in ipairs(menuObjects) do
        love.graphics.setColor(obj.color)
        love.graphics.push()
        love.graphics.translate(obj.body:getX(), obj.body:getY())
        love.graphics.rotate(obj.body:getAngle())

        if obj.shape:typeOf("CircleShape") then
            love.graphics.circle("fill", 0, 0, obj.shape:getRadius())
        else
            love.graphics.polygon("fill", obj.shape:getPoints())
        end

        love.graphics.pop()
    end

    love.graphics.setColor(1,1,1)

    -- Dark overlay so UI pops
    love.graphics.setColor(0,0,0,0.4)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)
    local glow = 0.08 + 0.03 * math.sin(love.timer.getTime() * 1.6)
    love.graphics.setColor(UI_ACCENT_SOFT[1], UI_ACCENT_SOFT[2], UI_ACCENT_SOFT[3], glow)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H * 0.36)
    love.graphics.setColor(1,1,1)


    -- ===== Main Card Panel =====
    local panelW = 420
    local panelH = 500
    local panelX = cx - panelW / 2
    local panelY = cy - panelH / 2

    drawPanel(panelX, panelY, panelW, panelH)

    -- ===== Title =====
    love.graphics.setColor(1,1,1)
    love.graphics.printf("PHYSICS PLAYGROUND", panelX, panelY + 40, panelW, "center")

    -- Subtitle
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.printf("Sandbox Physics Simulator", panelX, panelY + 70, panelW, "center")
    local subtitlePulse = 0.45 + 0.35 * math.sin(love.timer.getTime() * 2.6)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], subtitlePulse)
    love.graphics.rectangle("fill", panelX + 115, panelY + 92, panelW - 230, 2, 2, 2)

    -- Divider
    love.graphics.setColor(1,1,1,0.2)
    love.graphics.line(panelX + 40, panelY + 110, panelX + panelW - 40, panelY + 110)

    -- ===== Buttons =====
    local btnW = 240
    local btnH = 44
    local btnX = cx - btnW / 2
    local y = panelY + 150

    drawButton("New World", btnX, y, btnW, btnH, function()
        resetWorld()
        currentWorldName = nil
        autoSaveTimer = 0
        gameState = STATE_WORLD
    end)

    y = y + 65

    drawButton("Load World", btnX, y, btnW, btnH, function()
        refreshSaveCache()
        loadSearch = ""
        loadMenuScroll = 0
        gameState = STATE_LOAD
    end)

    y = y + 65

    drawButton("Settings", btnX, y, btnW, btnH, function()
        settingsScroll = 0
        rebindingAction = nil
        gameState = STATE_SETTINGS
    end)

    y = y + 65

    drawButton("Quit", btnX, y, btnW, btnH, function()
        love.event.quit()
    end, { theme = "danger" })

    y = y + 62
    drawButton("Rick", cx - 52, y, 104, 28, function()
        love.system.openURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end)

    -- ===== Footer / Credits =====
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("Owner: Galaxy", panelX, panelY + panelH - 60, panelW, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Thanks to Rick for the ideas", panelX, panelY + panelH - 40, panelW, "center")

    -- Tiny moving corner accents for menu card.
    local t = love.timer.getTime()
    local wobble = math.sin(t * 2.0) * 3
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.45)
    love.graphics.rectangle("fill", panelX + 8 + wobble, panelY + 8, 16, 2, 1, 1)
    love.graphics.rectangle("fill", panelX + 8, panelY + 8 + wobble, 2, 16, 1, 1)
    love.graphics.rectangle("fill", panelX + panelW - 24 - wobble, panelY + panelH - 10, 16, 2, 1, 1)
    love.graphics.rectangle("fill", panelX + panelW - 10, panelY + panelH - 24 - wobble, 2, 16, 1, 1)

    -- Version / Build tag (feels pro)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("v1.0 RC", panelX + 10, panelY + panelH - 20)
end

function drawLoadMenu()
    local panelW = math.floor(WINDOW_W * 0.65)
    local panelH = math.floor(WINDOW_H * 0.75)
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)

    -- ===== Background Dim =====
    love.graphics.setColor(0,0,0,0.45)
    love.graphics.rectangle("fill", 0,0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(UI_ACCENT_SOFT[1], UI_ACCENT_SOFT[2], UI_ACCENT_SOFT[3], 0.08)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H * 0.28)

    -- ===== Main Panel =====
    drawPanel(panelX, panelY, panelW, panelH)

    -- ===== Title =====
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Load World", panelX, panelY + 20, panelW, "center")

    love.graphics.setColor(0.7,0.7,0.9)
    love.graphics.printf("Double-click a world to load", panelX, panelY + 45, panelW, "center")

    -- Divider
    love.graphics.setColor(1,1,1,0.2)
    love.graphics.line(panelX + 30, panelY + 75, panelX + panelW - 30, panelY + 75)

    -- ===== Back Button =====
    drawButton("Back", panelX + 20, panelY + 20, 80, 28, function()
        saveSettings()
        gameState = STATE_MENU
        initMenuWorld()
    end)

    -- ===== Search Bar =====
    local searchY = panelY + 90
    love.graphics.setColor(1,1,1)
    love.graphics.print("Search:", panelX + 30, searchY)

    local searchX = panelX + 100
    local searchW = 260
    love.graphics.setColor(0.1, 0.12, 0.17, 0.9)
    love.graphics.rectangle("fill", searchX, searchY - 4, searchW, 26, 5, 5)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.45)
    love.graphics.rectangle("line", searchX, searchY - 4, searchW, 26, 5, 5)
    love.graphics.setColor(1,1,1)
    love.graphics.print(loadSearch .. "_", searchX + 6, searchY)

    -- ===== Filter Saves =====
    local filtered = {}
    for _, entry in ipairs(saveCache) do
        local name = entry.file:lower()
        if loadSearch == "" or name:find(loadSearch:lower(), 1, true) then
            table.insert(filtered, entry)
        end
    end

    -- ===== Scrolling =====
    local listX = panelX + 30
    local listY = panelY + 140
    local listW = panelW - 60
    local rowH  = LOAD_ROW_HEIGHT
    local viewH = panelH - 180
    local totalH = #filtered * rowH

    if totalH < viewH then
        loadMenuScroll = 0
    else
        loadMenuScroll = math.max(viewH - totalH, math.min(0, loadMenuScroll))
    end

    -- ===== List Background =====
    love.graphics.setColor(0.07, 0.09, 0.12, 0.95)
    love.graphics.rectangle("fill", listX, listY, listW, viewH, 6, 6)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.25)
    love.graphics.rectangle("line", listX, listY, listW, viewH, 6, 6)

    -- ===== Draw Rows =====
    for i, entry in ipairs(filtered) do
        local file = entry.file
        local meta = entry.meta

        local x = listX
        local y = listY + (i-1) * rowH + loadMenuScroll
        local w = listW
        local h = rowH
        
        local mx, my = love.mouse.getPosition()
        local hovered = mx >= x and mx <= x+w and my >= y and my <= y+h

        if y + h >= listY and y <= listY + viewH then
            -- Row BG
            if hovered then
                love.graphics.setColor(0.19, 0.24, 0.32)
            else
                love.graphics.setColor(0.12, 0.15, 0.2)
            end
            love.graphics.rectangle("fill", x, y, w, h)

            -- Border
            love.graphics.setColor(1,1,1,0.06)
            love.graphics.rectangle("line", x, y, w, h)

            -- Name
            love.graphics.setColor(1,1,1)
            love.graphics.print(meta.name or file, x + 10, y + 4)

            -- Meta Info
            local info = string.format(
                "Objects: %d   Modified: %s",
                meta.objectCount or 0,
                meta.modified and os.date("%Y-%m-%d %H:%M", meta.modified) or "?"
            )

            love.graphics.setColor(0.7,0.7,0.7)
            love.graphics.print(info, x + 10, y + 18)

            -- Delete Button (on hover)
            if hovered then
                drawButton("Delete", x + w - 80, y + 4, 70, h - 8, function()
                    deleteWorld(file)
                end, { theme = "danger" })
            end
        end
    end

    -- ===== Empty State =====
    if #filtered == 0 then
        love.graphics.setColor(0.7,0.7,0.7)
        love.graphics.printf("No saves found.", listX, listY + viewH/2 - 10, listW, "center")
    end
end

function drawSettingsMenu()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)
    love.graphics.setColor(0, 0, 0, 0.38)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H)
    love.graphics.setColor(UI_ACCENT_SOFT[1], UI_ACCENT_SOFT[2], UI_ACCENT_SOFT[3], 0.08)
    love.graphics.rectangle("fill", 0, 0, WINDOW_W, WINDOW_H * 0.25)

    local cx = WINDOW_W / 2
    local y = 160

    love.graphics.setColor(1,1,1)
    love.graphics.printf("SETTINGS", 0, 80, WINDOW_W, "center")
    local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 2.2)
    love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], pulse * 0.8)
    love.graphics.rectangle("fill", cx - 110, 112, 220, 2, 2, 2)

    -- Main panel
    local pw = 520
    local ph = math.min(620, WINDOW_H - 120)
    local px = cx - pw/2
    local py = y

    drawPanel(px, py, pw, ph)

    local viewY = py + 16
    local viewH = ph - 74 -- keep a fixed footer for Back button
    love.graphics.setScissor(px + 8, viewY, pw - 16, viewH)

    local cy = viewY + settingsScroll
    local function inView(rowY, rowH)
        return rowY + rowH >= viewY and rowY <= viewY + viewH
    end

    if inView(cy, 24) then drawSectionHeader("Audio", px+20, cy, pw-40) end
    cy = cy + 30

    if inView(cy, 34) then
        drawSliderRow("Master Volume", px+20, cy, pw-40,
            settings.masterVolume, 0, 1,
            function(v)
                settings.masterVolume = v
                love.audio.setVolume(v)
                saveSettings()
            end, "mastervolume")
    end
    cy = cy + 40

    if inView(cy, 10) then drawDividerSoft(px+20, cy, pw-40) end
    cy = cy + 20

    if inView(cy, 24) then drawSectionHeader("Display", px+20, cy, pw-40) end
    cy = cy + 30

    if inView(cy, 28) then
        drawToggleButton("Fullscreen", px+20, cy, pw-40, 26,
            settings.fullscreen, function(v)
                settings.fullscreen = v
                love.window.setFullscreen(v)
                saveSettings()
            end)
    end
    cy = cy + 36

    if inView(cy, 28) then
        drawToggleButton("VSync", px+20, cy, pw-40, 26,
            settings.vsync, function(v)
                settings.vsync = v
                love.window.setVSync(v and 1 or 0)
                saveSettings()
            end)
    end
    cy = cy + 36

    if inView(cy, 10) then drawDividerSoft(px+20, cy, pw-40) end
    cy = cy + 20

    if inView(cy, 24) then drawSectionHeader("Editor", px+20, cy, pw-40) end
    cy = cy + 30

    if inView(cy, 28) then
        drawToggleButton("Show Grid", px+20, cy, pw-40, 26,
            settings.showGrid, function(v)
                settings.showGrid = v
                saveSettings()
            end)
    end
    cy = cy + 36

    if inView(cy, 34) then
        drawSliderRow("Auto save Interval", px+20, cy, pw-40,
            settings.autoSaveInterval, 10, 600,
            function(v)
                settings.autoSaveInterval = v
                AUTO_SAVE_INTERVAL = settings.autoSaveInterval
                saveSettings()
            end, "autosave")
    end
    
    cy = cy + 36

    if inView(cy, 34) then
        drawSliderRow("Slow motion modifier", px+20, cy, pw-40,
            settings.slowMotionModifier, 0.1, 0.9,
            function(v)
                settings.slowMotionModifier = v
                slowMotionMod = settings.slowMotionModifier
                saveSettings()
            end, "slowmotion")
    end
    
    cy = cy + 36

    if inView(cy, 10) then drawDividerSoft(px+20, cy, pw-40) end
    cy = cy + 20

    if inView(cy, 24) then drawSectionHeader("Controls", px+20, cy, pw-40) end
    cy = cy + 30

    local controlsRows = {
        {"Select Tool", "tool_select"}, {"Move Tool", "tool_move"},
        {"Ball Tool", "tool_ball"}, {"Box Tool", "tool_box"},
        {"Drag Tool", "tool_drag"}, {"Freeze Tool", "tool_freeze"},
        {"Magnet Tool", "tool_magnet"}, {"Weld Tool", "tool_weld"},
        {"Spring Tool", "tool_spring"}, {"Rope Tool", "tool_rope"},
        {"Undo", "undo"}, {"Redo", "redo"},
        {"Delete", "delete_selected"}, {"Pause", "pause"},
        {"Slowmo", "slowmo"}, {"Reset Zoom", "reset_zoom"},
        {"Weld Mode", "weld_mode_toggle"}, {"Toggle UI", "toggle_ui"},
    }

    local colW = (pw - 60) / 2
    local leftX = px + 20
    local rightX = leftX + colW + 20
    local rowH = 24

    local function niceKeyName(k)
        if k == "space" then return "SPACE" end
        if k == "kpenter" then return "NUM ENTER" end
        if k == "return" then return "ENTER" end
        return string.upper(tostring(k or "?"))
    end

    for i, row in ipairs(controlsRows) do
        local label, action = row[1], row[2]
        local col = ((i - 1) % 2 == 0) and leftX or rightX
        local rowIndex = math.floor((i - 1) / 2)
        local ry = cy + rowIndex * (rowH + 6)

        local keyLabel = (rebindingAction == action) and "PRESS KEY..." or niceKeyName(controls[action])
        if inView(ry, rowH) then
            drawButton(label .. ": " .. keyLabel, col, ry, colW, rowH, function()
                rebindingAction = action
            end, { active = rebindingAction == action })
        end
    end

    cy = cy + math.ceil(#controlsRows / 2) * (rowH + 6) + 6

    if inView(cy, 28) then
        drawButton("Reset Controls", px+20, cy, pw-40, 26, function()
            controls = getDefaultControls()
            rebindingAction = nil
            saveControls()
        end)
    end
    cy = cy + 36

    if inView(cy, 10) then drawDividerSoft(px+20, cy, pw-40) end
    cy = cy + 20

    -- End scrollable content
    love.graphics.setScissor()

    local contentHeight = cy - settingsScroll - viewY
    local maxScroll = math.max(0, contentHeight - viewH)
    settingsScroll = math.min(0, math.max(-maxScroll, settingsScroll))

    if maxScroll > 0 then
        local barH = math.max(30, viewH * (viewH / contentHeight))
        local t = (-settingsScroll) / maxScroll
        local barY = viewY + t * (viewH - barH)
        love.graphics.setColor(1,1,1,0.08)
        love.graphics.rectangle("fill", px + pw - 10, viewY, 4, viewH, 3,3)
        love.graphics.setColor(UI_ACCENT[1], UI_ACCENT[2], UI_ACCENT[3], 0.75)
        love.graphics.rectangle("fill", px + pw - 10, barY, 4, barH, 3,3)
        love.graphics.setColor(1,1,1,1)
    end

    if rebindingAction then
        love.graphics.setColor(0.95, 0.9, 0.45, 1)
        love.graphics.printf("Press a key to bind (ESC to cancel)", px + 20, py + ph - 70, pw - 40, "center")
    elseif maxScroll > 0 then
        love.graphics.setColor(0.8, 0.8, 0.85, 0.8)
        love.graphics.printf("Scroll to see more settings", px + 20, py + ph - 70, pw - 40, "center")
    end

    drawButton("Back", cx - 80, py + ph - 40, 160, 30, function()
        rebindingAction = nil
        gameState = STATE_MENU
        initMenuWorld()
    end)
end

function drawGrid()
    if not settings.showGrid then return end

    local scale = camScale
    local base = GRID_SIZE

    -- Fade out when zoomed far out
    if scale < 0.15 then
        return
    end

    -- Adaptive spacing (world units)
    local spacing = base

    local w = love.graphics.getWidth() / scale
    local h = love.graphics.getHeight() / scale

    -- Camera top-left in WORLD space
    local worldLeft = (-camX / scale) + 10
    local worldTop  = -camY / scale

    -- First grid lines in world space
    local startX = math.floor(worldLeft / spacing) * spacing
    local startY = math.floor(worldTop  / spacing) * spacing

    love.graphics.setColor(GRID_COLOR)

    local maxLines = 300

    -- Vertical (WORLD space)
    local count = 0
    for gx = startX, startX + w, spacing do
        love.graphics.line(gx, worldTop, gx, worldTop + h)
        count = count + 1
        if count > maxLines then break end
    end

    -- Horizontal (WORLD space)
    count = 0
    for gy = startY, startY + h, spacing do
        love.graphics.line(worldLeft, gy, worldLeft + w, gy)
        count = count + 1
        if count > maxLines then break end
    end

    love.graphics.setColor(1,1,1,1)
end

function spawnMenuObject()
    local x = math.random(50, WINDOW_W-50)
    local y = -50

    local body = love.physics.newBody(menuWorld, x, y, "dynamic")

    local isCircle = math.random() < 0.5
    local shape

    if isCircle then
        shape = love.physics.newCircleShape(math.random(10, 30))
    else
        shape = love.physics.newRectangleShape(
            math.random(20, 60),
            math.random(20, 60)
        )
    end

    local fix = love.physics.newFixture(body, shape, 1)
    fix:setRestitution(0.7)
    fix:setFriction(0.2)


    local obj = {
        body = body,
        shape = shape,
        color = {math.random(), math.random(), math.random()}
    }

    body:setAngularVelocity(math.random(-5, 5))

    table.insert(menuObjects, obj)

    if #menuObjects > 50 then
        local old = table.remove(menuObjects, 1)
        if old and old.body and not old.body:isDestroyed() then
            old.body:destroy()
        end
    end

end

function initMenuWorld()
    menuWorld = love.physics.newWorld(0, 800, true)
    menuObjects = {}

    -- Floor
    menuGroundBody = love.physics.newBody(menuWorld, WINDOW_W/2, WINDOW_H + 20, "static")
    menuGroundShape = love.physics.newRectangleShape(WINDOW_W, 40)
    menuGroundFixture = love.physics.newFixture(menuGroundBody, menuGroundShape)
end

function spawnImpactParticles(x, y, nx, ny, power)
    power = power or 1
    power = math.max(0.3, math.min(power, 2))

    for i = 1, math.random(6, 12) do
        local baseAngle = math.atan2(ny, nx) + math.pi
        local angle = baseAngle + (math.random() - 0.5) * 1.2

        local speed = math.random(120, 260) * power

        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed - math.random(80, 160)

        table.insert(impactParticles, {
            x = x,
            y = y,
            vx = vx,
            vy = vy,

            radius = math.random(2, 4),
            life = math.random(0.2, 0.4),
            alpha = 1,
        })
    end
end

function spawnWeldParticles(x, y, intensity)
    local now = love.timer.getTime()
    if (now - (lastWeldParticleTime or -10)) < 0.06 then
        return
    end
    lastWeldParticleTime = now

    if #weldParticles > 220 then
        return
    end

    intensity = intensity or 1
    local count = math.floor(12 * intensity)
    local room = math.max(0, 260 - #weldParticles)
    count = math.min(count, room)
    if count <= 0 then return end
    for i = 1, count do
        local ang = math.random() * (math.pi * 2)
        local speed = math.random(90, 260) * intensity
        local life = math.random(18, 40) / 100
        table.insert(weldParticles, {
            x = x,
            y = y,
            vx = math.cos(ang) * speed,
            vy = math.sin(ang) * speed - math.random(40, 120),
            radius = math.random(1, 3),
            life = life,
            maxLife = life,
        })
    end
end

function triggerRandomEasterEgg()
    local sx, sy = WINDOW_W * 0.5, WINDOW_H * 0.42
    local wx, wy = screenToWorld(sx, sy)
    local palette = {
        {1.0, 0.35, 0.95},
        {0.62, 0.45, 1.0},
        {0.35, 0.92, 1.0},
        {1.0, 0.8, 0.35},
    }

    local variant = math.random(1, 2)
    pushUndoState()

    if variant == 1 then
        for i = 1, 10 do
            local angle = (i / 10) * (math.pi * 2)
            local radius = 24 + math.random() * 20
            spawnBall(wx + math.cos(angle) * radius, wy + math.sin(angle) * radius, math.random(10, 16))
            local obj = bodies[#bodies]
            if obj and obj.body then
                local c = palette[((i - 1) % #palette) + 1]
                obj.color = {c[1], c[2], c[3]}
                obj.body:setLinearVelocity(math.cos(angle) * (220 + math.random() * 120), math.sin(angle) * (220 + math.random() * 120) - 90)
                obj.body:setAngularVelocity((math.random() - 0.5) * 14)
            end
        end
        showHistoryToast("Easter Egg: Orbit Drop")
        logInfo("Easter egg triggered: Orbit Drop")
    else
        for i = 1, 9 do
            local px = wx - 160 + (i - 1) * 40
            local py = wy - 180 - math.random(0, 90)
            local bw, bh = math.random(22, 38), math.random(14, 26)
            spawnBox(px, py, bw, bh)
            local obj = bodies[#bodies]
            if obj and obj.body then
                local c = palette[((i - 1) % #palette) + 1]
                obj.color = {c[1], c[2], c[3]}
                obj.body:setAngle((math.random() - 0.5) * 0.6)
                obj.body:setLinearVelocity((math.random() - 0.5) * 90, math.random(120, 210))
                obj.body:setAngularVelocity((math.random() - 0.5) * 10)
            end
        end
        showHistoryToast("Easter Egg: Neon Rain")
        logInfo("Easter egg triggered: Neon Rain")
    end

    flashColor = {0.9, 0.48, 1.0}
    flashDuration = 0.22
    flashTimer = flashDuration
end

local function triggerPartyEasterEgg()
    if #bodies == 0 then return end
    pushUndoState()
    local palette = {
        {1.0, 0.25, 0.85},
        {0.75, 0.45, 1.0},
        {0.35, 0.8, 1.0},
        {1.0, 0.65, 0.3},
    }
    for i, obj in ipairs(bodies) do
        local c = palette[((i - 1) % #palette) + 1]
        obj.color = {c[1], c[2], c[3]}
        if obj.body and not obj.body:isDestroyed() then
            local boost = 60 + math.random() * 140
            obj.body:setAngularVelocity(obj.body:getAngularVelocity() + (math.random() - 0.5) * 6)
            local vx, vy = obj.body:getLinearVelocity()
            obj.body:setLinearVelocity(vx + (math.random() - 0.5) * boost, vy - boost * 0.25)
        end
    end
    showHistoryToast("Easter Egg: Party Paint")
    logInfo("Easter egg triggered: Party Paint")
    flashColor = {0.95, 0.42, 1.0}
    flashDuration = 0.2
    flashTimer = flashDuration
end

local function triggerBoomEasterEgg()
    if #bodies == 0 then return end
    local sx, sy = love.mouse.getPosition()
    local cx, cy = screenToWorld(sx, sy)
    pushUndoState()
    for _, obj in ipairs(bodies) do
        if obj.body and not obj.body:isDestroyed() and obj.body:getType() ~= "static" then
            local ox, oy = obj.body:getPosition()
            local dx, dy = ox - cx, oy - cy
            local d2 = dx * dx + dy * dy
            local dist = math.sqrt(d2)
            if dist < 0.001 then
                dx, dy, dist = 1, 0, 1
            end
            local radius = 480
            if dist < radius then
                local t = 1 - (dist / radius)
                local force = 260 * t
                obj.body:applyLinearImpulse((dx / dist) * force, (dy / dist) * force)
                obj.body:setAngularVelocity(obj.body:getAngularVelocity() + (math.random() - 0.5) * 12 * t)
            end
        end
    end
    showHistoryToast("Easter Egg: Boom Pulse")
    logInfo("Easter egg triggered: Boom Pulse")
    spawnImpactParticles(cx, cy, 0, -1, 2.0)
    flashColor = {1.0, 0.6, 0.25}
    flashDuration = 0.18
    flashTimer = flashDuration
end

local function triggerTinyEasterEgg()
    local sx, sy = WINDOW_W * 0.5, WINDOW_H * 0.4
    local wx, wy = screenToWorld(sx, sy)
    pushUndoState()
    for i = 1, 24 do
        local angle = (i / 24) * (math.pi * 2)
        local px = wx + math.cos(angle) * 80
        local py = wy + math.sin(angle) * 80
        spawnBall(px, py, math.random(4, 7))
        local obj = bodies[#bodies]
        if obj and obj.body then
            obj.color = {0.9, 0.75, 1.0}
            obj.body:setLinearVelocity(math.cos(angle) * 120, math.sin(angle) * 120 - 40)
            obj.body:setAngularVelocity((math.random() - 0.5) * 14)
        end
    end
    showHistoryToast("Easter Egg: Tiny Storm")
    logInfo("Easter egg triggered: Tiny Storm")
    flashColor = {0.86, 0.72, 1.0}
    flashDuration = 0.2
    flashTimer = flashDuration
end

local function toggleHudEasterEgg()
    showTesterHUD = not showTesterHUD
    showHistoryToast(showTesterHUD and "Easter Egg: HUD On" or "Easter Egg: HUD Off")
    logInfo("Easter egg triggered: HUD toggle -> " .. tostring(showTesterHUD))
end

local function runEasterEggAction(action)
    if action == "random_drop" then
        triggerRandomEasterEgg()
    elseif action == "party" then
        triggerPartyEasterEgg()
    elseif action == "boom" then
        triggerBoomEasterEgg()
    elseif action == "tiny" then
        triggerTinyEasterEgg()
    elseif action == "hud" then
        toggleHudEasterEgg()
    end
end

function handleSecretCodeInput(key)
    if gameState ~= STATE_WORLD then return end
    if type(SECRET_CODES) ~= "table" then return end
    for _, code in ipairs(SECRET_CODES) do
        local seq = code.sequence
        if type(seq) == "table" and #seq > 0 then
            local id = code.id or tostring(_)
            local progress = secretCodeProgress[id] or 1
            local expected = seq[progress]
            if key == expected then
                progress = progress + 1
                if progress > #seq then
                    progress = 1
                    runEasterEggAction(code.action)
                end
            elseif key == seq[1] then
                progress = 2
            else
                progress = 1
            end
            secretCodeProgress[id] = progress
        end
    end
end

function getDefaultControlHints()
    return {
        pan=false, zoom=false, select=false, box=false, ball=false,
        move=false, rotate=false, magnet=false, copy=false, paste=false,
        slowmo=false, pause=false,
        magnetRadius=false, magnetStrength=false,
        dragForce=false,
        weld=false, spring=false, rope=false
    }
end

function syncTutorialSkipFlag()
    tutorialSkipped = true
    for _, done in pairs(controlHints) do
        if not done then
            tutorialSkipped = false
            break
        end
    end
end

function completeTutorialHints()
    for key, _ in pairs(controlHints) do
        controlHints[key] = true
    end
    tutorialSkipped = true
    showHistoryToast("Tutorial Skipped")
    logLine("Tutorial skipped by user")
end

function buildWorldDataSnapshot()
    local objects = {}
    local objectIndex = {}

    for i, obj in ipairs(bodies) do
        local vx, vy = obj.body:getLinearVelocity()

        local entry = {
            type = obj.shape:typeOf("CircleShape") and "ball" or "box",
            x = obj.body:getX(),
            y = obj.body:getY(),
            angle = obj.body:getAngle(),
            vx = vx,
            vy = vy,
            av = obj.body:getAngularVelocity(),

            color = { obj.color[1], obj.color[2], obj.color[3] },

            restitution = obj.fixture:getRestitution(),
            friction    = obj.fixture:getFriction(),
            density     = obj.fixture:getDensity(),

            frozen = obj.frozen == true,
            collisionsEnabled = obj.collisionsEnabled ~= false
        }

        if entry.type == "ball" then
            entry.radius = obj.shape:getRadius()
        else
            local pts = { obj.shape:getPoints() }
            entry.w = math.abs(pts[3] - pts[1])
            entry.h = math.abs(pts[6] - pts[2])
        end

        table.insert(objects, entry)
        objectIndex[obj] = i
    end

    local savedJoints = {}
    for _, link in ipairs(joints) do
        if link.joint and not link.joint:isDestroyed() then
            local aIndex = objectIndex[link.objA]
            local bIndex = objectIndex[link.objB]

            if aIndex and bIndex then
                local ax, ay, bx, by = link.joint:getAnchors()
                table.insert(savedJoints, {
                    kind = link.kind,
                    aIndex = aIndex,
                    bIndex = bIndex,
                    ax = ax, ay = ay,
                    bx = bx, by = by,
                    weldMode = link.weldMode,
                    weldRigidity = link.weldRigidity,
                    frequency = link.frequency,
                    damping = link.damping,
                    maxLength = link.maxLength,
                })
            end
        end
    end

    return { objects = objects, joints = savedJoints }
end

function applyWorldDataSnapshot(data)
    if not data or not data.objects then return end

    historySuspended = true
    clearWorld()

    for _, entry in ipairs(data.objects) do
        local obj

        if entry.w == 0 or entry.h == 0 then
            entry.w = 1
            entry.h = 1
        end

        if entry.type == "ball" then
            spawnBall(entry.x, entry.y, entry.radius)
            obj = bodies[#bodies]
        else
            spawnBox(entry.x, entry.y, entry.w, entry.h)
            obj = bodies[#bodies]
        end

        obj.body:setAngle(entry.angle or 0)
        obj.body:setLinearVelocity(entry.vx or 0, entry.vy or 0)
        obj.body:setAngularVelocity(entry.av or 0)

        obj.color = entry.color or {1,1,1}

        obj.fixture:setRestitution(entry.restitution or 0.2)
        obj.fixture:setFriction(entry.friction or 0.8)
        setObjectDensity(obj, entry.density or 1.0)
        obj.collisionsEnabled = (entry.collisionsEnabled ~= false)
        obj.fixture:setSensor(not obj.collisionsEnabled)

        if entry.frozen then
            obj.frozen = true
            obj.body:setType("static")
            obj.originalType = "static"
        end
    end

    if data.joints then
        for _, j in ipairs(data.joints) do
            local objA = bodies[j.aIndex or 0]
            local objB = bodies[j.bIndex or 0]
            if objA and objB and j.kind then
                createJointLink(
                    j.kind,
                    objA,
                    objB,
                    j.ax or objA.body:getX(),
                    j.ay or objA.body:getY(),
                    j.bx or objB.body:getX(),
                    j.by or objB.body:getY(),
                    {
                        weldMode = j.weldMode or "point",
                        weldRigidity = normalizeWeldRigidity(j.weldRigidity),
                        frequency = j.frequency or springFrequency,
                        damping = j.damping or springDamping,
                        maxLength = j.maxLength
                    }
                )
            end
        end
    end

    clearAllSelection()
    selectedJoint = nil
    historySuspended = false
end

function pushUndoState()
    if historySuspended then return end
    table.insert(undoStack, buildWorldDataSnapshot())
    if #undoStack > MAX_HISTORY then
        table.remove(undoStack, 1)
    end
    redoStack = {}
end

function showHistoryToast(text)
    historyToastText = text
    historyToastTimer = 1.2
end

function undoAction()
    if #undoStack == 0 then return end
    local previous = table.remove(undoStack)
    table.insert(redoStack, buildWorldDataSnapshot())
    applyWorldDataSnapshot(previous)
    showHistoryToast("Undo")
    logLine(string.format("Undo applied | undo=%d redo=%d", #undoStack, #redoStack))
end

function redoAction()
    if #redoStack == 0 then return end
    local nextState = table.remove(redoStack)
    table.insert(undoStack, buildWorldDataSnapshot())
    applyWorldDataSnapshot(nextState)
    showHistoryToast("Redo")
    logLine(string.format("Redo applied | undo=%d redo=%d", #undoStack, #redoStack))
end

function saveWorld(worldName)
    if not worldName then
        logInfo("saveWorld called with nil worldName")
        return
    end

    worldName = sanitizeWorldName(worldName)
    currentWorldName = worldName

    local worldDir = getWorldDir(worldName)
    love.filesystem.createDirectory(worldDir)

    local worldPath = worldDir .. "world.lua"
    local metaPath  = worldDir .. "meta.lua"

    local objects = {}
    local objectIndex = {}

    for i, obj in ipairs(bodies) do
        local vx, vy = obj.body:getLinearVelocity()

        local entry = {
            type = obj.shape:typeOf("CircleShape") and "ball" or "box",
            x = obj.body:getX(),
            y = obj.body:getY(),
            angle = obj.body:getAngle(),
            vx = vx,
            vy = vy,
            av = obj.body:getAngularVelocity(),

            color = { obj.color[1], obj.color[2], obj.color[3] },

            restitution = obj.fixture:getRestitution(),
            friction    = obj.fixture:getFriction(),
            density     = obj.fixture:getDensity(),

            frozen = obj.frozen == true,
            collisionsEnabled = obj.collisionsEnabled ~= false
        }

        if entry.type == "ball" then
            entry.radius = obj.shape:getRadius()
        else
            local pts = { obj.shape:getPoints() }
            entry.w = math.abs(pts[3] - pts[1])
            entry.h = math.abs(pts[6] - pts[2])
        end

        table.insert(objects, entry)
        objectIndex[obj] = i
    end

    local savedJoints = {}
    for _, link in ipairs(joints) do
        if link.joint and not link.joint:isDestroyed() then
            local aIndex = objectIndex[link.objA]
            local bIndex = objectIndex[link.objB]

            if aIndex and bIndex then
                local ax, ay, bx, by = link.joint:getAnchors()
                table.insert(savedJoints, {
                    kind = link.kind,
                    aIndex = aIndex,
                    bIndex = bIndex,
                    ax = ax, ay = ay,
                    bx = bx, by = by,
                    weldMode = link.weldMode,
                    weldRigidity = link.weldRigidity,
                    frequency = link.frequency,
                    damping = link.damping,
                    maxLength = link.maxLength,
                })
            end
        end
    end

    -- Write world.lua
    local worldChunk = "return { objects = " .. tableToString(objects) .. ", joints = " .. tableToString(savedJoints) .. " }"
    love.filesystem.write(worldPath, worldChunk)

    -- Load old meta if exists (to preserve created time)
    local createdTime = os.time()
    if love.filesystem.getInfo(metaPath) then
        local ok, oldChunk = pcall(love.filesystem.load, metaPath)
        if ok and oldChunk then
            local old = oldChunk()
            if old and old.created then
                createdTime = old.created
            end
        end
    end

    -- Write meta.lua
    local meta = {
        name = worldName,
        ctrlHints = controlHints,
        tutorialSkipped = tutorialSkipped == true,
        created = createdTime,
        modified = os.time(),
        objectCount = #bodies,
        playtime = 0
    }

    local metaChunk = "return " .. tableToString(meta)
    love.filesystem.write(metaPath, metaChunk)

    logInfo(string.format("World saved: %s (objects=%d joints=%d)", worldDir, #objects, #savedJoints))
end

function loadWorld(worldPath)
    if not love.filesystem.getInfo(worldPath) then
        logInfo("No save file: " .. tostring(worldPath))
        return
    end

    local ok, chunk = pcall(love.filesystem.load, worldPath)
    if not ok or not chunk then
        logInfo("Failed to load world chunk: " .. tostring(worldPath))
        return
    end

    local ok2, data = pcall(chunk)
    if not ok2 or not data or not data.objects then
        logInfo("Invalid world data: " .. tostring(worldPath))
        return
    end

    applyWorldDataSnapshot(data)

    -- Load tutorial/control hint progress from world meta.
    local metaPath = worldPath:gsub("world%.lua$", "meta.lua")
    controlHints = getDefaultControlHints()
    if love.filesystem.getInfo(metaPath) then
        local okMeta, metaChunk = pcall(love.filesystem.load, metaPath)
        if okMeta and metaChunk then
            local okMetaData, meta = pcall(metaChunk)
            if okMetaData and type(meta) == "table" and type(meta.ctrlHints) == "table" then
                for k, v in pairs(meta.ctrlHints) do
                    controlHints[k] = v
                end
            end
            if okMetaData and type(meta) == "table" and meta.tutorialSkipped ~= nil then
                tutorialSkipped = (meta.tutorialSkipped == true)
            else
                syncTutorialSkipFlag()
            end
        end
    else
        syncTutorialSkipFlag()
    end

    undoStack = {}
    redoStack = {}

    local loadedJointCount = data.joints and #data.joints or 0
    logInfo(string.format("World loaded: %s (objects=%d joints=%d)", worldPath, #data.objects, loadedJointCount))
end

function clearWorld()
    cancelEdgeWeldDrag()
    for _, obj in ipairs(bodies) do
        if obj.body then
            obj.body:destroy()
        end
    end
    bodies = {}
    selectedObjects = {}
    joints = {}
    jointLinkStart = nil
    selectedJoint = nil
end

function resetWorld()
    -- Clear old physics + objects
    clearWorld()

    -- Recreate physics world
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)

    -- Reset lists
    bodies = {}
    selectedObjects = {}

    -- Reset save name
    currentWorldName = nil
    autoSaveTimer = 0
    undoStack = {}
    redoStack = {}

    -- Reset tools/state
    currentTool = TOOL_SELECT
    mouseJoint = nil
    dragging = false
    selecting = false
    joints = {}
    jointLinkStart = nil
    selectedJoint = nil
    edgeWeldDrag.active = false
    edgeWeldDrag.obj = nil
    edgeWeldDrag.candidate = nil
    edgeWeldDrag.dist = math.huge

    -- Reset camera
    camX, camY = 0, 0
    camScale = 1

    -- Recreate ground
    ground = {}
    ground.body = love.physics.newBody(world, 400, 2550, "static")
    ground.shape = love.physics.newRectangleShape(80000, 4000)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
end

function getWorldDir(worldName)
    worldName = sanitizeWorldName(worldName)
    return SAVE_DIR .. worldName .. "/"
end

function deleteWorld(worldName)
    worldName = sanitizeWorldName(worldName)
    local dir = getWorldDir(worldName)

    if not love.filesystem.getInfo(dir) then
        print("World folder not found:", dir)
        return
    end

    -- delete files inside
    love.filesystem.remove(dir .. "world.lua")
    love.filesystem.remove(dir .. "meta.lua")

    -- remove folder
    love.filesystem.remove(dir)

    print("Deleted world:", worldName)

    refreshSaveCache()
end

function tableToString(t, indent)
    indent = indent or 0
    local s = "{\n"

    for k, v in pairs(t) do
        local key
        if type(k) == "number" then
            key = ""
        else
            key = tostring(k) .. " = "
        end

        s = s .. string.rep(" ", indent + 2) .. key

        if type(v) == "table" then
            s = s .. tableToString(v, indent + 2)
        elseif type(v) == "string" then
            s = s .. string.format("%q", v)
        else
            s = s .. tostring(v)
        end

        s = s .. ",\n"
    end

    s = s .. string.rep(" ", indent) .. "}"
    return s
end

function getSaveFiles()
    local files = love.filesystem.getDirectoryItems(SAVE_DIR)
    local saves = {}

    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            table.insert(saves, file)
        end
    end

    return saves
end

function refreshSaveCache()
    saveCache = {}

    local folders = love.filesystem.getDirectoryItems(SAVE_DIR)

    for _, folder in ipairs(folders) do
        local worldPath = SAVE_DIR .. folder .. "/world.lua"
        local metaPath  = SAVE_DIR .. folder .. "/meta.lua"

        if love.filesystem.getInfo(worldPath) then
            local meta = {
                name = folder,
                modified = 0,
                objectCount = 0
            }

            if love.filesystem.getInfo(metaPath) then
                local ok, chunk = pcall(love.filesystem.load, metaPath)
                if ok and chunk then
                    local ok2, data = pcall(chunk)
                    if ok2 and type(data) == "table" then
                        meta = data
                    end
                end
            end

            table.insert(saveCache, {
                file = folder,   -- folder name
                meta = meta
            })
        end
    end

    table.sort(saveCache, function(a,b)
        return (a.meta.modified or 0) > (b.meta.modified or 0)
    end)
end

function saveSettings()
    local data = "return {\n"
    for k, v in pairs(settings) do
        if type(v) == "string" then
            data = data .. string.format('  %s = "%s",\n', k, v)
        else
            data = data .. string.format('  %s = %s,\n', k, tostring(v))
        end
    end
    data = data .. "}\n"

    love.filesystem.write(SETTINGS_FILE, data)
    logInfo("[Settings] Saved")
end

function loadSettings()
    if not love.filesystem.getInfo(SETTINGS_FILE) then
        logInfo("[Settings] No settings file, using defaults")
        return
    end

    local chunk = love.filesystem.load(SETTINGS_FILE)
    local loaded = chunk()

    if type(loaded) == "table" then
        for k, v in pairs(loaded) do
            settings[k] = v
        end
        logInfo("[Settings] Loaded")
    end
end

function saveControls()
    local chunk = "return " .. tableToString(controls)
    love.filesystem.write(CONTROLS_FILE, chunk)
    logLine("Controls saved")
end

function loadControls()
    if not love.filesystem.getInfo(CONTROLS_FILE) then
        logLine("No controls file, using defaults")
        return
    end

    local ok, chunk = pcall(love.filesystem.load, CONTROLS_FILE)
    if not ok or not chunk then
        logLine("Failed to load controls file")
        return
    end

    local ok2, loaded = pcall(chunk)
    if ok2 and type(loaded) == "table" then
        for k, v in pairs(loaded) do
            if type(v) == "string" then
                controls[k] = v
            end
        end
        logLine("Controls loaded")
    else
        logLine("Invalid controls table")
    end
end

function getDefaultControls()
    return {
        tool_select = "1",
        tool_move = "2",
        tool_ball = "3",
        tool_box = "4",
        tool_drag = "5",
        tool_freeze = "6",
        tool_magnet = "7",
        tool_weld = "8",
        tool_spring = "9",
        tool_rope = "r",
        undo = "z",
        redo = "y",
        delete_selected = "delete",
        pause = "p",
        slowmo = "space",
        reset_zoom = "0",
        weld_mode_toggle = "x",
        toggle_ui = "tab"
    }
end

function logLine(msg)
    local line = string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), tostring(msg))
    pcall(function()
        if LOG_DIR then
            love.filesystem.createDirectory(LOG_DIR)
        end
        love.filesystem.append(LOG_FILE or "logs/latest.log", line)
    end)
end

function logInfo(msg)
    local text = tostring(msg)
    print(text)
    logLine(text)
end

function love.quit()
    DiscordPresence.shutdown()
end

function love.errorhandler(msg)
    local trace = debug.traceback(tostring(msg), 2)
    logLine("CRASH: " .. trace)
    return love.errhand(msg)
end


function sanitizeWorldName(name)
    if not name then return "World" end

    -- remove any slashes or folders
    name = name:gsub("[/\\]", "")
    name = name:gsub("^saves", "")
    name = name:gsub("^SAVE", "")

    if name == "" then
        name = "World"
    end

    return name
end

function getObjectBounds(obj)
    local x,y = obj.body:getPosition()

    if obj.shapeType == "box" then
        local w = obj.width
        local h = obj.height
        return x - w/2, y - h/2, w, h
    end

    if obj.shapeType == "ball" then
        local d = obj.radius * 2
        return x - obj.radius, y - obj.radius, d, d
    end

    return nil
end

function getResizeHandles(obj)
    local handles = {}

    if obj.shapeType == "box" then
        local hw = obj.width * 0.5
        local hh = obj.height * 0.5
        local body = obj.body

        local tlx, tly = body:getWorldPoint(-hw, -hh)
        local trx, try_ = body:getWorldPoint(hw, -hh)
        local blx, bly = body:getWorldPoint(-hw, hh)
        local brx, bry = body:getWorldPoint(hw, hh)

        handles = {
            {tlx, tly, "tl"},
            {trx, try_, "tr"},
            {blx, bly, "bl"},
            {brx, bry, "br"},
        }
    elseif obj.shapeType == "ball" then
        local x, y = obj.body:getPosition()
        handles = {
            {x + obj.radius, y, "radius"},
        }
    end

    return handles
end

function drawResizeHandles(obj)
    local handles = getResizeHandles(obj)
    if #handles == 0 then return end

    local handleRadius = (HANDLE_SIZE * 0.5) / camScale
    local borderRadius = handleRadius + (1 / camScale)

    if obj.shapeType == "ball" then
        local cx, cy = obj.body:getPosition()
        local hx, hy = handles[1][1], handles[1][2]

        love.graphics.setColor(0.15, 0.95, 1, 0.55)
        love.graphics.setLineWidth(2 / camScale)
        love.graphics.line(cx, cy, hx, hy)
    end

    for _,c in ipairs(handles) do
        local sx,sy = c[1], c[2]

        love.graphics.setColor(0, 0, 0, 0.95)
        love.graphics.circle("fill", sx, sy, borderRadius)

        love.graphics.setColor(0.15, 0.95, 1, 1)
        love.graphics.circle("fill", sx, sy, handleRadius)
    end

    love.graphics.setLineWidth(1)
end

function spawnObjectFromData(data, offsetX, offsetY)
    local body = love.physics.newBody(
        world,
        data.x + (offsetX or 20),
        data.y + (offsetY or 20),
        "dynamic"
    )

    body:setAngle(data.angle)

    local shape
    if data.shapeType == "CircleShape" then
        shape = love.physics.newCircleShape(data.radius)
    else
        -- fallback box (if you only support boxes for now)
        shape = love.physics.newRectangleShape(40, 40)
    end

    local fix = love.physics.newFixture(body, shape, data.density)
    fix:setRestitution(data.restitution)
    fix:setFriction(data.friction)
    local collisionsEnabled = (data.collisionsEnabled ~= false)
    fix:setSensor(not collisionsEnabled)

    local obj = {
        body = body,
        shape = shape,
        fixture = fix,
        color = {data.color[1], data.color[2], data.color[3]},
        frozen = data.frozen,
        collisionsEnabled = collisionsEnabled,
    }

    if data.frozen then
        body:setType("static")
    end

    table.insert(bodies, obj)
    return obj
end

function getNextHint()
    if tutorialSkipped then
        return nil
    end

    if not controlHints.pan then
        return "Hold Middle Mouse to Pan Camera"
    end
    if not controlHints.zoom then
        return "Scroll Mouse Wheel to Zoom"
    end
    if not controlHints.select then
        return "Press 1 to Select Objects"
    end
    if not controlHints.box then
        return "Press 4 and Drag to Create Boxes"
    end
    if not controlHints.ball then
        return "Press 3 and Drag to Create Balls"
    end
    if not controlHints.move then
        return "Press 2 to Move Objects"
    end
    if not controlHints.rotate then
        return "Hold Q / E to Rotate Selection"
    end
    if not controlHints.drag then
        return "Press 5 to Drag Objects"
    end
    if not controlHints.dragForce then
        return "Adjust Drag Force: N / M"
    end
    if not controlHints.copy then
        return "Ctrl+C to Copy Selection"
    end
    if not controlHints.paste then
        return "Ctrl+V to Paste at Mouse"
    end
    if not controlHints.magnet then
        return "Press 7 to Use Magnet Tool"
    end
    if not controlHints.magnetRadius then
        return "Magnet Radius: Hold CTRL + Scroll"
    end
    if not controlHints.magnetStrength then
        return "Magnet Strength: Hold SHIFT + Scroll"
    end
    if not controlHints.weld then
        return "Press 8 for Weld Tool (click body A then B)"
    end
    if not controlHints.spring then
        return "Press 9 for Spring Tool (click body A then B)"
    end
    if not controlHints.rope then
        return "Press R for Rope Tool (click body A then B)"
    end
    if not controlHints.slowmo then
        return "Press Space for Slow Motion"
    end
    if not controlHints.pause then
        return "Press P to Pause Time"
    end

    return nil -- tutorial done 😈
end

function flash(obj, color, duration)
    obj.flashTimer = duration or 0.25
    obj.flashDuration = duration or 0.25

    if color then
        obj.flashColor = {color[1], color[2], color[3]}
    else
        obj.flashColor = {0, 1, 0} -- default green
    end
end

function toggleFreeze(obj)
    if obj.frozen then
        obj.frozen = false
        obj.body:setType("dynamic")
        obj.originalType = "dynamic"
    else
        obj.frozen = true
        obj.body:setType("static")
        obj.originalType = "static"
        obj.body:setLinearVelocity(0,0)
        obj.body:setAngularVelocity(0)
    end
end

function drawBody(obj)
    local body = obj.body
    local shape = obj.shape

    if shape:typeOf("CircleShape") then
        local x,y = body:getPosition()
        love.graphics.circle("fill", x, y, shape:getRadius())
    else
        love.graphics.polygon("fill", body:getWorldPoints(shape:getPoints()))
    end
end
