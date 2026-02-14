local M = {}

local rpcLib = nil
local startedAt = os.time()
local initialized = false
local lastPayloadKey = nil
local nextUpdateAt = 0

local TOOL_NAME = {
    [1] = "Select",
    [2] = "Move",
    [3] = "Ball",
    [4] = "Box",
    [5] = "Drag",
    [6] = "Freeze",
    [7] = "Magnet",
    [8] = "Weld",
    [9] = "Spring",
    [10] = "Rope",
}

local function tryRequireDiscordLib()
    local candidates = {
        "discordRPC",
        "discord-rpc",
        "lib.discordRPC",
    }

    for _, name in ipairs(candidates) do
        local ok, lib = pcall(require, name)
        if ok and lib then
            return lib
        end
    end
    return nil
end

local function callSafe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[Discord RPC] " .. tostring(err))
    end
    return ok
end

local function buildPresence(ctx, cfg)
    local details = "In Game"
    if ctx.gameState == "menu" then
        details = "Main Menu"
    elseif ctx.gameState == "load" then
        details = "Browsing Worlds"
    elseif ctx.gameState == "settings" then
        details = "Settings"
    elseif ctx.paused then
        details = "Paused"
    end

    local tool = TOOL_NAME[ctx.currentTool] or "Tool"
    local state = string.format("%s | %d obj | %d joints", tool, ctx.objectCount or 0, ctx.jointCount or 0)
    if ctx.worldName and ctx.worldName ~= "" then
        state = string.format("%s | World: %s", state, tostring(ctx.worldName))
    end

    return {
        details = details,
        state = state,
        largeImageKey = cfg.large_image_key or "logo",
        largeImageText = cfg.large_image_text or "Physics Playground",
        startTimestamp = startedAt,
    }
end

local function payloadKey(p)
    return table.concat({
        p.details or "",
        p.state or "",
        p.largeImageKey or "",
        p.largeImageText or "",
        tostring(p.startTimestamp or 0),
    }, "|")
end

function M.init(cfg)
    cfg = cfg or {}
    local appId = tostring(cfg.application_id or "")
    if appId == "" then
        print("[Discord RPC] Disabled (no application_id).")
        return false
    end

    rpcLib = tryRequireDiscordLib()
    if not rpcLib then
        print("[Discord RPC] Library not found; running without RPC.")
        return false
    end

    local initFn = rpcLib.initialize or rpcLib.init
    if not initFn then
        print("[Discord RPC] Unsupported library API.")
        return false
    end

    if not callSafe(initFn, appId, true) then
        return false
    end

    initialized = true
    print("[Discord RPC] Initialized.")
    return true
end

function M.update(ctx)
    if not initialized or not rpcLib then return end
    ctx = ctx or {}

    local now = love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    if now < nextUpdateAt then return end

    local cfg = require("discord_presence_config")
    local p = buildPresence(ctx, cfg)
    local key = payloadKey(p)

    if key == lastPayloadKey then
        nextUpdateAt = now + 8
        return
    end

    local updateFn = rpcLib.updatePresence or rpcLib.update
    if updateFn then
        callSafe(updateFn, p)
        lastPayloadKey = key
    end

    local runCallbacksFn = rpcLib.runCallbacks
    if runCallbacksFn then
        callSafe(runCallbacksFn)
    end

    nextUpdateAt = now + 3
end

function M.shutdown()
    if not initialized or not rpcLib then return end
    local shutdownFn = rpcLib.shutdown
    if shutdownFn then
        callSafe(shutdownFn)
    end
    initialized = false
    rpcLib = nil
    print("[Discord RPC] Shutdown.")
end

return M
