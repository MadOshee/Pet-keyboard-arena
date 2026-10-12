local Money = require("../src/shared/Util/Money")

local tests = {}

function tests.dollarsWithSpacesFromTenThousand()
	assert(Money.Format(0) == "$0")
	assert(Money.Format(250) == "$250")
	assert(Money.Format(1000) == "$1000")
	assert(Money.Format(12345) == "$12 345")
	assert(Money.Format(100000) == "$100 000")
	assert(Money.Format(1500000) == "$1 500 000")
	assert(Money.Format(99.9) == "$99")
end

return tests
