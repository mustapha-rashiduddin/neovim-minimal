vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termbidi = true
vim.opt.completeopt = { "menuone", "noselect", "popup" }

vim.g.mapleader = ","
vim.g.NERDSpaceDelims = 1
vim.cmd.packadd("nerdcommenter")

-- .v is ambiguous with Verilog; this setup uses it for Rocq sources.
vim.filetype.add({
  extension = {
    v = "coq",
  },
})

local config_dir = vim.fn.stdpath("config")
local rocq_completion_sources = {
  { path = config_dir .. "/dict/rocq-commands", menu = "[Command]" },
  { path = config_dir .. "/dict/rocq-tactics", menu = "[Tactic]" },
  { path = config_dir .. "/dict/rocq-keywords", menu = "[Keyword]" },
  { path = config_dir .. "/dict/rocq-core", menu = "[Core]" },
}
local rocq_dictionary, rocq_dictionary_menu, rocq_dictionary_paths = {}, {}, {}
for _, source in ipairs(rocq_completion_sources) do
  table.insert(rocq_dictionary_paths, source.path)
  for _, word in ipairs(vim.fn.readfile(source.path)) do
    if not rocq_dictionary_menu[word] then
      rocq_dictionary_menu[word] = source.menu
      table.insert(rocq_dictionary, word)
    end
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("rocq-settings", { clear = true }),
  pattern = "coq",
  callback = function(event)
    vim.opt_local.complete:append("k")
    vim.bo[event.buf].dictionary = table.concat(rocq_dictionary_paths, ",")
    vim.bo[event.buf].expandtab = true
    vim.bo[event.buf].shiftwidth = 2
    vim.bo[event.buf].softtabstop = 2
    vim.bo[event.buf].tabstop = 2
  end,
})

vim.diagnostic.config({
  severity_sort = true,
  signs = true,
  underline = true,
  virtual_text = {
    source = "if_many",
    spacing = 2,
  },
  float = {
    border = "rounded",
    source = true,
  },
})

local lsp_group = vim.api.nvim_create_augroup("native-lsp", { clear = true })
local keyword_completion_scheduled = {}

local function complete_rocq_keywords(bufnr)
  keyword_completion_scheduled[bufnr] = nil
  if
    not vim.api.nvim_buf_is_valid(bufnr)
    or vim.api.nvim_get_current_buf() ~= bufnr
    or not vim.api.nvim_get_mode().mode:match("^i")
    or vim.fn.pumvisible() == 1
  then
    return
  end

  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
  local line_to_cursor = vim.api.nvim_get_current_line():sub(1, cursor_col)
  local prefix = line_to_cursor:match("[%w_']+$")
  if not prefix then return end

  local ignore_case = vim.o.ignorecase and (not vim.o.smartcase or not prefix:find("%u"))
  local match_prefix = ignore_case and prefix:lower() or prefix
  local seen, items = {}, {}
  local function add(word, menu)
    local match_word = ignore_case and word:lower() or word
    if word ~= prefix and not seen[word] and vim.startswith(match_word, match_prefix) then
      seen[word] = true
      table.insert(items, { word = word, menu = menu, icase = ignore_case and 1 or 0 })
    end
  end

  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for word in line:gmatch("[%a_][%w_']*") do
      add(word, rocq_dictionary_menu[word] or "[Buffer]")
    end
  end
  for _, word in ipairs(rocq_dictionary) do
    add(word, rocq_dictionary_menu[word])
  end

  if #items > 0 then
    vim.fn.complete(cursor_col - #prefix + 1, items)
  end
end

-- coq-lsp only advertises "\\" as a completion trigger. Start Neovim's
-- buffer and Rocq keyword completion while identifiers are typed.
vim.api.nvim_create_autocmd("InsertCharPre", {
  group = lsp_group,
  callback = function(event)
    if vim.bo[event.buf].filetype ~= "coq"
        or vim.fn.pumvisible() == 1
        or keyword_completion_scheduled[event.buf]
        or vim.fn.state("m") == "m" then
      return
    end

    if vim.v.char == "'" or vim.fn.match(vim.v.char, [[\k]]) >= 0 then
      keyword_completion_scheduled[event.buf] = true
      vim.schedule(function() complete_rocq_keywords(event.buf) end)
    end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then return end

    vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })

    local function map(mode, lhs, rhs, desc, opts)
      vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", {
        buffer = event.buf,
        silent = true,
        desc = desc,
      }, opts or {}))
    end

    map("n", "gd", vim.lsp.buf.definition, "LSP: go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "LSP: go to declaration")
    map("n", "grr", vim.lsp.buf.references, "LSP: list references")
    map("n", "gri", vim.lsp.buf.implementation, "LSP: go to implementation")
    map("n", "K", vim.lsp.buf.hover, "LSP: hover documentation")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: rename symbol")
    map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
    map("n", "<leader>ds", vim.lsp.buf.document_symbol, "LSP: document symbols")
    map("n", "<leader>ws", vim.lsp.buf.workspace_symbol, "LSP: workspace symbols")
    map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic")
    map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
    map("n", "<leader>e", vim.diagnostic.open_float, "Show diagnostic")

    map("i", "<Tab>", function()
      return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
    end, "Select next completion", { expr = true })
    map("i", "<S-Tab>", function()
      return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
    end, "Select previous completion", { expr = true })
    map("i", "<CR>", function()
      local completion = vim.fn.complete_info({ "selected" })
      if vim.fn.pumvisible() == 1 and completion.selected ~= -1 then
        return "<C-y>"
      end
      return "<CR>"
    end, "Confirm completion", { expr = true })
  end,
})

vim.lsp.config("rocq_lsp", {
  cmd = { "coq-lsp" },
  filetypes = { "coq" },
  root_markers = { "_RocqProject", "_CoqProject", ".git" },
})

vim.lsp.enable("rocq_lsp")

-- Theme: switch built-in colorscheme from theme.lua (morning/evening).
-- Polls theme.lua so an already-open nvim updates live when `light`/`dark` runs.
local THEME_FILE = vim.fn.expand("~/.config/nvim/theme.lua")
local last_content = nil

local function apply_theme(c)
  local name = c:match('return%s+"([^"]+)"') or "dark"
  local scheme = "morning"
  if name == "light" then
    scheme = "morning"
    vim.o.background = "light"
  else
    scheme = "evening"
    vim.o.background = "dark"
  end
  pcall(vim.cmd.colorscheme, scheme)
end

local function read_theme()
  local f = io.open(THEME_FILE, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function watch()
  local c = read_theme()
  if c and c ~= last_content then
    last_content = c
    apply_theme(c)
  end
  vim.defer_fn(watch, 3000)
end

watch()

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(event.buf) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})
