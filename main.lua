function love.load()
    WINDOW_W, WINDOW_H = 1000, 700
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

    currentTool = TOOL_SELECT

    dragForce = 10000

    rotateSpeed = 15 * 10000
    originalRS = rotateSpeed
    qDown = false
    eDown = false

    -- Properties panel
    PROPS_W = 200
    PROPS_H = 300
    PROPS_X = WINDOW_W - PROPS_W - 10
    PROPS_Y = WINDOW_H - PROPS_H - 10

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
    ZOOM_MIN = 0.25
    ZOOM_MAX = 3
    ZOOM_SPEED = 0.1

    timeScale = 1
    paused = false

    inSlowMotion = false
    slowMotionIcon = love.graphics.newImage("textures/Slow motion icon.png")

    outLimits = false

    -- Game States
    STATE_MENU = "menu"
    STATE_WORLD = "world"
    STATE_LOAD = "load"

    gameState = STATE_MENU
    
    SAVE_DIR = "saves/"
    love.filesystem.createDirectory(SAVE_DIR)

    currentWorldName = nil   -- like "my_world_1.lua"
    isNamingWorld = false
    worldNameInput = ""
    hoveredSaveIndex = nil

    AUTO_SAVE_INTERVAL = 60 -- seconds
    autoSaveTimer = 0

    -- Load Menu stuff
    loadMenuScroll = 0
    LOAD_ROW_HEIGHT = 34

    lastClickTime = 0
    DOUBLE_CLICK_TIME = 0.35
    lastClickedFile = nil

    loadSearch = ""

    saveCache = {} -- { filename, meta }



    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)

    bodies = {}

    -- Ground
    ground = {}
    ground.body = love.physics.newBody(world, 400, 2550, "static")
    ground.shape = love.physics.newRectangleShape(80000, 4000)
    ground.fixture = love.physics.newFixture(ground.body, ground.shape)
end

function love.update(dt)
    local scaledDt = dt * timeScale
    DT = scaledDt
    world:update(scaledDt)

    -- Rotation Logic/Tool
    if #selectedObjects > 0 then
        if qDown then
            rotateSpeed = rotateSpeed + math.rad(1)
            for _, obj in ipairs(selectedObjects) do
                local body = obj.body
                body:applyTorque(rotateSpeed)
                if currentTool == TOOL_MOVE then
                    body:setAngle(body:getAngle() + rotateSpeed * 0.00002 * scaledDt)
                end
            end
        end

        if eDown then
            rotateSpeed = rotateSpeed + math.rad(1)
            for _, obj in ipairs(selectedObjects) do
                local body = obj.body
                body:applyTorque(-rotateSpeed)
                if currentTool == TOOL_MOVE then
                    body:setAngle(body:getAngle() - rotateSpeed * 0.00002 * scaledDt)
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
            print("Auto-saved:", currentWorldName)
        end
    end
end

function love.resize(w, h)
    WINDOW_W = w
    WINDOW_H = h
    PROPS_X = WINDOW_W - PROPS_W - 10
    PROPS_Y = WINDOW_H - PROPS_H - 10
end

function love.draw()
    uiButtons = {}
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


    -- =====================
    -- WORLD (WORLD SPACE)
    -- =====================
    love.graphics.push()
    love.graphics.translate(camX, camY)
    love.graphics.scale(camScale)


    love.graphics.setColor(0.05, 0.05, 0.05)
    drawBody(ground)

    for _, obj in ipairs(bodies) do
        -- Always draw real color
        love.graphics.setColor(obj.color)
        drawBody(obj)

        -- Draw outline if selected
        if obj.selected then
            drawSelectionOutline(obj)
        end
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

    love.graphics.pop()

    -- =====================
    -- UI (SCREEN SPACE)
    -- =====================
    drawUI()

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

end

function love.mousepressed(x, y, button)
    -- Middle mouse = pan camera
    if button == 3 then
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
            btn.onClick()
            return
        end
    end

    -- =====================
    -- Load Menu Double Click
    -- =====================
    if gameState == STATE_LOAD and button == 1 then
        local panelW = math.floor(WINDOW_W * 0.6)
        local panelH = math.floor(WINDOW_H * 0.7)
        local panelX = math.floor((WINDOW_W - panelW) / 2)
        local panelY = math.floor((WINDOW_H - panelH) / 2)

        local listX = panelX + 20
        local listY = panelY + 60
        local listW = panelW - 40
        local rowH = 30
        local viewH = panelH - 120

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
                    loadWorld(SAVE_DIR .. file .. "/world.lua")
                    currentWorldName = file
                    autoSaveTimer = 0
                    gameState = STATE_WORLD

                    lastClickedFile = nil
                    lastClickTime = 0
                    return
                else
                    -- SINGLE CLICK (select row)
                    lastClickedFile = file
                    lastClickTime = now
                    return
                end
            end
        end

        -- Clicked empty space → clear selection
        lastClickedFile = nil
        lastClickTime = 0
    end


    local wx, wy = screenToWorld(x, y)


    if currentTool == TOOL_SELECT then
        local obj = getObjectAtPoint(wx, wy)
        local ctrl = love.keyboard.isDown("lctrl", "rctrl")

        if obj then
            -- Click select object
            selectObject(obj, ctrl)
        else
            -- Box select
            selecting = true
            selectStartX, selectStartY = wx, wy
            selectEndX, selectEndY = wx, wy

            if not ctrl then
                clearAllSelection()
            end
        end

    elseif currentTool == TOOL_MOVE then
        if #selectedObjects > 0 then
            draggingGroup = true
            dragOffset = {}
            for _, obj in ipairs(selectedObjects) do
                local bx, by = obj.body:getPosition()
                dragOffset[obj] = { x = bx - wx, y = by - wy }
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
            toggleFreeze(obj)
        end
    end

    if currentTool == TOOL_BOX or currentTool == TOOL_BALL then
        dragging = true
        dragStartX, dragStartY = wx, wy
        dragEndX, dragEndY = wx, wy
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

    if draggingGroup then
        for _, obj in ipairs(selectedObjects) do
            obj.body:setType(obj.originalType)
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
                spawnBox(cx, cy, w, h)
            end
        elseif currentTool == TOOL_BALL then
            local radius = math.sqrt(w*w + h*h) / 2
            if radius > 5 then
                spawnBall(cx, cy, radius)
            end
        end
    end
end

function love.wheelmoved(dx, dy)
    if dy == 0 then return end

    -- LOAD MENU SCROLL ONLY
    if gameState == STATE_LOAD then
        loadMenuScroll = loadMenuScroll + dy * 20
        return
    end

    -- WORLD ZOOM ONLY
    local mx, my = love.mouse.getPosition()
    local wx, wy = screenToWorld(mx, my)

    local oldScale = camScale
    camScale = math.max(ZOOM_MIN,
               math.min(ZOOM_MAX, camScale + dy * ZOOM_SPEED))

    local scaleFactor = camScale / oldScale

    camX = mx - wx * camScale
    camY = my - wy * camScale
end


function love.keypressed(key)
    -- Reset Zoom
    if key == "0" then
        camScale = 1
        camX, camY = 0, 0
    end

    -- Tools
    if key == "1" then currentTool = TOOL_SELECT end
    if key == "2" then currentTool = TOOL_MOVE end
    if key == "3" then currentTool = TOOL_BALL end
    if key == "4" then currentTool = TOOL_BOX end
    if key == "5" then currentTool = TOOL_DRAG end
    if key == "6" then currentTool = TOOL_FREEZE end

    -- Remove Selected Objects
    if key == "delete" then
        deleteSelectedObjects()
    end

    -- Pauses the time
    if key == "p" then
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
        dragForce = dragForce + 1000
        if mouseJoint then
            mouseJoint:setMaxForce(dragForce)
        end
    end

    if key == "m" then
        dragForce = dragForce - 1000
        if mouseJoint then
            mouseJoint:setMaxForce(dragForce)
        end
    end

    -- Rotate selected objects with Q / E
    if #selectedObjects > 0 then
        if key == "q" then
            qDown = true
        end

        if key == "e" then
            eDown = true
        end
    end

    if key == "space" then
        if not inSlowMotion then
            timeScale = 0.4
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
        gameState = STATE_MENU
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

    obj.color = {1, 1, 1}
    table.insert(bodies, obj)
end

function spawnBox(x, y, w, h)
    local obj = {}
    obj.body = love.physics.newBody(world, x, y, "dynamic")
    obj.shape = love.physics.newRectangleShape(w, h)
    obj.fixture = love.physics.newFixture(obj.body, obj.shape, 1)
    obj.fixture:setRestitution(0.2)
    obj.fixture:setFriction(0.8)
    obj.originalType = "dynamic"
    obj.fixture:setDensity(1.0)
    obj.body:resetMassData()

    obj.color = {1, 1, 1}
    table.insert(bodies, obj)
end

function getObjectAtPoint(x, y)
    for _, obj in ipairs(bodies) do
        if obj.fixture:testPoint(x, y) then
            return obj
        end
    end
    return nil
end

function doSelection()
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

-- =========================
-- Button Theme System
-- =========================

BUTTON_THEME = {
    normal = {
        bg = {0.25, 0.25, 0.25},
        hover = {0.35, 0.35, 0.35},
        border = {1,1,1},
        text = {1,1,1}
    },
    active = {
        bg = {0.2, 0.4, 0.8},
        hover = {0.3, 0.5, 1.0},
        border = {1,1,1},
        text = {1,1,1}
    },
    danger = {
        bg = {0.6, 0.15, 0.15},
        hover = {0.8, 0.2, 0.2},
        border = {1,1,1},
        text = {1,1,1}
    },
    disabled = {
        bg = {0.15, 0.15, 0.15},
        hover = {0.15, 0.15, 0.15},
        border = {0.5,0.5,0.5},
        text = {0.6,0.6,0.6}
    }
}

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

    table.insert(uiButtons, {
        x=x,y=y,w=w,h=h,
        onClick = (isDisabled and nil or onClick)
    })

    -- Background
    if hovered then
        love.graphics.setColor(hover)
    else
        love.graphics.setColor(bg)
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border
    love.graphics.setColor(border)
    love.graphics.rectangle("line", x, y, w, h)

    -- Text (centered & pixel-perfect)
    love.graphics.setColor(textCol)

    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local textH = font:getHeight()

    local textX = math.floor(x + (w - textW) / 2)
    local textY = math.floor(y + (h - textH) / 2)

    love.graphics.print(text, textX, textY)

end

function drawPropertiesPanel()
    love.graphics.setColor(0.15,0.15,0.15)
    love.graphics.rectangle("fill", PROPS_X, PROPS_Y, PROPS_W, PROPS_H)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", PROPS_X, PROPS_Y, PROPS_W, PROPS_H)

    love.graphics.print("Properties", PROPS_X+10, PROPS_Y+5)

    -- Out of Limits Toggle
    drawToggleButton("Out of Limits", PROPS_X+10, PROPS_Y-30, 180, 20, outLimits, function(v)
        outLimits = v
    end)

    if #selectedObjects == 0 then
        love.graphics.print("No selection", PROPS_X+10, PROPS_Y+30)
        return
    end

    -- MULTI
    if #selectedObjects > 1 then
        love.graphics.print("Selected: " .. #selectedObjects, PROPS_X+10, PROPS_Y+30)

        local y = PROPS_Y + 60

        drawButton("Freeze All", PROPS_X+10, y, 140, 20, function()
            for _, obj in ipairs(selectedObjects) do
                obj.frozen = true
                obj.body:setType("static")
                obj.originalType = "static"
                obj.body:setLinearVelocity(0,0)
                obj.body:setAngularVelocity(0)
            end
        end)

        y = y + 30

        drawButton("Unfreeze All", PROPS_X+10, y, 140, 20, function()
            for _, obj in ipairs(selectedObjects) do
                obj.frozen = false
                obj.body:setType("dynamic")
                obj.originalType = "dynamic"
            end
        end)

        y = y + 40

        drawButton("Bounce +", PROPS_X+10, y, 65, 20, function()
            for _, obj in ipairs(selectedObjects) do
                local r = obj.fixture:getRestitution()
                local new = r + 0.1
                if not outLimits then new = math.min(1, new) end
                obj.fixture:setRestitution(new)
            end
        end)

        drawButton("Bounce -", PROPS_X+85, y, 65, 20, function()
            for _, obj in ipairs(selectedObjects) do
                local r = obj.fixture:getRestitution()
                local new = r - 0.1
                if not outLimits then new = math.max(0, new) end
                obj.fixture:setRestitution(new)
            end
        end)

        y = y + 30

        drawButton("Fric +", PROPS_X+10, y, 65, 20, function()
            for _, obj in ipairs(selectedObjects) do
                local f = obj.fixture:getFriction()
                local new = f + 0.1
                if not outLimits then new = math.min(1, new) end
                obj.fixture:setFriction(new)
            end
        end)

        drawButton("Fric -", PROPS_X+85, y, 65, 20, function()
            for _, obj in ipairs(selectedObjects) do
                local f = obj.fixture:getFriction()
                local new = f - 0.1
                if not outLimits then new = math.max(0, new) end
                obj.fixture:setFriction(new)
            end
        end)

        y = y + 30

        drawButton("Mass +", PROPS_X + 10, y, 65, 20, function ()
            for _, obj in ipairs(selectedObjects) do
                local d = obj.fixture:getDensity()
                local new = d + 0.2
                if not outLimits then new = math.max(0.1, new) end
                setObjectDensity(obj, new)
            end
        end)

        drawButton("Mass -", PROPS_X + 85, y, 65, 20, function ()
            for _, obj in ipairs(selectedObjects) do
                local d = obj.fixture:getDensity()
                local new = d - 0.2
                if not outLimits then new = math.max(0.1, new) end
                setObjectDensity(obj, new)
            end
        end)

        y = y + 30

        drawButton("Delete ALL", PROPS_X + 10, y, 140, 20, function ()
            deleteSelectedObjects()
        end, { theme = "danger" })

        return
    end

    -- SINGLE
    local obj = selectedObjects[1]
    local fixture = obj.fixture
    local y = PROPS_Y + 30

    love.graphics.print("Frozen: " .. tostring(obj.frozen == true), PROPS_X+10, y)
    drawButton("Toggle", PROPS_X+110, y, 80, 20, function()
        toggleFreeze(obj)
    end)

    y = y + 30

    local rest = fixture:getRestitution()
    love.graphics.print(string.format("Bounce: %.2f", rest), PROPS_X+10, y)

    drawButton("-", PROPS_X+130, y, 20, 20, function()
        local new = rest - 0.1
        new = math.max(0, new)
        fixture:setRestitution(new)
    end)

    drawButton("+", PROPS_X+160, y, 20, 20, function()
        local new = rest + 0.1
        if not outLimits then new = math.min(1, new) end
        fixture:setRestitution(new)
    end)

    y = y + 30

    local fric = fixture:getFriction()
    love.graphics.print(string.format("Friction: %.2f", fric), PROPS_X+10, y)

    drawButton("-", PROPS_X+130, y, 20, 20, function()
        local new = fric - 0.1
        new = math.max(0, new)
        fixture:setFriction(new)
    end)

    drawButton("+", PROPS_X+160, y, 20, 20, function()
        local new = fric + 0.1
        if not outLimits then new = math.min(1, new) end
        fixture:setFriction(new)
    end)

    y = y + 30

    local density = fixture:getDensity()
    love.graphics.print(string.format("Density: %.2f", density), PROPS_X + 10, y)

    drawButton("-", PROPS_X + 130, y, 20, 20, function ()
        local new = density - 0.2
        new = math.max(0.1, new)
        setObjectDensity(obj, new)
    end)

    drawButton("+", PROPS_X + 160, y, 20, 20, function ()
        local new = density + 0.2
        if not outLimits then new = math.max(0.1, new) end
        setObjectDensity(obj, new)
    end)

    y = y + 30

    -- ---------------------
    -- Colors
    -- ---------------------
    love.graphics.print("Color: ", PROPS_X + 10, y)
    -- Color preview box
    love.graphics.setColor(obj.color)
    love.graphics.rectangle("fill", PROPS_X + 60, y - 5, 20, 20)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", PROPS_X + 60, y - 5, 20, 20)
    y = y + 25
    -- Red
    love.graphics.print("R", PROPS_X + 60, y)
    love.graphics.print(fmtColor(obj.color[1]), PROPS_X + 10, y)
    drawButton("+", PROPS_X + 130, y, 20, 20, function ()
        obj.color[1] = math.min(1, obj.color[1] + 0.1)
    end)
    drawButton("-", PROPS_X + 160, y, 20, 20, function ()
        obj.color[1] = math.max(0, obj.color[1] - 0.1)
    end)
    y = y + 25

    -- Green
    love.graphics.print("G", PROPS_X + 60, y)
    love.graphics.print(fmtColor(obj.color[2]), PROPS_X + 10, y)
    drawButton("+", PROPS_X + 130, y, 20, 20, function ()
        obj.color[2] = math.min(1, obj.color[2] + 0.1)
    end)
    drawButton("-", PROPS_X + 160, y, 20, 20, function ()
        obj.color[2] = math.max(0, obj.color[2] - 0.1)
    end)
    y = y + 25

    -- Blue
    love.graphics.print("B", PROPS_X + 60, y)
    love.graphics.print(fmtColor(obj.color[3]), PROPS_X + 10, y)
    drawButton("+", PROPS_X + 130, y, 20, 20, function ()
        obj.color[3] = math.min(1, obj.color[3] + 0.1)
    end)
    drawButton("-", PROPS_X + 160, y, 20, 20, function ()
        obj.color[3] = math.max(0, obj.color[3] - 0.1)
    end)
    y = y + 30


    drawButton("Delete", PROPS_X + 80, y, 100, 20, function ()
        if obj then
            deleteObject(obj)
            removeObjectFromList(obj)
            clearSelectionOf(obj)
            obj = nil
        end
    end, { theme = "danger" })
end

function fmtColor(v)
    return string.format("%.2f", v)
end

function drawToolsPanel()
    ToolButtonY = WINDOW_H - 30

    addToolButton("Select", 10, ToolButtonY, TOOL_SELECT, function ()
        currentTool = TOOL_SELECT
    end)

    addToolButton("Move", 80, ToolButtonY, TOOL_MOVE, function ()
        currentTool = TOOL_MOVE
    end)

    addToolButton("Ball", 150, ToolButtonY, TOOL_BALL, function ()
        currentTool = TOOL_BALL
    end)

    addToolButton("Box", 220, ToolButtonY, TOOL_BOX, function ()
        currentTool = TOOL_BOX
    end)

    addToolButton("Drag", 290, ToolButtonY, TOOL_DRAG, function ()
        currentTool = TOOL_DRAG
    end)

    addToolButton("Freeze", 360, ToolButtonY, TOOL_FREEZE, function ()
        currentTool = TOOL_FREEZE
    end)
end

function addToolButton(text, x, y, toolId, onClick)
    local w = 60
    local h = 30

    drawButton("", x, y, w, h, onClick, {
        active = (currentTool == toolId)
    })

    local font = love.graphics.getFont()
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
    for _, obj in ipairs(selectedObjects) do
        deleteObject(obj)
        removeObjectFromList(obj)
    end
    selectedObjects = {}
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

function drawUI()
    -- Tool UI
    local toolName = {
        [TOOL_SELECT] = "Select",
        [TOOL_MOVE] = "Move",
        [TOOL_BALL] = "Spawn Ball",
        [TOOL_BOX] = "Spawn Box",
        [TOOL_DRAG] = "Drag",
        [TOOL_FREEZE] = "Freeze"
    }

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tool: " .. toolName[currentTool], 10, 40)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)

    -- Controls, slow motion, tools, properties
    drawPropertiesPanel()
    drawToolsPanel()

    drawButton("", WINDOW_W / 2, 10, 30, 30, function ()
        if not inSlowMotion then
            timeScale = 0.4
            inSlowMotion = true
        else
            timeScale = 1.0
            inSlowMotion = false
        end
    end)

    love.graphics.draw(slowMotionIcon, (WINDOW_W / 2) - 3, 10, 0, 0.03, 0.03)

    -- Current world Name
    if currentWorldName then
        love.graphics.print("World: " .. currentWorldName, 10, 60)
    else
        love.graphics.print("World: (unsaved)", 10, 60)
    end

    if currentWorldName then
        local t = math.floor(AUTO_SAVE_INTERVAL - autoSaveTimer)
        love.graphics.print("Auto-save in: " .. t .. "s", 10, 80)
    end

end

function drawMainMenu()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    local cx = WINDOW_W / 2
    local y = 200

    love.graphics.setColor(1,1,1)
    love.graphics.printf("PHYSICS PLAYGROUND", 0, 100, WINDOW_W, "center")

    drawButton("New World", cx - 100, y, 200, 40, function()
        resetWorld()
        currentWorldName = nil
        autoSaveTimer = 0
        gameState = STATE_WORLD
    end)

    y = y + 60

    drawButton("Load World", cx - 100, y, 200, 40, function()
        refreshSaveCache()
        loadSearch = ""
        loadMenuScroll = 0
        gameState = STATE_LOAD
    end)

    y = y + 60

    drawButton("Quit", cx - 100, y, 200, 40, function()
        love.event.quit()
    end)
end

function drawLoadMenu()
    local panelW = math.floor(WINDOW_W * 0.6)
    local panelH = math.floor(WINDOW_H * 0.7)
    local panelX = math.floor((WINDOW_W - panelW) / 2)
    local panelY = math.floor((WINDOW_H - panelH) / 2)

    -- Panel BG
    love.graphics.setColor(0.12, 0.12, 0.12)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)

    -- Title
    local title = "Load World"
    local font = love.graphics.getFont()
    local titleW = font:getWidth(title)
    local titleX = math.floor(panelX + (panelW - titleW) / 2)
    local titleY = math.floor(panelY - 20)

    love.graphics.print(title, titleX, titleY)


    -- Search bar
    love.graphics.print("Search:", panelX + 120, panelY + 15)
    love.graphics.rectangle("line", panelX + 180, panelY + 12, 200, 24)
    love.graphics.print(loadSearch .. "_", panelX + 185, panelY + 16)


    -- Back Button
    drawButton("Back", panelX + 10, panelY + 10, 80, 28, function()
        gameState = STATE_MENU
    end)

    local filtered = {}

    for _, entry in ipairs(saveCache) do
        local name = entry.file:lower()
        if loadSearch == "" or name:find(loadSearch:lower(), 1, true) then
            table.insert(filtered, entry)
        end
    end


    local totalH = #filtered * LOAD_ROW_HEIGHT
    local viewH = panelH - 120

    if totalH < viewH then
        loadMenuScroll = 0
    else
        loadMenuScroll = math.max(viewH - totalH, math.min(0, loadMenuScroll))
    end

    local listX = panelX + 20
    local listY = panelY + 60
    local listW = panelW - 40
    local rowH = 30

    for i, entry in ipairs(filtered) do
        local file = entry.file
        local meta = entry.meta
        local x = listX
        local y = listY + (i-1) * LOAD_ROW_HEIGHT + loadMenuScroll
        local w = listW
        local h = rowH

        local mx, my = love.mouse.getPosition()
        local hovered = mx >= x and mx <= x+w and my >= y and my <= y+h

        if y + rowH >= listY and y <= listY + viewH then
            -- Row hover
            if hovered then
                love.graphics.setColor(0.22, 0.22, 0.22)
                love.graphics.rectangle("fill", x, y, w, h)
            end

            love.graphics.setColor(1,1,1)
            love.graphics.print(meta.name or file, x + 8, y + 4)

            local info = string.format(
                "Objects: %d   Modified: %s",
                meta.objectCount or 0,
                meta.modified and os.date("%Y-%m-%d %H:%M", meta.modified) or "?"
            )

            love.graphics.setColor(0.7,0.7,0.7)
            love.graphics.print(info, x + 8, y + 16)
            love.graphics.setColor(1,1,1)

            -- Delete button on hover
            if hovered then
                drawButton("Delete", x + w - 70, y, 70, h, function()
                    deleteWorld(file)
                end, { theme = "danger" })
            end
        end
    end

    if #filtered == 0 then
        love.graphics.print("No saves found.", listX, listY)
    end
end


function saveWorld(worldName)
    if not worldName then
        print("saveWorld called with nil worldName")
        return
    end

    worldName = sanitizeWorldName(worldName)
    currentWorldName = worldName

    local worldDir = getWorldDir(worldName)
    love.filesystem.createDirectory(worldDir)

    local worldPath = worldDir .. "world.lua"
    local metaPath  = worldDir .. "meta.lua"

    local objects = {}

    for _, obj in ipairs(bodies) do
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

            frozen = obj.frozen == true
        }

        if entry.type == "ball" then
            entry.radius = obj.shape:getRadius()
        else
            local pts = { obj.shape:getPoints() }
            entry.w = math.abs(pts[3] - pts[1])
            entry.h = math.abs(pts[6] - pts[2])
        end

        table.insert(objects, entry)
    end

    -- Write world.lua
    local worldChunk = "return { objects = " .. tableToString(objects) .. " }"
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
        created = createdTime,
        modified = os.time(),
        objectCount = #bodies,
        playtime = 0
    }

    local metaChunk = "return " .. tableToString(meta)
    love.filesystem.write(metaPath, metaChunk)

    print("World saved:", worldDir)
end

function loadWorld(worldPath)
    if not love.filesystem.getInfo(worldPath) then
        print("No save file:", worldPath)
        return
    end

    clearWorld()

    local ok, chunk = pcall(love.filesystem.load, worldPath)
    if not ok or not chunk then
        print("Failed to load world chunk:", worldPath)
        return
    end

    local ok2, data = pcall(chunk)
    if not ok2 or not data or not data.objects then
        print("Invalid world data:", worldPath)
        return
    end

    for _, entry in ipairs(data.objects) do
        local obj

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

        if entry.frozen then
            obj.frozen = true
            obj.body:setType("static")
            obj.originalType = "static"
        end
    end

    clearAllSelection()

    print("World loaded:", worldPath)
end

function clearWorld()
    for _, obj in ipairs(bodies) do
        if obj.body then
            obj.body:destroy()
        end
    end
    bodies = {}
    selectedObjects = {}
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

    -- Reset tools/state
    currentTool = TOOL_SELECT
    mouseJoint = nil
    dragging = false
    selecting = false

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
