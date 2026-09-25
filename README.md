# neovim-minimal

Minimal Neovim config, Rocq/coq oriented.

## Install

Clone the config, then run the install script once:

```sh
git clone git@github.com:mustapha-rashiduddin/neovim-minimal.git ~/.config/nvim
~/.config/nvim/install.sh
```

The script clones the plugins that `init.lua` loads with `packadd()` into
Neovim's package directory (`~/.local/share/nvim/site/pack/core/opt`), pinned to
specific commits. That directory sits outside this repo, so the config alone is
not enough to get a working setup on a new machine.

## Plugins

| Plugin        | Upstream                                          |
| ------------- | ------------------------------------------------- |
| nerdcommenter | https://github.com/preservim/nerdcommenter        |
| leap.nvim     | https://codeberg.org/andyg/leap.nvim              |

leap.nvim moved to Codeberg; the GitHub repository of the same name is dead.

## Keys

`<leader>` is `,`.

| Keys   | Action                                          |
| ------ | ----------------------------------------------- |
| `,s`   | leap: type a character, then a label to jump    |

`,s` takes exactly one character and labels **every** occurrence of it in the
window, including runs like `llll`. Press a label to jump to that match.

- The character is matched literally, so regex metacharacters (`.`, `*`, `[`,
  `\`, ...) match themselves.
- With few enough matches, leap jumps to the nearest one instead of labeling.
- With more matches than labels, `<space>` and `<backspace>` page through them.
- `Escape` cancels.

Works in normal and visual mode.

## Theme

`theme.lua` holds the colorscheme name (`"light"` or `"dark"`). `init.lua`
polls that file, so editing it live-switches the running editor.
