-- Example script entrypoint for game-native Lua mod APIs.
-- Replace with functions/events supported by the game's official mod SDK.

local Mod = {}
Mod.id = "hello_mod"

function Mod.init(api)
    if api and api.log then
        api.log("[hello_mod] initialized")
    end
end

function Mod.shutdown(api)
    if api and api.log then
        api.log("[hello_mod] shutdown")
    end
end

return Mod
