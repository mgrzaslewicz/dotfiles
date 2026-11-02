-- Sources opened from go-to-definition in Kotlin, which kotlin_lsp answers with URIs Neovim cannot read:
--  - `jar:file:///…/src.zip!/java.base/…/X.java`: JDK sources (or `jrt:` class files when no src.zip is known)
--  - `jar:file:///…-sources.jar!/…/X.kt`: library sources from Gradle's cache
-- The text is read from the zip with `unzip -p`, and the buffer is read-only. Class files inside jars have no source
-- here and show a one-line note. Tests: tests/test_jdk_source.lua; e2e in tests/e2e/test_gradle_kotlin.lua.
-- Known limit: the JDK source is the one on this machine ($JAVA_HOME, else `java` on PATH), not kotlin_lsp's JDK.

local M = {}

--- Path of the source file in src.zip for a `jrt:` class URI, e.g. `java.base/java/util/ArrayList.java`.
--- Nested and anonymous classes (`Map$Entry`, `HashMap$1`) map to their outer class's source.
---@param uri string
---@return string?
function M.entry(uri)
  local path = uri:match '^jrt:.-!/(.+)%.class$'
  if not path then return nil end
  return (path:gsub('%$.*$', '')) .. '.java'
end

--- JDK home for source lookup: $JAVA_HOME, else the JDK that `java` on PATH belongs to.
---@return string?
function M.java_home()
  if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= '' then return vim.env.JAVA_HOME end
  local java = vim.fn.exepath 'java'
  if java == '' then return nil end
  local real = vim.uv.fs_realpath(java) or java
  return vim.fs.dirname(vim.fs.dirname(real))
end

--- Splits a `jar:` URI into the zip path and the entry inside it. kotlin_lsp sends `jar:///path/x.zip!/entry/X.kt`
--- (no `file:` scheme); `jar:file:///…` is accepted too.
---@param uri string
---@return string?, string?
function M.jar_entry(uri)
  local rest, entry = uri:match '^jar:(.-)!/(.+)$'
  if not rest then return nil, nil end
  local path = rest:gsub('^file:', ''):gsub('^/+', '/')
  return vim.uri_to_fname('file://' .. path), entry
end

--- Text of `entry` inside the zip (or jar) at `zip`, or nil when it is not there.
---@param zip string
---@param entry string
---@return string?
function M.read_zip(zip, entry)
  local done = vim.system({ 'unzip', '-p', zip, entry }, { text = true }):wait()
  if done.code ~= 0 then return nil end
  return done.stdout
end

--- Source text for a `jrt:` or `jar:` URI, or nil when none can be read.
---@param uri string
---@return string?
function M.source(uri)
  local zip, entry
  if vim.startswith(uri, 'jar:') then
    zip, entry = M.jar_entry(uri)
  else
    local home = M.java_home()
    zip = home and vim.fs.joinpath(home, 'lib', 'src.zip')
    entry = M.entry(uri)
  end
  if not zip or not entry or entry:match '%.class$' then return nil end
  return M.read_zip(zip, entry)
end

--- Attaches the running kotlin_lsp to a source buffer, so go-to-definition works inside it. kotlin_lsp's root_dir cannot
--- root a `jar:`/`jrt:` name and its filetypes do not include `java`, so the lspconfig path never attaches it here.
---@param buf integer
function M.attach_kotlin_lsp(buf)
  local client = vim.lsp.get_clients({ name = 'kotlin_lsp' })[1]
  if client then vim.lsp.buf_attach_client(buf, client.id) end
end

--- Reads `jrt:` and `jar:` buffers from their source zip, and fixes nvim-jdtls's `*.class` reader for them (below).
function M.setup()
  -- nvim-jdtls registers its readers when its plugin/ files are sourced: after init.lua, before VimEnter.
  if vim.v.vim_did_enter == 1 then
    M.replace_class_reader()
  else
    vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = M.replace_class_reader })
  end

  local group = vim.api.nvim_create_augroup('custom-jdk-source', { clear = true })
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    -- A pattern without `/` would match only the file name's tail, so it needs the slash.
    pattern = { 'jrt:*/*', 'jar:*/*' },
    callback = function(args)
      local text = M.source(args.match)
      if not text then text = ('// Source of %s not found in this JDK or its sources.'):format(args.match) end
      vim.bo[args.buf].modifiable = true
      vim.bo[args.buf].swapfile = false
      vim.bo[args.buf].buftype = 'nofile'
      vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, vim.split(text, '\r?\n'))
      vim.bo[args.buf].filetype = vim.filetype.match { filename = args.match:match '[^/]*$' } or 'java'
      vim.bo[args.buf].modifiable = false
      M.attach_kotlin_lsp(args.buf)
    end,
  })
end

--- nvim-jdtls also reads every `*.class` buffer, and a `jrt:…/ArrayList.class` URI matches that pattern. Its reader
--- asserts a jdtls client, which a Kotlin buffer never has, and the error aborts the read. Replace it with one that
--- leaves `jrt:` URIs to `M.setup`'s reader and otherwise hands over to nvim-jdtls as before.
function M.replace_class_reader()
  if not pcall(vim.api.nvim_clear_autocmds, { group = 'jdtls', event = 'BufReadCmd', pattern = '*.class' }) then return end
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = 'jdtls',
    pattern = '*.class',
    callback = function(args)
      if vim.startswith(args.match, 'jrt:') or vim.startswith(args.match, 'jar:') then return end
      require('jdtls').open_classfile(args.buf, args.match)
    end,
  })
end

return M
