require('plenary.test_harness'):setup_busted()

local generator = require('vim9jit.generator')
local generate = generator.generate

local helpers = require('test.helpers')
local eq, neq, get_item = helpers.eq, helpers.neq, helpers.get_item

local fmt = generator._utils.fmt

local make_vim9script = function(text)
  return 'vim9script\n' .. fmt(text)
end

describe('generator', function()
  it('should generate nothing for empty file', function()
    local result = generate("vim9script")

    eq('', result)
  end)

  it('should parse simple var statements', function()
    local result = generate(make_vim9script("var x = 1"))

    eq('local x = 1\n', result)
  end)

  it('should parse simple var addition statements', function()
    local result = generate(make_vim9script("var x = 1 + 2"))

    eq('local x = 1 + 2\n', result)
  end)

  it('should parse simple var addition statements', function()
    local result = generate(make_vim9script("var x: number"))

    eq('local x = vim9jit.DefaultForType("number")\n', result)
  end)

  it('should ignore type statements when strict mode is off', function()
    -- Our other option would be do something like `local x = assert_type(1 + 2, 'number')
    local result = generate(make_vim9script("var x: number = 1 + 2"))

    eq('local x = 1 + 2\n', result)
  end)

  it('should not ignore type statements when in strict mode', function()
    -- Our other option would be do something like `local x = assert_type(1 + 2, 'number')
    local result = generate(make_vim9script("var x: number = 1 + 2"), true)

    eq('local x = vim9jit.AssertType("number", 1 + 2)\n', result)
  end)

  it('should not use vim.g for declaring globals', function()
    local result = generate(make_vim9script("var g:glob_var = 1 + 2"))

    eq('vim.g["glob_var"] = 1 + 2\n', result)
  end)

  it('should not use local again for variables', function()
    local result = generate(make_vim9script([[
      var this_var = 1
      this_var = 3
    ]]))

    eq("local this_var = 1\nthis_var = 3\n", result)
  end)

  it('should not use local for forward declarations', function()
    local result = generate(make_vim9script([[
      var this_var
      if cond
        this_var = 3
      else
        this_var = 5
      endif
    ]]))

    eq("local this_var = nil\nif cond then\n  this_var = 3\nelse\n  this_var = 5\nend\n", result)
  end)

  describe('functions', function()
    -- TODO: Figure out why this won't work.
    pending('should be able to generate functions', function()
      local result = generate(make_vim9script [[
  var sum = 1

  def VimNew()
    sum = sum + 1
  enddef
]])

      eq(vim.trim [[
local sum = 1
local function VimNew()
  sum = sum + 1
end
]], vim.trim(result))
    end)
  end)

  describe('calling functions', function()
    it('should redirect to vim functions', function()
      local result = generate(make_vim9script [[
        var range = range(1, 100)
      ]])

      eq("local range = vim.fn['range'](1, 100)\n", result)
    end)
  end)

  describe('loops', function()
    it('should use pairs wrapper', function()
      local result = generate(make_vim9script [[
        var sum = 0
        for i in my_func(1, 100)
          sum = sum + 1
        endfor
      ]])

      eq(vim.trim[[
local sum = 0
for _, i in vim9jit.VimPairs(vim.fn['my_func'](1, 100)) do
  sum = sum + 1
end
]], vim.trim(result))
    end)

    it('should use super cool range wrapper', function()
      local result = generate(make_vim9script [[
        var sum = 0
        for i in range(1, 100)
          sum = sum + 1
        endfor
      ]])

      eq(vim.trim[[
local sum = 0
for i = 1, 100, 1 do
  sum = sum + 1
end
]], vim.trim(result))
    end)
  end)

  describe('vim9 spec', function()
    it('should handle indent time measurements', function()
      local result = generate(make_vim9script [[
        def VimNew(): number
          var totallen = 0
          for i in range(1, 100000)
            setline(i, '    ' .. getline(i))
            totallen = totallen + len(getline(i))
          endfor
          return totallen
        enddef
      ]])

      eq([[
local function VimNew()
  local totallen = 0
  for i = 1, 100000, 1 do
    vim.fn['setline'](i, '    ' .. vim.fn['getline'](i))
    totallen = totallen + vim.fn['len'](vim.fn['getline'](i))
  end

  return totallen
end
]], result)
    end)
  end)

  describe('method calls', function()
    it('should special case add', function()
      local result = generate(make_vim9script("var x = myList->add(1)"))

      eq("local x = (table.insert(myList, 1) or myList)", vim.trim(result))
    end)
  end)

  describe('conditionals', function()
    it('should handle a simple conditional', function()
      local result = generate(make_vim9script [[
        var x = v:true ? 1 : 2
      ]])

      eq([[local x = vim9jit.conditional(true, function() return 1 end, function() return 2 end)]], vim.trim(result))
    end)

    it('should handle functions', function()
      local result = generate(make_vim9script [[
        var x = MyFunc() ? 1 : 2
      ]])

      eq([[local x = vim9jit.conditional(MyFunc(), function() return 1 end, function() return 2 end)]], vim.trim(result))
    end)

    it('should handle this', function()
      local result = generate(make_vim9script [[
        var Z = g:cond ? FuncOne : FuncTwo
      ]])

      eq([[local Z = vim9jit.conditional(vim.g['cond'], function() return FuncOne end, function() return FuncTwo end)]], vim.trim(result))
    end)
  end)
end)
