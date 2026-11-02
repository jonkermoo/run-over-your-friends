--!strict
-- Developer products (bought with Robux, any number of times unless once = true).
-- id is 0 until the product exists on the Creator Hub; in Studio the store then grants it for testing.
-- robux is only the label shown while the id is 0; once set, the real price comes from Roblox.

export type Product = {
	key: string,
	id: number,
	title: string,
	money: number,
	vehicle: string?, -- a vehicle that comes with it
	robux: number,
	once: boolean,
	tag: string?, -- small label on the card ("BEST VALUE")
}

local function p(row: Product): Product
	return table.freeze(row)
end

return table.freeze({
	MoneyPacks = table.freeze({
		p({
			key = "Cash1",
			id = 0,
			title = "Pocket Change",
			money = 5000,
			robux = 25,
			once = false,
		}),
		p({ key = "Cash2", id = 0, title = "Fat Wallet", money = 25000, robux = 99, once = false }),
		p({
			key = "Cash3",
			id = 0,
			title = "Bank Job",
			money = 120000,
			robux = 399,
			once = false,
			tag = "POPULAR",
		}),
		p({
			key = "Cash4",
			id = 0,
			title = "Money Truck",
			money = 600000,
			robux = 1499,
			once = false,
			tag = "BEST VALUE",
		}),
	}),
	StarterOfferAfter = 300, -- seconds of play (tutorial done) before the Starter Pack ad pops up, once
	Starter = p({
		key = "Starter",
		id = 0,
		title = "Starter Pack",
		money = 10000,
		vehicle = "Taxi",
		robux = 49,
		once = true,
		tag = "ONCE",
	}),
})
