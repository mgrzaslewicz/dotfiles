local helpers = require 'tests.helpers'
local eq = MiniTest.expect.equality

local child = helpers.new_child()

local T = MiniTest.new_set {
  hooks = {
    pre_case = function() child.start() end,
    post_case = function() child.stop() end,
  },
}

T['Kotlin launch prompts for the main class of the current file'] = function()
  local dir = helpers.tree { ['src/main.kt'] = 'package com.example\n\nfun main() {}' }
  child.cmd('edit ' .. dir .. '/src/main.kt')
  local prompt = child.lua [[
    local prompt
    vim.fn.input = function(text, default) prompt = { text, default } return default end
    require('dap').configurations.kotlin[1].mainClass()
    return prompt
  ]]
  eq(prompt, { 'Main class: ', 'com.example.MainKt' })
end

return T
