vim.opt.clipboard = "unnamedplus"
vim.opt.termbidi = true
vim.opt.completeopt = { "menuone", "noselect", "popup" }

-- .v is ambiguous with Verilog; this setup uses it for Rocq sources.
vim.filetype.add({
  extension = {
    v = "coq",
  },
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
