local dkjson = require('dkjson')
local helpers = require('test.helpers')
local parser = require('vim9jit.parser')
local token = require('vim9jit.token')



local function parsed_expr(s)
  return token.parsestring(parser.grammar_expression, s)
end


local function parsed_file(s)
  return token.parsestring(parser.grammar, 'vim9script\n' .. helpers.dedent(s))
end


local function parsed_full(s)
  return token.parsestring(parser.grammar, s)
end


local script = [[vim9script
var x = 123
var y = "4"
]]

local parsed = parsed_full(script)
local sorted = {
  "line_start",
  "line_finish",
  "char_start",
  "char_finish",
  "byte_start",
  "byte_finish",
}
print(dkjson.encode(parsed, {indent = true, keyorder = sorted}))