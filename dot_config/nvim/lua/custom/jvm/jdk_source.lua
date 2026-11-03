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

--- Declarations of a Java source text, from its tree-sitter tree: types, constructors and methods, nested ones
--- included, in source order. `lnum` is 1-based and `col` the 0-based byte column of the name, as the cursor wants them.
---@param text string
---@return { text: string, kind: string, lnum: integer, col: integer }[]
function M.declarations(text)
  local kinds = {
    class_declaration = 'Class',
    interface_declaration = 'Interface',
    enum_declaration = 'Enum',
    record_declaration = 'Record',
    constructor_declaration = 'Constructor',
    method_declaration = 'Method',
  }
  local items = {}
  local function walk(node)
    for child in node:iter_children() do
      local kind = kinds[child:type()]
      local name = kind and child:field('name')[1]
      if name then
        local row, col = name:start()
        items[#items + 1] = { text = vim.treesitter.get_node_text(name, text), kind = kind, lnum = row + 1, col = col }
      end
      walk(child)
    end
  end
  walk(vim.treesitter.get_string_parser(text, 'java'):parse()[1]:root())
  return items
end

--- Document symbols for a JDK source buffer. kotlin_lsp answers `textDocument/documentSymbol` with nothing for a `jar:`
--- buffer, so when the server has no symbols the declarations are listed from the buffer's Java text instead.
function M.document_symbols()
  local buf = vim.api.nvim_get_current_buf()
  vim.lsp.buf_request_all(buf, 'textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(buf) }, function(results)
    for _, r in pairs(results) do
      if r.result and not vim.tbl_isempty(r.result) then return require('telescope.builtin').lsp_document_symbols() end
    end
    local items = M.declarations(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
    if #items == 0 then return vim.notify('No declarations found in the JDK source', vim.log.levels.WARN) end
    vim.ui.select(items, {
      prompt = 'JDK source symbols',
      format_item = function(item) return ('%s %s (%d)'):format(item.kind, item.text, item.lnum) end,
    }, function(item)
      if item then vim.api.nvim_win_set_cursor(0, { item.lnum, item.col }) end
    end)
  end)
end

--- Attaches the running kotlin_lsp to a source buffer, so go-to-definition works inside it. kotlin_lsp's root_dir cannot
--- root a `jar:`/`jrt:` name and its filetypes do not include `java`, so the lspconfig path never attaches it here.
---@param buf integer
function M.attach_kotlin_lsp(buf)
  local client = vim.lsp.get_clients({ name = 'kotlin_lsp' })[1]
  if client then vim.lsp.buf_attach_client(buf, client.id) end
end

--- Path in src.zip of the JDK class named `word`, from the buffer's own text: an explicit import, else its package,
--- else `java.lang`. Wildcard imports are not followed. Returns nil for something that is not an identifier.
---@param word string
---@param lines string[]
---@return string?
function M.class_path(word, lines)
  if not word:match '^[%a_][%w_]*$' then return nil end
  local pkg
  for _, line in ipairs(lines) do
    pkg = pkg or line:match '^package%s+([%w_%.]+)'
    local fqn = line:match('^import%s+([%w_%.]+%.' .. word .. ')%s*;?%s*$')
    if fqn then return (fqn:gsub('%.', '/')) .. '.java' end
  end
  return ((pkg or 'java.lang'):gsub('%.', '/')) .. '/' .. word .. '.java'
end

--- The src.zip entry ending in `path`, e.g. `java.base/java/util/Objects.java` for `java/util/Objects.java`.
---@param names string[]
---@param path string
---@return string?
function M.find_entry(names, path)
  for _, name in ipairs(names) do
    if name == path or name:sub(-#path - 1) == '/' .. path then return name end
  end
end

--- The zip a JDK source buffer was read from: the `jar:` URI's file, or the JDK's src.zip for a `jrt:` one.
---@param name string buffer name
---@return string?
local function zip_of(name)
  if vim.startswith(name, 'jar:') then return (M.jar_entry(name)) end
  local home = M.java_home()
  return home and vim.fs.joinpath(home, 'lib', 'src.zip')
end

local zip_names = {}

--- Entry names of a zip, listed once per zip.
---@param zip string
---@return string[]
local function list_zip(zip)
  if not zip_names[zip] then
    local done = vim.system({ 'unzip', '-Z1', zip }, { text = true }):wait()
    zip_names[zip] = done.code == 0 and vim.split(done.stdout, '\n', { trimempty = true }) or {}
  end
  return zip_names[zip]
end

--- Go to definition for the word under the cursor in a JDK source buffer. The server is asked first, which answers
--- in-file symbols and what it can resolve; when it has nothing (kotlin_lsp does not resolve JDK-to-JDK references
--- inside a `jar:` buffer), the class is looked up by its import or package in the same src.zip and opened from there.
function M.goto_definition()
  local buf = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand '<cword>'
  local params = vim.lsp.util.make_position_params(0, 'utf-16')
  vim.lsp.buf_request_all(buf, 'textDocument/definition', { textDocument = params.textDocument, position = params.position }, function(results)
    for _, r in pairs(results) do
      -- An empty list is truthy in Lua, so take the first location explicitly.
      local loc = vim.islist(r.result) and r.result[1] or (not vim.islist(r.result) and r.result) or nil
      if loc then return vim.lsp.util.show_document(loc, 'utf-16', { reuse_win = true }) end
    end
    local zip = zip_of(vim.api.nvim_buf_get_name(buf))
    local path = M.class_path(word, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    local entry = zip and path and M.find_entry(list_zip(zip), path)
    if not entry then return vim.notify(('No definition of %s in the JDK sources'):format(word), vim.log.levels.WARN) end
    vim.cmd.edit(vim.fn.fnameescape(('jar://%s!/%s'):format(zip, entry)))
  end)
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
  -- The LSP attach maps `grd` and `gO` to Telescope, which shows nothing for a JDK-to-JDK jump or for the symbols of a
  -- `jar:` buffer, so both are mapped again after the attach and on every entry into the buffer.
  local function map_goto(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.keymap.set('n', 'grd', M.goto_definition, { buffer = buf, desc = '[G]oto [D]efinition in JDK source' })
    vim.keymap.set('n', 'gO', M.document_symbols, { buffer = buf, desc = 'Open Document Symbols in JDK source' })
  end
  vim.api.nvim_create_autocmd({ 'BufEnter', 'LspAttach' }, {
    group = group,
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf)
      if vim.startswith(name, 'jrt:') or vim.startswith(name, 'jar:') then vim.schedule(function() map_goto(args.buf) end) end
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
