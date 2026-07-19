-- Makes this computer connectable from a remote_controller computer over
-- rednet -- an in-game equivalent of Cloud Catcher, no internet needed.
--
-- Usage:
--   remote_agent                  -- wraps the normal interactive shell
--   remote_agent -- <program> ... -- wraps a specific program instead

-- Try the normal name first (regular installs), then the hidden dot-prefixed
-- name (used by discreet/hidden installs) as a fallback. dofile (not
-- require) for the hidden path -- require() treats "." as a module-path
-- separator, not a literal filename character, so it can't find a file
-- that's actually named ".agent_lib".
local ok, agentLib = pcall(require, "agent_lib")
if not ok then
    agentLib = dofile("/.agent_lib")
end

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
