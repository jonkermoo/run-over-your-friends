--!strict
-- HUD shape images in the Road Paint style (tools/ui/icons.py): image ids. Arrow, Pointer, Pin and Sign are
-- white with ink outlines, so the game tints them (ImageColor3); Coin, Bill and the Pass pictures are full colour.

return table.freeze({
	Arrow = 99299599300196, -- the guide's block arrow, pointing down (the world arrow, the edge pointer, the press arrow)
	Pointer = 100238627414292, -- the giant finder's wedge, pointing right
	Pin = 81668720367172, -- a push-pin for pinned goals
	Coin = 82732236787662, -- a gold coin out of the cash box
	Bill = 92497881821797, -- a banknote out of the cash box
	Sign = 98798122954662, -- the event chip's diamond warning sign with a "!"
	-- the store's game pass cards, full colour (tools/ui/store_icons.py)
	PassVIP = 94878460906390, -- a gold crown
	PassRoadster = 130169004213949, -- the red Roadster with its rear jet
	PassDoubleMoney = 107962796793732, -- two banknotes with a "2X" sticker
	-- Street Sign pictograms (tools/ui/sign_icons.py): white shapes with see-through details, tinted in game
	SignGarage = 131145482534585, -- a car, the garage's menu sign
	SignStore = 131258998465620, -- a shopping bag with a $
	SignGoals = 74302420739949, -- a chequered flag
	SignMap = 87697438006488, -- a folded map with a dashed route
	SignInvite = 76669739625185, -- two people
	SignTutorial = 96220546871923, -- a "?" in a ring
	SignSettings = 118965571580421, -- a wrench
	SignBoost = 137046716958650, -- double chevrons
	SignHorn = 110658772837271, -- a horn with sound waves
	SignView = 119111769304075, -- an eye
	SignUnstuck = 107881160438518, -- a tipped car with a turn arrow
	SignGift = 136681305731590, -- a wrapped gift
	Stop = 104168263192523, -- the stop-sign octagon alert badge, full colour (red with a white rim and black edge)
	-- the road UI icons (tools/ui/road_icons.py): black outline, flat traffic colours, full colour (not tinted),
	-- 256 px; preloaded behind the loading cover (first/Loading)
	RoadBag = 100751902892147, -- bag
	RoadBolt = 112754394326221, -- bolt
	RoadCarBlack = 75663587557493, -- car-black
	RoadCarBlue = 76716020793903, -- car-blue
	RoadCarGreen = 119125093667730, -- car-green
	RoadCarPink = 102807577873440, -- car-pink
	RoadCarRed = 135712065091242, -- car-red
	RoadCarTaxi = 77978477574044, -- car-taxi
	RoadCarWhite = 135451717694544, -- car-white
	RoadCarYellow = 81725698112790, -- car-yellow
	RoadCash = 99798213093541, -- cash
	RoadCheck = 140280752279603, -- check
	RoadChest = 92014782543309, -- chest
	RoadClock = 83732446002304, -- clock
	RoadCoin = 132378840780683, -- coin
	RoadCone = 126119340902395, -- cone
	RoadCrown = 100413443450861, -- crown
	RoadEye = 114597095659754, -- eye
	RoadFlag = 90668949254628, -- flag
	RoadGift = 92034103021215, -- gift
	RoadLock = 83464061487660, -- lock
	RoadMap = 112404987737502, -- map
	RoadMinus = 83441291470924, -- minus
	RoadMusic = 124453689833301, -- music
	RoadPaint = 117097778078080, -- paint
	RoadPeople = 139510269319697, -- people
	RoadPin = 106730221309948, -- pin
	RoadPlus = 95210446217118, -- plus
	RoadRocket = 119280263069795, -- rocket
	RoadSeat = 85488063662378, -- seat
	RoadSkull = 97143186365407, -- skull
	RoadStar = 134681462774653, -- star
	RoadStop = 83826547029328, -- stop
	RoadTarget = 75370453566679, -- target
	RoadTicket = 88119798064505, -- ticket
	RoadTrophy = 103430761692038, -- trophy
	RoadVip = 130431096140448, -- vip
	RoadWrench = 93475247083487, -- wrench
})
