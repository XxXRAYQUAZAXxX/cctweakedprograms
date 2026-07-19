-- Makes this computer connectable from a remote_controller computer over
-- rednet -- an in-game equivalent of Cloud Catcher, no internet needed.
--
-- Usage:
--   remote_agent                  -- wraps the normal interactive shell
--   remote_agent -- <program> ... -- wraps a specific program instead
--                                    (e.g. your flight computer's startup)
--
-- Protocol "ccremote":
--   {type="who"}                     controller broadcast -> agent replies {type="here", id, label, busy}
--   {type="connect"}                 controller requests a session
--   {type="connected", w, h}         agent confirms, session begins
--   {type="event", event={...}}      controller forwards a local input event to inject here
--   {type="term", call=, args={}}    agent forwards a terminal draw call
--   {type="disconnect"}              either side ends the session

local PROTOCOL = "ccremote"

local rawArgs = { ... }
local wrappedProgram = nil
for i, a in ipairs(rawArgs) do
    if a == "--" then
        wrappedProgram = {}
        for j = i + 1, #rawArgs do table.insert(wrappedProgram, rawArgs[j]) end
        break
    end
end

local function openModem()
    local modem = peripheral.find("modem")
    if not modem then error("No modem found -- attach a wired or wireless modem.") end
    local name = peripheral.getName(modem)
    if not rednet.isOpen(name) then rednet.open(name) end
end

openModem()

local label = os.getComputerLabel() or ("Computer " .. os.getComputerID())
local connectedController = nil

-- Wraps the real terminal: every draw call still happens locally (so
-- someone standing at the computer sees the same thing) and is also
-- forwarded to whichever controller is currently connected.
local function makeProxyTerm(sendFn)
    local real = term.current()
    local proxy = {}

    local writeMethods = {
        "write", "scroll", "setCursorPos", "setCursorBlink", "clear", "clearLine",
        "setTextColor", "setTextColour", "setBackgroundColor", "setBackgroundColour", "blit",
    }
    for _, m in ipairs(writeMethods) do
        proxy[m] = function(...)
            real[m](...)
            sendFn(m, { ... })
        end
    end

    local readMethods = {
        "getCursorPos", "getSize", "isColor", "isColour",
        "getTextColor", "getTextColour", "getBackgroundColor", "getBackgroundColour",
    }
    for _, m in ipairs(readMethods) do
        proxy[m] = function(...) return real[m](...) end
    end

    return proxy
end

local function announceLoop()
    while true do
        local sender, msg = rednet.receive(PROTOCOL)
        if type(msg) == "table" then
            if msg.type == "who" then
                rednet.send(sender, {
                    type = "here", id = os.getComputerID(), label = label,
                    busy = connectedController ~= nil,
                }, PROTOCOL)
            elseif msg.type == "connect" and not connectedController then
                connectedController = sender
                local w, h = term.getSize()
                rednet.send(sender, { type = "connected", w = w, h = h }, PROTOCOL)
            elseif msg.type == "event" and sender == connectedController then
                os.queueEvent(table.unpack(msg.event))
            elseif msg.type == "disconnect" and sender == connectedController then
                connectedController = nil
            end
        end
    end
end

local function targetProgram()
    if wrappedProgram then
        shell.run(table.unpack(wrappedProgram))
    else
        shell.run("shell")
    end
end

local oldTerm = term.current()
local proxy = makeProxyTerm(function(call, callArgs)
    if connectedController then
        rednet.send(connectedController, { type = "term", call = call, args = callArgs }, PROTOCOL)
    end
end)
term.redirect(proxy)

local ok, err = pcall(parallel.waitForAny, announceLoop, targetProgram)

term.redirect(oldTerm)
if not ok then error(err, 0) end
