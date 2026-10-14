local PlayerSettings = require("../src/shared/Logic/PlayerSettings")

local tests = {}

function tests.acceptsKnownNamesWithBooleans()
	assert(PlayerSettings.IsValid("Music", false))
	assert(PlayerSettings.IsValid("Sfx", true))
	assert(PlayerSettings.IsValid("Vfx", false))
end

function tests.rejectsUnknownNamesAndValues()
	assert(not PlayerSettings.IsValid("Coins", true))
	assert(not PlayerSettings.IsValid("Music", "off"))
	assert(not PlayerSettings.IsValid("Music", nil))
	assert(not PlayerSettings.IsValid(1, true))
end

function tests.missingSwitchesAreOn()
	assert(PlayerSettings.Get(nil, "Music") == true)
	assert(PlayerSettings.Get({}, "Sfx") == true)
	assert(PlayerSettings.Get({ Vfx = "x" }, "Vfx") == true)
	assert(PlayerSettings.Get({ Music = false }, "Music") == false)
end

return tests
