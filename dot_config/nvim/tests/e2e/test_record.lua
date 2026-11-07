-- The recording step of `tests/run.sh --record` (tests/replay.lua) on fixtures/gradle-kotlin, against a real
-- kotlin-lsp, into a temp contracts dir: what a recorded contract holds, and that a failed request keeps the old one.
local replay = require 'tests.replay'
local eq = MiniTest.expect.equality

local MAIN = 'app/src/main/kotlin/com/example/app/Main.kt'
local contracts = vim.fn.tempname()
local path = vim.fs.joinpath(contracts, 'gradle-kotlin.kotlin_lsp.json')
local store = {}
local _, ctx = replay.session(
  'gradle-kotlin',
  { kotlin_lsp = { file = MAIN, symbol = 'greet', target = 'lib/src/main/kotlin/com/example/lib/Greeter.kt' } },
  { mode = 'record', contracts = contracts, store = store }
)
local child = ctx.child

local T = MiniTest.new_set {
  hooks = {
    pre_once = ctx.hooks.pre_once,
    post_once = function()
      ctx.hooks.post_once()
      vim.fn.delete(contracts, 'rf')
    end,
  },
}

--- Sends `method` through the request seam from the current buffer and waits for its callback.
local function request(method, params)
  child.lua(
    [[
    local method, params = ...
    _G.answered = false
    require('custom.implementations').request_all(method, params, function() _G.answered = true end)
  ]],
    { method, params }
  )
  ctx.wait(method .. ' answered', '_G.answered')
end

--- Records what a case sends with `send`, then writes the contracts; returns `finish_recording`'s result and lines.
local function record(send)
  for key in pairs(store) do
    store[key] = nil
  end
  ctx.hooks.pre_case()
  ctx.edit(MAIN)
  send()
  ctx.hooks.post_case()
  local lines = {}
  local ok = replay.finish_recording(store, { print = function(line) table.insert(lines, line) end })
  return ok, lines
end

T['gradle-kotlin | record | writes the server version, the fixture hash and each request with its answer'] = function()
  local uri = 'file://${fixture}/' .. MAIN
  local ok, lines = record(function() request('textDocument/documentSymbol', { textDocument = { uri = vim.uri_from_fname(ctx.project .. '/' .. MAIN) } }) end)
  eq(
    { ok, lines },
    { true, { 'recorded gradle-kotlin.kotlin_lsp.json, 1 request(s):', '  textDocument/documentSymbol {"textDocument":{"uri":"' .. uri .. '"}}' } }
  )
  local contract = replay.decode(table.concat(vim.fn.readfile(path), '\n'))
  eq({ contract.fixture, contract.server, contract.server_version, contract.fixture_hash }, {
    'gradle-kotlin',
    'kotlin_lsp',
    require('custom.tools').version 'kotlin-lsp',
    replay.fixture_hash(vim.fs.joinpath(replay.fixtures_dir, 'gradle-kotlin')),
  })
  eq(#contract.recordings, 1)
  local rec = contract.recordings[1]
  eq({ rec.method, rec.params }, { 'textDocument/documentSymbol', { textDocument = { uri = uri } } })
  eq(vim.tbl_contains(vim.tbl_map(function(s) return s.name end, rec.result), 'greeting'), true)
end

T['gradle-kotlin | record | a request answered with an error keeps the old contract, and is reported'] = function()
  local before = vim.fn.readfile(path)
  local ok, lines = record(function() request('textDocument/notAMethod', { textDocument = { uri = vim.uri_from_fname(ctx.project .. '/' .. MAIN) } }) end)
  eq({ ok, lines[1] }, { false, 'kept gradle-kotlin.kotlin_lsp.json unchanged, 1 failure(s):' })
  eq(vim.startswith(lines[2], '  failed textDocument/notAMethod '), true)
  eq(vim.fn.readfile(path), before)
end

return T
