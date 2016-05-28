describe("Plutfo and UTF-8 Lua Library unit testing framework", function ()
	print(os.getenv("PLUTFO") == "TRUE" and "plutfo" or "utf8")

	local utf = require (os.getenv("PLUTFO") == "TRUE" and "plutfo" or "utf8")

	local unpack = unpack or table.unpack

	local wrap = function (func, ...)
		local a = {...}
		return function () return func(unpack(a)) end
	end

	local ecall = function (func, ...)
		local a = {func(...)}
		local b = a[1]
		table.remove(a, 1)

		if b then
			return unpack(a)
		else
			error(unpack(a))
		end
	end
	
	local wcall = function (func, ...)
		return wrap(ecall, func, ...)
	end

	describe("utf8.offset", function ()
		it("Passing cases", function ()
			assert.is.equal(utf.offset("abc\xE3def", 4),	 4)
			assert.is.equal(utf.offset("abc\xE3def", 5),	 5)
			assert.is.equal(utf.offset("ñáüÂìÖ",	 3),	 5)
			assert.is.equal(utf.offset("ñáüÂìÖ",	-3),	 7)
			assert.is.equal(utf.offset("ñáüÂìÖ",	 1,  5), 5)
			assert.is.equal(utf.offset("ñáüÂìÖ",	 1, -4), 9)
			assert.is.equal(utf.offset("ñáüÂìÖ",	-1,  5), 3)
			assert.is.equal(utf.offset("ñáüÂìÖ",	-1, -4), 7)
		end)

		it("Character not in subject", function ()
			assert.is_nil(utf.offset("alo",  5))
			assert.is_nil(utf.offset("alo", -4))
		end)

		it("Position out of range", function ()
			assert.error_matches(wrap(utf.offset, "abc", 1,  5), "position out of range", nil, true)
			assert.error_matches(wrap(utf.offset, "abc", 1, -4), "position out of range", nil, true)
			assert.error_matches(wrap(utf.offset, "",	 1,  2), "position out of range", nil, true)
			assert.error_matches(wrap(utf.offset, "",	 1, -1), "position out of range", nil, true)
		end)

		describe("Continuation byte", function ()
			assert.error_matches(wrap(utf.offset, "𦧺", 1,	2), "continuation byte", nil, true)
			assert.error_matches(wrap(utf.offset, "𦧺", 1,	2), "continuation byte", nil, true)
			assert.error_matches(wrap(utf.offset, "\x80",	1), "continuation byte", nil, true)
		end)
	end)
	
	describe("utf8.len", function ()
		it("Passing cases", function ()
			assert.is.equal(utf.len(""),				0)
			assert.is.equal(utf.len("abcdef"),			6)
			assert.is.equal(utf.len("ñábceí"),			6)
			assert.is.equal(utf.len("ñábceí", 3),		5)
			assert.is.equal(utf.len("ñábceí", 3, 3),	1)
			assert.is.equal(utf.len("ñábceí", 3, 4),	1)
			assert.is.equal(utf.len("ñábceí", 3, -1),	5)
			assert.is.equal(utf.len("ñábceí", -5, 6),	2)
		end)
		
		it("Null range", function ()
			assert.is.equal(utf.len("abc", 4), 0)
			assert.is.equal(utf.len("abc", -1, 1), 0)
		end)
		
		describe("Initial position out of string", function ()
			assert.error_matches(wrap(utf.len, "abc", -5), "initial position out of string", nil, true)
		end)

		it("Invalid byte sequence", function ()
			assert.has_error(wcall(utf.len, "汉字\x80"),	#("汉字") + 1)
			assert.has_error(wcall(utf.len, "\xF4\x9F\xBF"),			1)
			assert.has_error(wcall(utf.len, "\xF4\x9F\xBF\xBF"),		1)
			assert.has_error(wcall(utf.len, "ñábceí", 2),				2)
			assert.has_error(wcall(utf.len, "abc\xE3def"),				4)
		end)
	end)
	
	describe("utf8.codes", function ()
		local iter = utf.codes("")
		
		it("Passing cases", function ()
			local t = {}
			
			for position, char in utf.codes("abñÉÂ") do
				t[position] = char
			end
			
			assert.are.same({[1] = 97, [2] = 98, [3] = 241, [5] = 201, [7] = 194}, t)
		end)

		describe("Invalid byte sequence", function ()
			assert.error_matches(wrap(iter, "abñÉÂ\xff", 8), "invalid UTF-8 code", nil, true)
		end)
	end)
	
	describe("utf8.codepoint", function ()
		local s = "áéí\128"

		it("Passing cases", function ()
			local result	= { utf.codepoint(s, 1, #s - 1) }
			local expected	= { 225, 233, 237 }

			assert.are.same(expected, result)

			local zero		= #{ utf.codepoint(s, 4, 3) }
			assert.is.equal(0, zero)
		end)

		describe("Invalid byte sequence", function ()
			assert.error_matches(wrap(utf.codepoint, s, 1, #s),				"invalid UTF-8 code", nil, true)
			assert.error_matches(wrap(utf.codepoint, "abc\xE3def", 1, 6),	"invalid UTF-8 code", nil, true)
		end)

		describe("Position out of range", function ()
			assert.error_matches(wrap(utf.codepoint, s, #s + 1),		"out of range", nil, true)
			assert.error_matches(wrap(utf.codepoint, s, -(#s + 1), 1),	"out of range", nil, true)
			assert.error_matches(wrap(utf.codepoint, s, 1, #s + 1),		"out of range", nil, true)
		end)
	end)
	
	describe("utf8.char", function ()
		it("Passing cases", function ()
			assert.is.equal("",		utf.char()				)
			assert.is.equal("abc",	utf.char(97, 98, 99)	)
			assert.is.equal("áéí",	utf.char(225, 233, 237)	)

			assert.is.equal(0x10FFFF, utf.codepoint(utf.char(0x10FFFF)))
		end)
		
		it("Out of range", function ()
			assert.error_matches(wrap(utf.char, 0x10FFFF + 1), "value out of range", nil, true)
		end)
	end)
end)