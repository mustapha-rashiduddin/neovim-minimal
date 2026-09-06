vim.opt.clipboard = "unnamedplus"
vim.opt.termbidi = true

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
