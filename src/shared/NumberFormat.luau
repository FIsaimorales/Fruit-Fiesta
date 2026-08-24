--!strict
local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

-- Helper to format decimals without trailing .0 / .00 and avoiding %g scientific notation
local function formatDecimals(val: number, decimals: number): string
	local formatted = string.format("%." .. decimals .. "f", val)
	-- Remove trailing zeros after decimal point (e.g. 1.50 -> 1.5, 1.00 -> 1)
	formatted = formatted:gsub("%.?0+$", "")
	return formatted
end

-- formatMoney(9682000000) → "$9.68B", formatMoney(1500) → "$1.5K", formatMoney(99) → "$99"
function NumberFormat.formatMoney(n: number): string
	if n < 0 then
		return "-" .. NumberFormat.formatMoney(-n)
	end
	if n < 1000 then
		return "$" .. tostring(math.floor(n))
	end

	local i = 1
	local current = n
	while current >= 1000 and i < #SUFFIXES do
		current /= 1000
		i += 1
	end

	local formatted = formatDecimals(current, 2)
	return "$" .. formatted .. SUFFIXES[i]
end

-- formatPlain(1500) → "1,500"
function NumberFormat.formatPlain(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return formatted
end

-- incomePerSecond → "+$1.5K/s"
function NumberFormat.formatIncome(n: number): string
	return "+" .. NumberFormat.formatMoney(n) .. "/s"
end

return NumberFormat
