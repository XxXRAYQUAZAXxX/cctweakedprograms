-- Shared "remote agent" service: makes this computer discoverable and
-- connectable by a remote_controller, mirroring whatever's currently on
-- screen. Used by remote_agent.lua (dedicated) and menu.lua (always-on,
-- so the computer stays connectable no matter what's running in front).

local PROTOCOL = "ccremote"

local function openModem()
    local modem = peripheral.find("modem")
    if not modem then error("No modem found -- attach a wired or wireless modem.") end
    local name = peripheral.getName(modem)
    if not rednet.isOpen(name) then rednet.open(name) end
end

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

-- Runs `foreground` (a zero-arg function -- whatever should actually be
-- driving the screen) while continuously advertising this computer and
-- accepting connections in the background. Returns/errors when `foreground`
-- does. Only one controller can be attached at a time; disconnecting
-- (gracefully or via the controller's Ctrl+T) makes this immediately
-- visible/connectable again, since the announce loop never stops running.
local function serve(foreground, label)
    openModem()
    label = label or (os.getComputerLabel() or ("Computer " .. os.getComputerID()))

    local connectedController = nil

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

    local oldTerm = term.current()
    local proxy = makeProxyTerm(function(call, callArgs)
        if connectedController then
            rednet.send(connectedController, { type = "term", call = call, args = callArgs }, PROTOCOL)
        end
    end)
    term.redirect(proxy)

    local ok, err = pcall(parallel.waitForAny, announceLoop, foreground)

    term.redirect(oldTerm)
    if not ok then error(err, 0) end
end

return { serve = serve, PROTOCOL = PROTOCOL }
