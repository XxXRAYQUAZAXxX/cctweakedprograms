-- CC:Tweaked Programs Installer
-- Run with:
--   wget run https://raw.githubusercontent.com/XxXRAYQUAZAXxX/cctweakedprograms/main/install.lua

local BASE = "https://raw.githubusercontent.com/XxXRAYQUAZAXxX/cctweakedprograms/main/"

local function fetch(name, dest)
    print("Downloading " .. name .. "...")
    local ok = shell.run("wget", BASE .. name, dest or name)
    if not ok then
        print("Failed to download " .. name)
        return false
    end
    return true
end

local function writeStartup(command)
    local f = fs.open("/startup.lua", "w")
    f.write('shell.run("' .. command .. '")\n')
    f.close()
end

print("=== CC:Tweaked Programs Installer ===")
print("1) Remote Controller (connect to/control other computers)")
print("2) Remote Agent (make this computer remotely controllable)")
print("3) Pocket Menu (agent + controller, always connectable)")
write("Install which? (1/2/3): ")
local choice = read()

if choice == "1" then
    if fetch("remote_controller.lua") then
        print("Auto-start on boot? (y/n)")
        write("> ")
        if read():lower() == "y" then
            writeStartup("remote_controller")
        end
        print("Installed remote_controller. Run 'remote_controller' to use it.")
    end
elseif choice == "2" then
    if fetch("agent_lib.lua") and fetch("remote_agent.lua") then
        print("Auto-start on boot? (y/n)")
        write("> ")
        if read():lower() == "y" then
            writeStartup("remote_agent")
        end
        print("Installed remote_agent. Run 'remote_agent' to use it.")
    end
elseif choice == "3" then
    if fetch("agent_lib.lua") and fetch("remote_agent.lua") and fetch("remote_controller.lua")
        and fetch("menu.lua") then
        print("Auto-start on boot? (y/n)")
        write("> ")
        if read():lower() == "y" then
            writeStartup("menu")
        end
        print("Installed menu. Run 'menu' to use it.")
    end
else
    print("Invalid choice.")
end
