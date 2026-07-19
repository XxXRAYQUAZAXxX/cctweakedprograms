-- Pocket computer program launcher.
-- Arrow keys to move, Enter to launch, Ctrl+T to back out of whatever's
-- running, Q to quit to the normal shell.
--
-- Runs entirely under agent_lib's background service, so this computer
-- stays discoverable/connectable via remote_controller the whole time --
-- whether you're sitting at the menu, running the sniffer, or even acting
-- as a controller yourself. The instant a controller session here ends,
-- it's immediately visible/connectable again (the announce loop never stops).

local agentLib = require("agent_lib")

local programs = {
    { name = "Remote Controller", cmd = "remote_controller", color = colors.cyan },
    { name = "Rednet Sniffer",    cmd = "rednet_sniffer",    color = colors.lime },
    { name = "Shell",             cmd = "shell",             color = colors.lightGray },
}

local selected = 1

local function draw()
    local w, h = term.getSize()

    term.setBackgroundColor(colors.black)
    term.clear()

    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    local title = "PROGRAMS"
    term.setCursorPos(math.max(1, math.floor((w - #title) / 2) + 1), 1)
    term.write(title)
    term.setBackgroundColor(colors.black)

    for i, p in ipairs(programs) do
        local y = 2 + i
        term.setCursorPos(1, y)
        if i == selected then
            term.setBackgroundColor(p.color)
            term.setTextColor(colors.black)
            term.clearLine()
            term.setCursorPos(2, y)
            term.write("> " .. p.name)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(p.color)
            term.write("  " .. p.name)
        end
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(1, h)
    term.write("Enter=launch Ctrl+T=back Q=quit")
end

local function menuLoop()
    while true do
        draw()
        local event, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected - 1
            if selected < 1 then selected = #programs end
        elseif key == keys.down then
            selected = selected + 1
            if selected > #programs then selected = 1 end
        elseif key == keys.enter then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            local ok, err = pcall(shell.run, programs[selected].cmd)
            -- Ctrl+T raises "Terminated" -- that's the sanctioned "back to
            -- menu" gesture now, so don't show it as an error.
            if not ok and not tostring(err):find("Terminated") then
                print("Error: " .. tostring(err))
                print("Press any key to continue...")
                os.pullEvent("key")
            end
        elseif key == keys.q then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            return
        end
    end
end

agentLib.serve(menuLoop)
