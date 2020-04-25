#!/usr/local/bin/lua5.3

-- Neither standard Lua 5.1 nor 5.3 have a bit library exactly matching what NodeMCU code expects
bit = {
    band = function(a, b) return a & b end,
    rshift = function(a, b) return a >> b end,
    lshift = function(a, b) return a << b end,
}

font = require "font"

text = "Testing 123!"

for y = 0, font.charh-1 do
    local bits = {}
    for x = 0, (font.charw * #text)-1 do
        local textPos = 1 + (x // font.charw)
        local char = text:sub(textPos, textPos)
        local chx = x % font.charw
        table.insert(bits, font.getPixel(char, chx, y) and "X" or " ")
    end
    print(table.concat(bits))
end
