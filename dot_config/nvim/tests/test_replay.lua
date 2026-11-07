-- The replay of contracts (tests/replay.lua): contract format, fixture hash, request keys, and what fails a replayed
-- test. The contracts themselves are exercised by tests/test_replay_<fixture>.lua.
local helpers = require 'tests.helpers'
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['encode()'] = MiniTest.new_set()

T['encode()']['sorts object keys at every level, so equal params give one key'] = function()
  eq(replay.encode { b = 1, a = { d = true, c = 'x' } }, '{"a":{"c":"x","d":true},"b":1}')
  eq(replay.encode { position = { line = 1, character = 2 } }, replay.encode { position = { character = 2, line = 1 } })
end

T['encode()']['keeps lists in order and writes an empty table as a list'] = function()
  eq(replay.encode { 3, 1, { x = 'a/b' } }, '[3,1,{"x":"a/b"}]')
  eq(replay.encode {}, '[]')
end

T['encode()']['indents when asked, one key or item per line'] = function()
  eq(replay.encode({ a = { 1, 2 }, b = {} }, '  '), '{\n  "a": [\n    1,\n    2\n  ],\n  "b": []\n}')
end

T['key()'] = MiniTest.new_set()

T['key()']['is the method and the canonical params'] = function()
  eq(replay.key('textDocument/definition', { textDocument = { uri = 'file:///a' } }), 'textDocument/definition {"textDocument":{"uri":"file:///a"}}')
end

T['generalize() and localize()'] = MiniTest.new_set()

local roots = { { '${fixture}', '/tmp/copy/gradle-java' }, { '${state}', '/tmp/state' } }

T['generalize() and localize()']['swap machine paths for placeholders and back, in every string'] = function()
  local here = { uri = 'file:///tmp/copy/gradle-java/app/Main.java', list = { 'jrt:///tmp/state/data/jbr!/java.base/X.class' } }
  local general = replay.generalize(here, roots)
  eq(general, { uri = 'file://${fixture}/app/Main.java', list = { 'jrt://${state}/data/jbr!/java.base/X.class' } })
  eq(replay.localize(general, { { '${fixture}', '/other/copy' }, { '${state}', '/other/state' } }), {
    uri = 'file:///other/copy/app/Main.java',
    list = { 'jrt:///other/state/data/jbr!/java.base/X.class' },
  })
end

T['generalize() and localize()']['leave a nil result nil'] = function()
  eq(replay.generalize(nil, roots), nil)
  eq(replay.localize(nil, roots), nil)
end

T['fixture_hash()'] = MiniTest.new_set()

T['fixture_hash()']['changes with a file content or a new file'] = function()
  local dir = helpers.tree { ['a.kt'] = 'one', ['src/b.kt'] = 'two' }
  local before = replay.fixture_hash(dir)
  eq(replay.fixture_hash(dir), before)
  vim.fn.writefile({ 'changed' }, dir .. '/src/b.kt')
  local changed = replay.fixture_hash(dir)
  MiniTest.expect.no_equality(changed, before)
  vim.fn.writefile({ 'new' }, dir .. '/c.kt')
  MiniTest.expect.no_equality(replay.fixture_hash(dir), changed)
end

T['fixture_hash()']['ignores build output, server metadata and the fixture README'] = function()
  local dir = helpers.tree { ['a.kt'] = 'one' }
  local before = replay.fixture_hash(dir)
  for _, path in ipairs { 'build/x.class', '.gradle/cache.bin', 'target/x.class', 'bin/x.class', '.settings/x.prefs', '.project', '.classpath', 'README.md' } do
    vim.fn.mkdir(vim.fs.dirname(dir .. '/' .. path), 'p')
    vim.fn.writefile({ 'noise' }, dir .. '/' .. path)
  end
  eq(replay.fixture_hash(dir), before)
end

T['load()'] = MiniTest.new_set()

--- A fixture dir and a contract recorded on it, in a temp contracts dir.
local function recorded()
  local fixtures = helpers.tree { ['tiny/Main.kt'] = 'fun main() {}' }
  local contracts = helpers.tree { ['.keep'] = '' }
  local opts = { fixtures = fixtures, contracts = contracts }
  replay.write(replay.path('tiny', 'kotlin_lsp', opts), {
    fixture = 'tiny',
    server = 'kotlin_lsp',
    server_version = 'v1',
    fixture_hash = replay.fixture_hash(fixtures .. '/tiny'),
    recordings = { { method = 'textDocument/documentSymbol', params = { textDocument = { uri = 'file://${fixture}/Main.kt' } }, result = {} } },
  })
  return fixtures, opts
end

T['load()']['indexes the recordings by key'] = function()
  local _, opts = recorded()
  local contract = replay.load('tiny', 'kotlin_lsp', opts)
  eq(contract.server_version, 'v1')
  eq(vim.tbl_keys(contract.index), { 'textDocument/documentSymbol {"textDocument":{"uri":"file://${fixture}/Main.kt"}}' })
end

T['load()']['fails on a fixture changed since the recording, saying to re-record'] = function()
  local fixtures, opts = recorded()
  vim.fn.writefile({ 'fun main() { println() }' }, fixtures .. '/tiny/Main.kt')
  local ok, err = pcall(replay.load, 'tiny', 'kotlin_lsp', opts)
  eq(ok, false)
  MiniTest.expect.no_equality(tostring(err):find('fixture tiny changed since it was recorded; re-record it with `tests/run.sh --record`', 1, true), nil)
end

T['load()']['fails on a missing contract, saying to record it'] = function()
  local _, opts = recorded()
  local ok, err = pcall(replay.load, 'tiny', 'jdtls', opts)
  eq(ok, false)
  MiniTest.expect.no_equality(tostring(err):find('no contract tiny.jdtls.json; record it with `tests/run.sh --record`', 1, true), nil)
end

T['contracts'] = MiniTest.new_set()

T['contracts']['are recorded with the pinned server versions'] = function()
  local tools = require 'custom.tools'
  local files = vim.fn.globpath(replay.contracts_dir, '*.json', true, true)
  MiniTest.expect.no_equality(#files, 0)
  for _, file in ipairs(files) do
    local contract = replay.decode(table.concat(vim.fn.readfile(file), '\n'))
    eq({ vim.fs.basename(file), contract.server_version }, { vim.fs.basename(file), tools.version(replay.servers[contract.server]) })
  end
end

-- A replayed request needs its recording: without one the test fails, naming the request, instead of getting nothing.
T['a replayed request without a recording fails the test, naming the request'] = function()
  local _, opts = recorded()
  local _, ctx = replay.session('tiny', { kotlin_lsp = {} }, opts)
  ctx.hooks.pre_once()
  MiniTest.finally(ctx.hooks.post_once)
  ctx.hooks.pre_case()
  ctx.edit 'Main.kt'
  ctx.child.lua [[require('custom.implementations').request_all('textDocument/hover', { position = { line = 0, character = 4 } }, function() end)]]
  local message = 'no recording of textDocument/hover {"position":{"character":4,"line":0}} in tiny; record it with `tests/run.sh --record`'
  local ok, err = pcall(ctx.wait, 'hover answered', 'false')
  eq(ok, false)
  MiniTest.expect.no_equality(tostring(err):find(message, 1, true), nil)
  -- Also when the test does not wait for the answer.
  ok, err = pcall(ctx.hooks.post_case)
  eq(ok, false)
  MiniTest.expect.no_equality(tostring(err):find(message, 1, true), nil)
end

T['a replayed request with a recording gets the recorded result, with local paths'] = function()
  local _, opts = recorded()
  local _, ctx = replay.session('tiny', { kotlin_lsp = {} }, opts)
  ctx.hooks.pre_once()
  MiniTest.finally(ctx.hooks.post_once)
  ctx.hooks.pre_case()
  ctx.edit 'Main.kt'
  ctx.child.lua [[
    _G.answer = nil
    require('custom.implementations').request_all('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(0) }, function(r) _G.answer = r end)
  ]]
  ctx.wait('symbols answered', '_G.answer ~= nil')
  eq(ctx.child.lua_get '_G.answer', {})
  ctx.hooks.post_case()
end

return T
