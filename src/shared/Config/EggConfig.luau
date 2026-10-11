--!strict
-- Egg offer rules (docs/design.md 4.3 "Яйца", 4.5). After a rewarded round a
-- player gets 4 eggs, one per theme, each with its own rolled rarity.
-- No requires or Roblox types: Lune tests load this file directly.

return table.freeze({
	-- Offer slots in this order; each slot is one theme from PetConfig.Themes.
	OfferThemes = table.freeze({ "Basic", "Forest", "Arctic", "Volcanic" }),
	EggsPerOffer = 4,

	-- Base weights in PetConfig.Rarities order (Common .. Legendary).
	BaseWeights = table.freeze({ 50, 28, 15, 6, 1 }),
	-- A rarity of rank r (Common = 0) has its weight multiplied by
	-- (1 + bonus) ^ r, where bonus adds up the values below and pet Luck.
	OutcomeBonus = table.freeze({ Win = 0.35, Draw = 0.15, Lose = 0 }),
	ContributionBonus = 0.3, -- times the share of the team's best painter (0..1)

	-- Coins for the 1st..5th reroll of one offer; no more rerolls after that.
	RerollCosts = table.freeze({ 50, 100, 200, 400, 800 }),
	-- Unpicked offers auto-pick the rarest egg after this many seconds.
	OfferSeconds = 30,

	-- Model name under ReplicatedStorage.Assets.Eggs for a theme.
	ModelName = function(theme: string): string
		return theme .. " Egg"
	end,
})
