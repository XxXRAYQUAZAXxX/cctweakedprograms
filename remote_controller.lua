-- Connects to and controls any remote_agent computer over rednet.
-- Run this on the computer you want to use as your "control hub" (computer 1).

local PROTOCOL = "ccremote"

local function openModem()
    local modem = peripheral.find("modem")
    if not modem then error("No modem found -- attach a wired or wireless modem.") end
    local name = peripheral.getName(modem)
    if not rednet.isOpen(name) then rednet.open(name) end
end

openModem()

local function discover(timeout)
    rednet.broadcast({ type = "who" }, PROTOCOL)
    local found = {}
    local endTime = os.clock() + (timeout or 1.5)
    while os.clock() < endTime do
        local sender, msg = rednet.receive(PROTOCOL, endTime - os.clock())
        if type(msg) == "table" and msg.type == "here" then
            found[sender] = msg
        end
    end
    return found
end

local function chooseComputer()
    print("Searching for computers...")
    local found = discover(1.5)

    local list = {}
    for id, info in pairs(found) do
        table.insert(list, { id = id, label = info.label, busy = info.busy })
    end
    table.sort(list, function(a, b) return a.id < b.id end)

    if #list == 0 then
        print("No remote_agent computers found. Make sure the target is")
        print("running remote_agent and both have modems attached.")
        return nil
    end

    print("Found computers:")
    for i, c in ipairs(list) do
        print(("  %d) %s%s"):format(i, c.label, c.busy and " [busy]" or ""))
    end
    write("Connect to #: ")
    local n = tonumber(read())
    if n and list[n] then return list[n].id end
    return nil
end

local function runSession(targetId)
    rednet.send(targetId, { type = "connect" }, PROTOCOL)
    local sender, msg = rednet.receive(PROTOCOL, 3)
    if sender ~= targetId or type(msg) ~= "table" or msg.type ~= "connected" then
        print("Connection failed or timed out.")
        return
    end

    term.clear()
    term.setCursorPos(1, 1)
    print("Connected. Hold Ctrl+T to disconnect.")
    sleep(1)

    local running = true

    local function renderLoop()
        while running do
            local s, m = rednet.receive(PROTOCOL, 1)
            if s == targetId and type(m) == "table" then
                if m.type == "term" then
                    local fn = term[m.call]
                    if fn then fn(table.unpack(m.args)) end
                elseif m.type == "disconnect" then
                    running = false
                end
            end
        end
    end

    local function inputLoop()
        while running do
            -- pullEventRaw (not pullEvent) so we can catch "terminate"
            -- (Ctrl+T) ourselves instead of it killing the program outright.
            local event = { os.pullEventRaw() }
            local e = event[1]

            if e == "terminate" then
                running = false
            elseif e == "char" or e == "key" or e == "key_up" or e == "mouse_click"
                or e == "mouse_up" or e == "mouse_drag" or e == "mouse_scroll" or e == "paste" then
                rednet.send(targetId, { type = "event", event = event }, PROTOCOL)
            end
        end
    end

    parallel.waitForAny(renderLoop, inputLoop)

    rednet.send(targetId, { type = "disconnect" }, PROTOCOL)
    term.clear()
    term.setCursorPos(1, 1)
    print("Disconnected.")
end

while true do
    local id = chooseComputer()
    if id then
        runSession(id)
    else
        print("Try again? (y/n)")
        if read():lower() ~= "y" then break end
    end
end
