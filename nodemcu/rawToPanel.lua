local f = assert(io.open(arg[1], "rb"))
local outf = assert(io.open(arg[2], "wb"))

while true do
	local w = f:read(4)
	if w == nil then break end
	local a,r,g,b = string.byte(w, 1, 4)
	local hex = r * 2^16 + g * 2^8 + b
	if hex == 0 then
		outf:write("\0") -- Black
	elseif hex == 0xFFFF0B then
		outf:write("\4") -- Yellow
	else
		outf:write("\3") -- White for anything else
	end
end
