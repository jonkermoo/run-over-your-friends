--!strict
-- Client entry.
local Boards = require(script.Boards)
local Cockpit = require(script.Cockpit)
local Crowd = require(script.Crowd)
local Drive = require(script.Drive)
local EventBanner = require(script.EventBanner)
local Fx = require(script.Fx)
local Goals = require(script.Goals)
local Guide = require(script.Guide)
local Hud = require(script.Hud)
local Interiors = require(script.Interiors)
local Streets = require(script.Streets)

Hud.onGoals = Goals.toggle
Hud.onMenu = Goals.close
Drive.start()
Cockpit.start()
Hud.start()
Guide.start()
Goals.start()
Fx.start()
Boards.start()
EventBanner.start()
Crowd.start()
Streets.start()
Interiors.start()
