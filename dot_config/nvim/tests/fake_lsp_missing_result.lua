-- Stdio LSP server for tests/test_lsp_missing_result.lua, run with `nvim -l`. Answers textDocument/typeDefinition the
-- way jdtls does on a call returning a primitive: a response with neither `result` nor `error`.
local function write(body)
  io.write(('Content-Length: %d\r\n\r\n%s'):format(#body, body))
  io.flush()
end

while true do
  local length
  repeat
    local line = io.read 'l'
    if not line then return end
    line = line:gsub('\r$', '')
    length = tonumber(line:match '^Content%-Length: (%d+)') or length
  until line == ''
  local msg = vim.json.decode(io.read(length))
  if msg.method == 'initialize' then
    write(vim.json.encode { jsonrpc = '2.0', id = msg.id, result = { capabilities = { typeDefinitionProvider = true } } })
  elseif msg.method == 'textDocument/typeDefinition' then
    write(('{"jsonrpc":"2.0","id":%d}'):format(msg.id))
  elseif msg.method == 'shutdown' then
    write(vim.json.encode { jsonrpc = '2.0', id = msg.id, result = vim.NIL })
  elseif msg.method == 'exit' then
    return
  end
end
