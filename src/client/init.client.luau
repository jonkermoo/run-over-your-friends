--!strict
-- Client entry.
local Drive = require(script.Drive)
local Fx = require(script.Fx)
local Goals = require(script.Goals)
local Guide = require(script.Guide)
local Hud = require(script.Hud)

Drive.start()
Hud.start()
Guide.start()
Goals.start()
Fx.start()
