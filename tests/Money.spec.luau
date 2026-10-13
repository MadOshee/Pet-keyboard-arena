local Money = require("../src/shared/Util/Money")

local tests = {}

function tests.dollarsWithSpacesFromTenThousand()
	assert(Money.Format(0) == "$0")
	assert(Money.Format(250) == "$250")
	assert(Money.Format(1000) == "$1000")
	assert(Money.Format(12345) == "$12 345")
	assert(Money.Format(100000) == "$100 000")
	assert(Money.Format(999999) == "$999 999")
	assert(Money.Format(99.9) == "$99")
end

function tests.shortFromAMillion()
	assert(Money.Format(1000000) == "$1M")
	assert(Money.Format(1100000) == "$1.1M")
	assert(Money.Format(1500000) == "$1.5M")
	assert(Money.Format(1999999) == "$1.9M")
	assert(Money.Format(99900000) == "$99.9M")
	assert(Money.Format(123456789) == "$123.4M")
	assert(Money.Format(1100000000) == "$1.1B")
	assert(Money.Format(2.5e12) == "$2.5T")
	assert(Money.Number(-1100000) == "-1.1M")
end

return tests
