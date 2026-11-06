-- Project Golf - sandbox options (media/sandbox-options.txt, page "Project Golf").
-- PG.sandbox(name, default) reads SandboxVars.ProjectGolf.<name>, falling back to the default when unset.

require "ProjectGolf/PG_Config"

local PG = ProjectGolf

function PG.sandbox(name, default)
    local sv = SandboxVars and SandboxVars.ProjectGolf
    if sv and sv[name] ~= nil then return sv[name] end
    return default
end
