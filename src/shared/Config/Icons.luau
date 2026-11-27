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
})
