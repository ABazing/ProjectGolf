-- Project Golf - one code path for single player, hosted and dedicated servers.
-- Single player has no server: commands are delivered straight to the handler tables instead of the network.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Sandbox"

local PG = ProjectGolf
PG.ServerCommands = PG.ServerCommands or {}   -- filled in server/ProjectGolf/PG_Server.lua
PG.ClientCommands = PG.ClientCommands or {}   -- filled in client/ProjectGolf/PG_Client.lua

function PG.isSinglePlayer()
    return not isClient() and not isServer()
end

-- client -> server
function PG.sendToServer(player, command, args)
    if isClient() then
        sendClientCommand(player, PG.MOD_ID, command, args)
    else
        local handler = PG.ServerCommands[command]
        if handler then handler(player, args) end
    end
end

-- server -> every client
function PG.broadcast(command, args)
    if isServer() then
        sendServerCommand(PG.MOD_ID, command, args)
    else
        local handler = PG.ClientCommands[command]
        if handler then handler(args) end
    end
end

-- server -> one client
function PG.sendToPlayer(player, command, args)
    if isServer() then
        sendServerCommand(player, PG.MOD_ID, command, args)
    else
        local handler = PG.ClientCommands[command]
        if handler then handler(args) end
    end
end

function PG.now()
    return getTimestampMs()
end
