local EggConfig = require("../src/shared/Config/EggConfig")
local EggRoller = require("../src/shared/Logic/EggRoller")
local PetConfig = require("../src/shared/Config/PetConfig")

local RARITIES = PetConfig.Rarities

local function context(outcome: string, contribution: number, luck: number)
	return { Outcome = outcome, ContributionPct = contribution, Luck = luck }
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

-- Deterministic sequence of rolls.
local function sequence(values: { number })
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local tests = {}

function tests.oddsSumToOne()
	for _, ctx in { context("Lose", 0, 0), context("Win", 1, 1), context("Draw", 0.5, 0.3) } do
		local total = 0
		for _, chance in EggRoller.Odds(EggRoller.Weights(ctx, EggConfig)) do
			total += chance
		end
		assert(near(total, 1), "odds must sum to 1")
	end
end

function tests.baseOddsWithoutBonus()
	local odds = EggRoller.Odds(EggRoller.Weights(context("Lose", 0, 0), EggConfig))
	assert(near(odds[1], 0.5))
	assert(near(odds[5], 0.01))
end

function tests.winContributionAndLuckShiftUp()
	local function legendary(ctx)
		return EggRoller.Odds(EggRoller.Weights(ctx, EggConfig))[5]
	end
	local lose = legendary(context("Lose", 0, 0))
	local win = legendary(context("Win", 0, 0))
	local winBest = legendary(context("Win", 1, 0))
	local winLucky = legendary(context("Win", 1, 1))
	assert(lose < win and win < winBest and winBest < winLucky)
	-- Common gets rarer as bonuses grow.
	local commonLose = EggRoller.Odds(EggRoller.Weights(context("Lose", 0, 0), EggConfig))[1]
	local commonLucky = EggRoller.Odds(EggRoller.Weights(context("Win", 1, 1), EggConfig))[1]
	assert(commonLucky < commonLose)
end

function tests.contributionIsClamped()
	local over = EggRoller.Bonus(context("Lose", 5, 0), EggConfig)
	local full = EggRoller.Bonus(context("Lose", 1, 0), EggConfig)
	local under = EggRoller.Bonus(context("Lose", -2, -1), EggConfig)
	assert(near(over, full))
	assert(near(under, 0))
end

function tests.pickIndexFollowsWeights()
	local weights = { 1, 1, 2 }
	assert(EggRoller.PickIndex(weights, function()
		return 0
	end) == 1)
	assert(EggRoller.PickIndex(weights, function()
		return 0.3
	end) == 2)
	assert(EggRoller.PickIndex(weights, function()
		return 0.99999
	end) == 3)
end

function tests.offerHasOneEggPerTheme()
	local eggs = EggRoller.RollOffer(
		context("Win", 0.5, 0),
		EggConfig.OfferThemes,
		RARITIES,
		EggConfig,
		sequence({ 0.1, 0.6, 0.9, 0.999 })
	)
	assert(#eggs == EggConfig.EggsPerOffer)
	for index, egg in eggs do
		assert(egg.Theme == EggConfig.OfferThemes[index])
		assert(table.find(RARITIES, egg.Rarity) ~= nil)
	end
	assert(eggs[1].Rarity == "Common")
end

function tests.rollPetMatchesThemeAndRarity()
	for _, theme in EggConfig.OfferThemes do
		for _, rarity in RARITIES do
			for _, roll in { 0, 0.5, 0.99999 } do
				local kind = EggRoller.RollPet(PetConfig.Pets, theme, rarity, function()
					return roll
				end)
				assert(kind ~= nil, `no pet for {theme} {rarity}`)
				local entry = PetConfig.Pets[kind]
				assert(entry.Theme == theme and entry.Rarity == rarity)
			end
		end
	end
end

function tests.rollPetReturnsNilWhenNothingFits()
	assert(EggRoller.RollPet(PetConfig.Pets, "Nope", "Common", function()
		return 0
	end) == nil)
end

function tests.bestSlotPicksRarestFirstOnTies()
	local eggs = {
		{ Theme = "Basic", Rarity = "Rare" },
		{ Theme = "Forest", Rarity = "Epic" },
		{ Theme = "Arctic", Rarity = "Epic" },
		{ Theme = "Volcanic", Rarity = "Common" },
	}
	assert(EggRoller.BestSlot(eggs, RARITIES) == 2)
end

function tests.manyRollsRoughlyMatchOdds()
	local weights = EggRoller.Weights(context("Lose", 0, 0), EggConfig)
	local seed = 12345
	local function lcg()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local counts = { 0, 0, 0, 0, 0 }
	local rolls = 20000
	for _ = 1, rolls do
		local index = EggRoller.PickIndex(weights, lcg)
		counts[index] += 1
	end
	assert(math.abs(counts[1] / rolls - 0.5) < 0.02, "common share off")
	assert(math.abs(counts[5] / rolls - 0.01) < 0.005, "legendary share off")
end

return tests
