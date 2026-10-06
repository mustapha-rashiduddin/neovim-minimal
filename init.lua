vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termbidi = true
vim.opt.completeopt = { "menuone", "noselect", "popup" }
-- rust-analyzer fills completion `detail` with absolute source paths; without a
-- cap the popup stretches the full screen width. Truncate instead.
vim.opt.pumwidth = 70
vim.opt.pumheight = 12

vim.g.mapleader = ","
vim.g.NERDSpaceDelims = 1

-- Plugins live outside this repo; a fresh clone needs install.sh to have run.
-- Load them tolerantly so a missing plugin degrades one feature instead of
-- aborting the rest of the config.
local function load_plugin(name)
  if pcall(vim.cmd.packadd, name) then return true end
  vim.schedule(function()
    vim.notify(("plugin %q not installed - run install.sh"):format(name), vim.log.levels.WARN)
  end)
  return false
end

load_plugin("nerdcommenter")
local has_leap = load_plugin("leap.nvim")
local has_blink = load_plugin("blink.cmp")

-- Several ftplugins set `formatoptions` flags that carry the comment leader onto
-- the line you open -- "o" for the `o` command and "r" for <CR>. Neovim's Rust
-- ftplugin, for one, runs `setlocal formatoptions+=croqnl`. Opening a new line
-- off a comment should start uncommented, so drop both flags for every filetype.
-- This runs after each ftplugin, and only these two flags are removed, so
-- autoindent, auto-wrapping and the rest are left alone.
vim.api.nvim_create_autocmd("FileType", {
  callback = function() vim.opt_local.formatoptions:remove({ "o", "r" }) end,
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

-- Motion: leap.nvim. `<leader>s` then one character labels every occurrence
-- of it in the window; press a label to jump there. A lone occurrence is
-- jumped to right away.
--
-- The character is read here and handed to leap as a literal pattern, for two
-- reasons:
--   * leap's own `inputlen = 1` mode only matches a character that is *not*
--     followed by another one, so a run like "llll" yields a single target.
--   * `\V` (very nomagic) makes the pattern literal, so regex metacharacters
--     such as `.` or `*` match themselves. Only a backslash still needs
--     escaping; `vim.pesc` must not be used here, since its `%.`-style
--     escapes are literal under `\V` and would never match.
local leap = has_leap and require("leap") or nil

if leap then
  -- Lowercase-only labels. The default pool is lowercase *then* uppercase, so
  -- a screen with many matches starts handing out capitals, which is awkward
  -- to hit. 26 letters is enough for one screenful; `?` is the overflow label
  -- leap itself appends for group switching.
  leap.opts.labels = "abcdefghijklmnopqrstuvwxyz?"
  leap.opts.safe_labels = "sfnut"
end

-- Number of occurrences of `pattern` in `win`, as leap itself counts them.
-- `leap.search` is the only private module this leans on, hence the pcall:
-- if it ever disappears, we fall back to leap's own autojump heuristic.
local function leap_match_count(pattern, win)
  local ok, search = pcall(require, "leap.search")
  if not ok then return nil end
  local targets = search.get_targets(pattern, { windows = { win }, inputlen = 0 })
  return targets and #targets or 0
end

local function leap_to_char()
  if not leap then return end
  local char = vim.fn.getcharstr()
  if char == "" or char == "\27" then return end
  local pattern = char == "\\" and "\\V\\\\" or "\\V" .. char
  local win = vim.api.nvim_get_current_win()

  -- leap autojumps to the nearest target whenever every *other* target still
  -- fits in `safe_labels`, which means a handful of matches on screen makes it
  -- jump and label the rest -- the choice is made for us. Autojump is only
  -- wanted when the match is unambiguous, so with two or more occurrences we
  -- blank out `safe_labels`, which leaves leap no reason to autojump and makes
  -- it label every match instead.
  local n = leap_match_count(pattern, win)
  leap.leap {
    pattern = pattern,
    windows = { win },
    inclusive = true,
    opts = (n and n > 1) and { safe_labels = "" } or nil,
  }
end

vim.keymap.set({ "n", "x" }, "<leader>s", leap_to_char, { desc = "Leap to character" })

-- <C-w> closes the window.
vim.keymap.set("n", ",w", "<C-w>", { desc = "Close window" })

-- fix_keyboard_input patch encodes XK_h/i/m for Ctrl+Alt (sends CSI u)
-- neovim translates these to <M-BS>, <M-i>, <M-m> internally
vim.keymap.set({ "n", "i" }, "<M-BS>", "<C-w>", { desc = "Delete word backward (Ctrl+Alt+h)" })
-- vim.keymap.set({ "n", "i" }, "<M-i>", "<C-w>", { desc = "Delete word backward (Ctrl+Alt=i) — Emacs: completion-at-point" })
-- vim.keymap.set({ "n", "i" }, "<M-m>", "<C-w>", { desc = "Delete word backward (Ctrl+Alt+m) — Emacs: indent-for-comment" })

local lsp_group = vim.api.nvim_create_augroup("native-lsp", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then return end

    -- Completion keys are owned by blink.cmp (see its setup below). Mapping
    -- them here as well would shadow blink's own buffer-local insert mappings,
    -- which is what left <C-n> unable to open the menu: it called
    -- vim.lsp.completion.get() while no builtin completion source was enabled,
    -- so it silently did nothing.

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        buffer = event.buf,
        silent = true,
        desc = desc,
      })
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
  end,
})

vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml", "rust-project.json", ".git" },
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = false,
      cargo = { allFeatures = true },
      procMacro = { enable = true },
      completion = {
        autoimport = { enable = true },
        fullFunctionSignatures = { enable = true },
      },
      inlayHints = { enable = true },
      semanticHighlighting = { strings = { enable = true } },
    },
  },
  -- Tell rust-analyzer about blink's extra capabilities (snippets, signature
  -- help) so it keeps sending parameterised insert text.
  capabilities = has_blink and require("blink.cmp").get_lsp_capabilities() or nil,
})

vim.lsp.enable("rust_analyzer")

-- blink.cmp: single-plugin completion engine. It replaces nvim-cmp plus the
-- separate LuaSnip/cmp-nvim-lsp/cmp-buffer/cmp-path plugins, expands LSP
-- snippets through the built-in vim.snippet, shows signature help, and inserts
-- brackets from semantic tokens when you accept a function or macro.
if has_blink then
  require("blink.cmp").setup({
    keymap = {
      -- Keep blink's defaults (C-n/C-p select, C-y accept, C-space show,
      -- C-e cancel, Up/Down) and override only what we want to change.
      preset = "default",
      -- blink's own mappings are buffer-local, so nothing else may claim these
      -- keys. Each entry is a chain: blink runs the first command that returns
      -- true, then falls through to the literal key.
      --
      -- Tab cycles the menu while it is open, and otherwise walks snippet
      -- placeholders, which is what makes a function's parameters fillable.
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      -- Enter accepts only when there is something to accept; otherwise it
      -- stays a newline. C-y is blink's own accept.
      ["<CR>"] = {
        function(cmp)
          if cmp.is_visible() then return cmp.accept_and_enter() end
        end,
        "fallback",
      },
    },
    appearance = { nerd_font_variant = "mono" },
    completion = { documentation = { auto_show = false } },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    -- "prefer_rust" uses the prebuilt fuzzy matcher when present and silently
    -- falls back to the Lua implementation, so this works offline too.
    fuzzy = { implementation = "prefer_rust" },
  })
end
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
  local comment_fg = name == "light" and "#4b5563" or "#9ca3af"
  vim.api.nvim_set_hl(0, "Comment", { fg = comment_fg })
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
