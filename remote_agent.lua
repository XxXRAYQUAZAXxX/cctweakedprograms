-- Makes this computer connectable from a remote_controller computer over
-- rednet -- an in-game equivalent of Cloud Catcher, no internet needed.
--
-- Usage:
--   remote_agent                  -- wraps the normal interactive shell
--   remote_agent -- <program> ... -- wraps a specific program instead

local agentLib = require("agent_lib")

local rawArgs = { ... }
local wrappedProgram = nil
for i, a in ipairs(rawArgs) do
    if a == "--" then
        wrappedProgram = {}
        for j = i + 1, #rawArgs do table.insert(wrappedProgram, rawArgs[j]) end
        break
    end
end

agentLib.serve(function()
    if wrappedProgram then
        shell.run(table.unpack(wrappedProgram))
    else
        shell.run("shell")
    end
end)
