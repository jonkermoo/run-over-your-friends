--!strict
-- How the VIP pass shows: the gold tag over a VIP player's head (client/VipTags) and their chat prefix.
-- The pass id and cash bonus are in Config/Economy, the VIP Gold paint in Config/Paints. Colours are 0-255 sRGB.

return table.freeze({
	Gold = { 255, 196, 40 }, -- tag and chat prefix colour
	Ink = { 20, 20, 24 }, -- tag text and outline
	TagWidth = 54, -- tag pill in pixels (shrinks on small screens like the other world labels)
	TagHeight = 22,
	TagText = 15,
	-- studs above the top of the head: clears Roblox's own name label, which sits just over the head
	TagLift = 2.6,
	TagRange = 100, -- studs: hidden past this
	HideWithin = 4, -- your own tag hides while the camera is this close to your head (first person)
	HideCheckEvery = 0.2, -- seconds
	ChatPrefix = "[VIP]",
})
