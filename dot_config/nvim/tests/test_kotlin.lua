local main_class = require('custom.jvm.kotlin').main_class
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['main_class()'] = MiniTest.new_set()

T['main_class()']['is <package>.<File>Kt'] = function()
  eq(main_class({ 'package com.example.app', '', 'fun main() {}' }, '/src/App.kt'), 'com.example.app.AppKt')
end

T['main_class()']['has no package prefix in the default package'] = function() eq(main_class({ 'fun main() {}' }, '/src/App.kt'), 'AppKt') end

T['main_class()']['finds the package after comments and file annotations'] = function()
  local lines = { '/*', ' * Copyright', ' */', '@file:Suppress("unused")', '', 'package com.example', 'fun main() {}' }
  eq(main_class(lines, '/src/App.kt'), 'com.example.AppKt')
end

T['main_class()']['finds the package after a long license header'] = function()
  local lines = { '/*' }
  for i = 1, 80 do
    lines[#lines + 1] = ' * license line ' .. i
  end
  vim.list_extend(lines, { ' */', 'package com.example', 'fun main() {}' })
  eq(main_class(lines, '/src/App.kt'), 'com.example.AppKt')
end

T['main_class()']['capitalizes the file name like kotlinc'] = function() eq(main_class({ 'package com.example' }, '/src/main.kt'), 'com.example.MainKt') end

T['main_class()']['replaces characters invalid in a class name like kotlinc'] = function() eq(main_class({}, '/src/my-app.kt'), 'My_appKt') end

T['main_class()']['uses @file:JvmName instead of the file name'] = function()
  eq(main_class({ '@file:JvmName("Launcher")', 'package com.example' }, '/src/main.kt'), 'com.example.Launcher')
end

return T
