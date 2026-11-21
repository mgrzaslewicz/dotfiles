-- `<M-m>t`: the tests of the method around the cursor, the test methods that call it, from anywhere in its body.
-- The callers are those of its whole family (the method, the methods it overrides and their implementations, as
-- `<M-m>c`), kept when they sit in a test file (`is_test_file`); each test is listed once, at its name, the method's
-- own first. One is jumped to, several open a picker. Tests: tests/test_method_tests.lua; replayed on jdtls in
-- tests/test_replay_gradle_java.lua.
--
-- `<M-m>u` runs those tests through neotest: each test file is added to the buffer list (neotest parses a file on
-- BufAdd), and each test is the innermost neotest test position on its name's line, run by its id.
--
-- Known limit: only direct callers count, so a test reaching the method through a helper is not listed.

local implementations = require 'custom.implementations'

local M = {}

--- Whether `path` is a test source: in a test source set (`src/test/`, `src/integrationTest/`, any `src/*Test/`),
--- under a `test/` or `tests/` directory, or named as a test (`FooTest`, `FooTests`, `FooIT`, `FooSpec`, `test_foo`,
--- `foo_test`).
---@param path string
---@return boolean
function M.is_test_file(path)
  if path:find '/src/[%w]*[Tt]est[%w]*/' or path:find '/tests?/' then return true end
  local name = vim.fs.basename(path):match '^(.-)%.[^.]+$' or vim.fs.basename(path)
  return name:match 'Tests?$' ~= nil or name:match 'IT$' ~= nil or name:match 'Spec$' ~= nil or name:match '^test_' ~= nil or name:match '_test$' ~= nil
end

--- The innermost method symbol around `pos` in a documentSymbol tree.
local function method_around(symbols, pos)
  for _, sym in ipairs(symbols) do
    if implementations.contains(sym.range, pos) then
      return method_around(sym.children or {}, pos) or (implementations.METHOD_KINDS[sym.kind] and sym) or nil
    end
  end
end

--- Calls back with the test methods making `calls` (incoming calls in test files), in order, each once, at their
--- names: the method symbol of the test file around the call (jdtls gives a caller's call site as its selection
--- range, and its range starts at the annotations), else the caller's selection range.
local function tests_at_names(calls, callback)
  local uris, symbols = {}, {}
  for _, call in ipairs(calls) do
    if not symbols[call.from.uri] then
      symbols[call.from.uri] = {}
      table.insert(uris, call.from.uri)
    end
  end
  local function done()
    local tests, seen = {}, {}
    for _, call in ipairs(calls) do
      local at = (call.fromRanges[1] or call.from.selectionRange).start
      local sym = method_around(symbols[call.from.uri], at)
      local range = sym and sym.selectionRange or call.from.selectionRange
      local key = ('%s:%d'):format(call.from.uri, range.start.line)
      if not seen[key] then
        seen[key] = true
        local test_name = (sym and sym.name or call.from.name):match '^[^(%s]+'
        table.insert(tests, { uri = call.from.uri, range = range, name = test_name })
      end
    end
    callback(tests)
  end
  local pending = #uris
  if pending == 0 then return done() end
  for _, uri in ipairs(uris) do
    implementations.request_all('textDocument/documentSymbol', { textDocument = { uri = uri } }, function(found)
      symbols[uri] = found
      pending = pending - 1
      if pending == 0 then done() end
    end)
  end
end

--- Calls back with the test methods calling the method around the cursor or its family, in family order, each once
--- (uri, range of its name, name), and the method's name. Outside any method says so and does not call back.
---@param callback fun(tests: {uri: string, range: table, name: string}[], name: string)
function M.collect(callback)
  implementations.method_around_cursor(function(here, name)
    implementations.family_of(here, name, function(family)
      local found, left = {}, #family
      for i, member in ipairs(family) do
        implementations.incoming({ textDocument = { uri = member.uri }, position = member.range.start }, function(calls)
          found[i] = calls
          left = left - 1
          if left > 0 then return end
          local calls = {}
          for j = 1, #family do
            local tested = vim.tbl_filter(function(call) return M.is_test_file(vim.uri_to_fname(call.from.uri)) end, found[j])
            table.sort(tested, function(a, b)
              if a.from.uri ~= b.from.uri then return a.from.uri < b.from.uri end
              return a.from.range.start.line < b.from.range.start.line
            end)
            vim.list_extend(calls, tested)
          end
          tests_at_names(calls, function(tests) callback(tests, name) end)
        end)
      end
    end)
  end)
end

--- Goes to the tests of the method around the cursor (`<M-m>t`): one is jumped to, several open a picker.
function M.goto_tests()
  M.collect(function(tests, name)
    if #tests == 0 then
      vim.notify(('No tests call %s'):format(name), vim.log.levels.INFO)
      return
    end
    if #tests == 1 then
      vim.cmd "normal! m'"
      vim.lsp.util.show_document(tests[1], 'utf-16', { focus = true })
      return
    end
    implementations.pick(tests, ('Tests of %s'):format(name), { keep_order = true })
  end)
end

--- The neotest position ids of `tests`: for each, the innermost test position on the line of its name in the tree
--- `tree_of(path)` gives for its file. Tests without one are left out.
---@param tests {uri: string, range: table}[]
---@param tree_of fun(path: string): table? a neotest.Tree or nil
---@return string[]
function M.position_ids(tests, tree_of)
  local ids, seen = {}, {}
  for _, test in ipairs(tests) do
    local tree, line, best = tree_of(vim.uri_to_fname(test.uri)), test.range.start.line, nil
    for _, pos in tree and tree:iter() or function() end do
      if pos.type == 'test' and pos.range and pos.range[1] <= line and line <= pos.range[3] and (not best or pos.range[1] >= best.range[1]) then best = pos end
    end
    if best and not seen[best.id] then
      seen[best.id] = true
      table.insert(ids, best.id)
    end
  end
  return ids
end

--- Runs the tests of the method around the cursor (`<M-m>u`) through neotest, once neotest has parsed their files
--- (up to 3 s).
function M.run_tests()
  M.collect(function(tests, name)
    if #tests == 0 then
      vim.notify(('No tests call %s'):format(name), vim.log.levels.INFO)
      return
    end
    local neotest = require 'neotest'
    local buffers = {}
    for _, test in ipairs(tests) do
      local path = vim.uri_to_fname(test.uri)
      if not buffers[path] then
        vim.cmd.badd(vim.fn.fnameescape(path))
        buffers[path] = vim.fn.bufnr(path)
      end
    end
    local function tree_of(path)
      for _, adapter in ipairs(neotest.state.adapter_ids()) do
        local tree = neotest.state.positions(adapter, { buffer = buffers[path] })
        if tree then return tree end
      end
    end
    local deadline = vim.uv.now() + 3000
    local function try()
      local ids = M.position_ids(tests, tree_of)
      if #ids < #tests and vim.uv.now() < deadline then return vim.defer_fn(try, 100) end
      if #ids == 0 then
        vim.notify(('neotest knows no test of %s'):format(name), vim.log.levels.WARN)
        return
      end
      for _, id in ipairs(ids) do
        neotest.run.run(id)
      end
    end
    try()
  end)
end

return M
