-- Go to Class (IntelliJ Ctrl+N): workspace symbols with a fuzzy, package-aware prompt, e.g. `java.io InputStream`.
--
-- Telescope's dynamic workspace symbols sends the whole prompt to the server, and jdtls matches it against type
-- names only, so `java.io InputStream` finds nothing. Here only one word goes to the server as the query (the first
-- containing an uppercase letter, else the last word); the whole prompt then fuzzy-filters the results, whose
-- ordinal includes the file path / jdt:// URI and so the package. jdtls returns JDK and library types only because
-- nvim-jdtls advertises `classFileContentsSupport` (see custom/plugins/jdtls.lua).

---@param opts? table telescope picker options, plus `symbols` (kinds to keep, as for builtin.lsp_*_symbols)
return function(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local channel = require('plenary.async.control').channel
  local conf = require('telescope.config').values
  local cancel = function() end
  require('telescope.pickers')
    .new(opts, {
      prompt_title = opts.prompt_title or 'Go to Class',
      finder = require('telescope.finders').new_dynamic {
        entry_maker = require('telescope.make_entry').gen_from_lsp_symbols(opts),
        fn = function(prompt)
          local words = vim.split(prompt, '%s+', { trimempty = true })
          local query = words[#words] or ''
          for _, word in ipairs(words) do
            if word:match '%u' then
              query = word
              break
            end
          end
          if query == '' then return {} end
          local tx, rx = channel.oneshot()
          cancel()
          cancel = vim.lsp.buf_request_all(bufnr, 'workspace/symbol', { query = query }, tx)
          local items = {}
          for client_id, res in pairs(rx()) do
            local client = vim.lsp.get_client_by_id(client_id)
            if res.result and client then vim.list_extend(items, vim.lsp.util.symbols_to_items(res.result, bufnr, client.offset_encoding)) end
          end
          return require('telescope.utils').filter_symbols(items, opts) or {}
        end,
      },
      sorter = conf.generic_sorter(opts),
      previewer = conf.qflist_previewer(opts),
    })
    :find()
end
