local FeedbackText = require("../src/shared/Logic/FeedbackText")

local tests = {}

function tests.trimsAndKeepsText()
	assert(FeedbackText.Clean("  add more eggs \n", 3, 500) == "add more eggs")
end

function tests.rejectsShortLongAndNonStrings()
	assert(FeedbackText.Clean("  hi ", 3, 500) == nil)
	assert(FeedbackText.Clean(string.rep("a", 501), 3, 500) == nil)
	assert(FeedbackText.Clean(42, 3, 500) == nil)
	assert(FeedbackText.Clean(nil, 3, 500) == nil)
end

function tests.countsCharactersNotBytes()
	local russian = string.rep("я", 500)
	assert(FeedbackText.Clean(russian, 3, 500) == russian)
end

function tests.rejectsInvalidUtf8()
	assert(FeedbackText.Clean("abc\255def", 3, 500) == nil)
end

return tests
