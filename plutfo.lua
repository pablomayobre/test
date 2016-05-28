local utf = {
	_VERSION		= "plutfo 0.1.0",
	_DESCRIPTION	= "Pure Lua UTF-8 operations is a library compatible with Lua 5.3 UTF-8 module",
	_URL			= "https://www.github.com/Cations/plutfo",
	_AUTHOR			= "Cations",
	_LICENSE		= [[
		The MIT License (MIT)

		Copyright (c) 2016 Cations

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	]]
}

--Errors not reported or reported incorrectly
--Make sure your code works with the Native UTF-8 lib before using this one

local string, table, math = require "string", require "table", require "math"
local unpack = unpack or table.unpack

--Helper stuff!
local pattern 
if tonumber(string.match(_VERSION,"Lua 5%.(.+)")) <= 1 then
	pattern = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"
else
	pattern = "[\0-\x7F\xC2-\xF4][\x80-\xBF]*"
end

local character = function (char)
	if char <= 0x7f then return string.char(char) end

	if (char <= 0x7ff) then
		local a = 0xc0 + math.floor(char / 0x40);
		local b = 0x80 + (char % 0x40);
		return true, string.char(a, b);
	end

	if (char <= 0xffff) then
		local a = 0xe0 +  math.floor(char / 0x1000);
		local b = 0x80 + (math.floor(char / 0x40) % 0x40);
		local c = 0x80 + (char % 0x40);
		return true, string.char(a, b, c);
	end

	if (char <= 0x10ffff) then
		local code = char
		local a	= 0x80 + (code % 0x40);
		code	= math.floor(code / 0x40)
		local b	= 0x80 + (code % 0x40);
		code	= math.floor(code / 0x40)
		local c	= 0x80 + (code % 0x40);
		code	= math.floor(code / 0x40)  
		local d	= 0xf0 + code;

		return true, string.char(a, b, c, d);
	end
end

local sh6, sh12, sh18 = 2^6, 2^12, 2^18
local codepoint = function (char)
	local a, b, c, d = string.byte(char, 1, -1)
	local n = string.len(char)
	
	if n == 1 then
		return a
	end

	if n == 2 then
		local w, x = a - 0xc0, b - 0x80
		return math.floor(w * sh6 + x)
	end
	
	if n == 3 then
		local w, x, y = a - 0xe0, b - 0x80, c - 0x80
		return math.floor(w * sh12 + x * sh6 + y)
	end
	
	if n == 4 then
		local w, x, y, z = a - 0xf0, b - 0x80, c - 0x80, d - 0x80
		return math.floor(w * sh18 + x * sh12 + y * sh6 + z)
	end
	
	error ("UTF-8 sequences can contain up to 4 bytes", 2)
end

local iterator = function (state, v)
	local value = tonumber(v) or 0

	local finish = string.match(state, "("..pattern..")()", value)
	if finish == string.len(state) + 1 then return end

	local position, char, offset = string.match(state, "()("..pattern..")", value + 1)

	if value ~= 0 then
		if position ~= finish then error("invalid UTF-8 code") end
	end

	if char and position and offset then
		return position, char, offset
	end
end

local loop = function (s, f, i, j, ...)
	for u, c, v in iterator, s, i do
		if v > i then
			if u > j then
				break
			end

			if f(u, c, v, ...) then break end
		end
	end
end

--Some looping functions that will run in the function defined above
local funcCodepoint = function (u, c, v, ret)
	table.insert(ret, codepoint(c))
end

local funcLen = function (u, c, v, ret)
	ret[1] = ret[1] + 1
end

local funcOffset = function (u, c, v, ret)
	if ret[2] == ret[1] then
		ret[3] = u
		return true
	end
	
	ret[2] = ret[2] + 1
end

local funcNOffset = function (u, c, v, ret)
	table.insert(ret, u)
end

--Actual UTF-8 functions
utf.char = function (...)
	local ret = {}

	for i=1, select("#", ...) do
		local ok, char = character(select(i, ...))
		if ok then
			table.insert(ret, char)
		else
			error("bad argument #"..i.." to 'char' (value out of range)", 2)
		end
	end
	
	return table.concat(ret, "")
end

utf.charpattern = pattern

utf.codes = function (state)
	return function (...)
		local position, char = iterator(...)
		return position, char and codepoint(char)
	end, state, 0
end

utf.codepoint = function (s, i, j)
	local len = string.len(s)

	i = i and (i < 0 and len + 1 + i or i) or 1
	j = j and (j < 0 and len + 1 + j or j) or i

	if j < i then return end

	local ret = {}

	loop(s, funcCodepoint, i, j, ret)

	return unpack(ret)
end

utf.len = function (s, i, j)
	local len = string.len(s)

	i = i and (i < 0 and len + 1 + i or i) or 1
	j = j and (j < 0 and len + 1 + j or j) or len

	if j < i then return 0 end

	local ret = {0}
	
	loop(s, funcLen, i, j, ret)

	return ret[1]
end

utf.offset = function (s, n, i)
	local len = string.len(s)

	--local char = n

	if n < 0 then
		local j = i or len + 1
		local ret = {}

		loop(s, funcNOffset, 0, j, ret)

		return ret[#ret + n]
	else
		local j = i or 1
		local ret = {n, 0, nil}

		loop(s, funcOffset, j, len + 1, ret)

		return ret[2]
	end
end

return utf