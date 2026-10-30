--!strict
-- Client entry.
local Boards = require(script.Boards)
local Drive = require(script.Drive)
local EventBanner = require(script.EventBanner)
local Fx = require(script.Fx)
local Goals = require(script.Goals)
local Guide = require(script.Guide)
local Hud = require(script.Hud)

Drive.start()
Hud.start()
Guide.start()
Goals.start()
Fx.start()
Boards.start()
EventBanner.start()
