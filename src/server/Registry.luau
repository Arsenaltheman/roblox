--!strict
-- Services look each other up here at runtime (Luau doesn't allow require cycles).
-- main.server.luau fills this before calling any init().
local Registry: { [string]: any } = {}
return Registry
