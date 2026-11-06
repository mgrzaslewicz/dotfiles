-- Treats a response with neither `result` nor `error` as a null result, for servers that leave out a null result.
-- jdtls does so, e.g. on go-to-type-definition of a call that returns a primitive (`grM` on
-- `counter.incrementAndGet()`). Neovim rejects such a response as INVALID_SERVER_MESSAGE: it shows the error and
-- drops the response, so the request's callback never runs and whatever waits for it (buf_request_all, `grM`) hangs.
-- Tests: tests/test_lsp_missing_result.lua.
--
-- `patch` is an `on_init`: it wraps the client's rpc.request to keep each pending request's callbacks, and its
-- write_error, which Neovim calls with the rejected message, to answer the request instead.

local M = {}

---@param client vim.lsp.Client
function M.patch(client)
  local pending = {} ---@type table<integer, {callback: function, notify_reply: function?}>
  local request = client.rpc.request
  client.rpc.request = function(method, params, callback, notify_reply)
    local ok, id = request(method, params, function(err, result, request_id)
      pending[request_id] = nil
      callback(err, result, request_id)
    end, notify_reply)
    if ok and id then pending[id] = { callback = callback, notify_reply = notify_reply } end
    return ok, id
  end

  ---@diagnostic disable-next-line: invisible
  local write_error = client.write_error
  ---@diagnostic disable-next-line: invisible, duplicate-set-field
  client.write_error = function(self, code, err)
    local missing = code == vim.lsp.rpc.client_errors.INVALID_SERVER_MESSAGE
      and type(err) == 'table'
      and err.result == nil
      and err.error == nil
      and pending[err.id]
    if not missing then return write_error(self, code, err) end
    pending[err.id] = nil
    vim.schedule(function()
      if missing.notify_reply then missing.notify_reply(err.id) end
      missing.callback(nil, nil, err.id)
    end)
  end
end

return M
