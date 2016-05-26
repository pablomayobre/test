describe("Plutfo and UTF-8 Lua Library unit testing framework", function ()
	print(os.getenv("PLUTFO"))

	local utf = require (os.getenv("PLUTFO") == "TRUE" and "plutfo" or "utf8") or utf8

	local unpack = unpack and unpack or table.unpack

	local wrap = function (func, ...)
		local arguments = {...}

		return function ()
			return func(unpack(arguments))
		end
	end

	local notpcall = function (...)
		local wrapped = wrap(...)

		return function ()
			local a, b = wrapped()

			if not a then
				error(b)
			end
		end
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
			assert.has_error(wrap(utf.offset, "abc",	1,  5),	"position out of range")
			assert.has_error(wrap(utf.offset, "abc",	1, -4),	"position out of range")
			assert.has_error(wrap(utf.offset, "",		1,  2),	"position out of range")
			assert.has_error(wrap(utf.offset, "",		1, -1), "position out of range")
		end)

		it("Continuation byte", function ()
			assert.has_error(wrap(utf.offset, "𦧺", 1,	2), "continuation byte")
			assert.has_error(wrap(utf.offset, "𦧺", 1,	2), "continuation byte")
			assert.has_error(wrap(utf.offset, "\x80",	1), "continuation byte")
		end)
	end)
	
	describe("utf8.len", function ()
		it("Passing cases", function ()
			assert.is.equal(utf.len(""),				0)
			assert.is.equal(utf.len("abcdef"),			#("abcdef"))
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
		
		it("Initial position out of string", function ()
			assert.has_error(wrap(utf.len, "abc", -5), "bad argument #2 to 'len' (initial position out of string)")
		end)

		it("Invalid byte sequence", function ()
			assert.has_error(notpcall(utf.len, "abc\xE3def"),		4)
			assert.has_error(notpcall(utf.len, "汉字\x80"),			#("汉字") + 1)
			assert.has_error(notpcall(utf.len, "\xF4\x9F\xBF"),		1)
			assert.has_error(notpcall(utf.len, "\xF4\x9F\xBF\xBF"),	1)
			assert.has_error(notpcall(utf.len, "ñábceí", 2),		2)
		end)
	end)
	
	describe("utf8.codes", function ()
		local iter = utf.codes("")
		
		it("Passing cases", function ()
			local t = {}
			
			for position, char in utf.codes("abñÉÂ") do
				t[position] = char
			end
			
			assert.are.same(t, {[1] = 97, [2] = 98, [3] = 241, [5] = 201, [7] = 194})
		end)

		it("Invalid byte sequence", function ()
			assert.has_error(wrap(iter, "abñÉÂ\xff", 8), "invalid UTF-8 code")
		end)
	end)
	
	describe("utf8.codepoint", function ()
		local s = "áéí\128"

		it("Passing cases", function ()
			local result	= { utf.codepoint(s, 1, #s - 1) }
			local expected	= { 225, 233, 237 }

			assert.are.same(result, expected)

			local zero		= #{ utf8.codepoint(s, 4, 3) }
			assert.is.equal(zero, 0)
		end)

		it("Invalid byte sequence", function ()
			assert.has_error(wrap(utf.codepoint, s, 1, #s),				"invalid UTF-8 code")
			assert.has_error(wrap(utf.codepoint, "abc\xE3def", 1, 6),	"invalid UTF-8 code")
		end)

		it("Position out of range", function ()
			assert.has_error(wrap(utf.codepoint, s, #s + 1			  ), 	"out of range")
			assert.has_error(wrap(utf.codepoint, s, -(#s + 1),		 1), 	"out of range")
			assert.has_error(wrap(utf.codepoint, s, 1,			#s + 1),	"out of range")
		end)
	end)
	
	describe("utf8.char", function ()
		it("Passing cases", function ()
			assert.is.equal(utf.char(),					""   )
			assert.is.equal(utf.char(97, 98, 99),		"abc")
			assert.is.equal(utf.char(225, 233, 237),	"áéí")

			assert.is.equal(utf.codepoint(utf.char(0x10FFFF)), 0x10FFFF)
		end)
	end)
end)