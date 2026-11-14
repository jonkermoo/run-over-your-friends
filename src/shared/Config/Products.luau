--!strict
-- Developer products (bought with Robux, any number of times unless once = true).
-- id is 0 until the product exists on the Creator Hub; in Studio the store then grants it for testing.
-- robux is only the label shown while the id is 0; once set, the real price comes from Roblox.

export type Product = {
	key: string,
	id: number,
	title: string,
	money: number,
	vehicles: { string }?, -- vehicles that come with it
	robux: number,
	once: boolean,
	onceKey: string?, -- products sharing this key count as one buy (the Starter Pack and its deal); default key
	deal: boolean?, -- only sold while the player's deal window is open (Rules/Offer)
	tag: string?, -- small label on the card ("BEST VALUE")
}

local function p(row: Product): Product
	return table.freeze(row)
end

return table.freeze({
	MoneyPacks = table.freeze({
		p({
			key = "Cash1",
			id = 3731061335,
			title = "Pocket Change",
			money = 5000,
			robux = 9,
			once = false,
		}),
		p({
			key = "Cash2",
			id = 3731061338,
			title = "Fat Wallet",
			money = 25000,
			robux = 29,
			once = false,
		}),
		p({
			key = "Cash3",
			id = 3731061340,
			title = "Bank Job",
			money = 120000,
			robux = 99,
			once = false,
			tag = "POPULAR",
		}),
		p({
			key = "Cash4",
			id = 3731061343,
			title = "Money Truck",
			money = 600000,
			robux = 299,
			once = false,
			tag = "BEST VALUE",
		}),
	}),
	StarterOfferAfter = 300, -- seconds of play (tutorial done) before the Starter Pack ad pops up, once a session
	-- the pop-up's discount: a window of this many seconds starts the first time the card shows (saved per
	-- player, never restarted); while it runs the pack sells as StarterDeal, after it only at the full price
	StarterDealSeconds = 1800,
	-- the pack is offered (pop-up and garage) only while the player owns no vehicle at least this dear
	StarterUntil = "Muscle",
	Starter = p({
		key = "Starter",
		id = 3731061347,
		title = "Starter Pack",
		money = 275000,
		vehicles = table.freeze({ "Muscle", "Bulldozer" }),
		robux = 99,
		once = true,
		tag = "ONCE",
	}),
	StarterDeal = p({
		key = "StarterDeal",
		id = 3731061351,
		title = "Starter Pack",
		money = 275000,
		vehicles = table.freeze({ "Muscle", "Bulldozer" }),
		robux = 49,
		once = true,
		onceKey = "Starter",
		deal = true,
	}),
})
