local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

-- formatMoney(9682000000) → "$9.682B"
function NumberFormat.formatMoney(n: number): string
	if n < 0 then return "-" .. NumberFormat.formatMoney(-n) end
	if n < 1000 then return "$" .. math.floor(n) end

	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n = n / 1000
		i += 1
	end

	local formatted = string.format("%.3g", n)
	return "$" .. formatted .. SUFFIXES[i]
end

-- formatPlain(1500) → "1,500"
function NumberFormat.formatPlain(n: number): string
	local s = tostring(math.floor(n))
	local result = ""
	local count = 0
	for i = #s, 1, -1 do
		if count > 0 and count % 3 == 0 then
			result = "," .. result
		end
		result = string.sub(s, i, i) .. result
		count += 1
	end
	return result
end

-- incomePerSecond → "+$1.5K/s"
function NumberFormat.formatIncome(n: number): string
	return "+" .. NumberFormat.formatMoney(n) .. "/s"
end

return NumberFormat
