# neovim-minimal

Minimal Neovim config.

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
| blink.cmp     | https://github.com/Saghen/blink.cmp               |

leap.nvim moved to Codeberg; the GitHub repository of the same name is dead.

blink.cmp is the completion engine and owns the insert-mode completion keys.
Its native `vim.snippet` support is what expands the snippets rust-analyzer
sends, so accepting a function or macro fills in its parameters.

## Keys

`<leader>` is `,`.

| Keys   | Action                                          |
| ------ | ----------------------------------------------- |
| `,s`   | leap: type a character, then a label to jump    |
| `,w`   | close window                                    |

### Completion

The menu opens by itself as you type. No key opens it explicitly; `C-space`
re-opens it.

| Keys            | Action                                    |
| --------------- | ----------------------------------------- |
| `C-n` / `C-p`   | next / previous item                      |
| `Tab`/`S-Tab`   | next / previous item, else next/previous placeholder |
| `C-y`           | accept                                    |
| `Enter`         | accept while the menu is open, else newline |
| `C-e`           | dismiss the menu                          |
| `C-k`           | toggle the signature help                 |

Accepting a function or macro inserts its brackets and one placeholder per
argument; `Tab` moves between them.

`,s` takes exactly one character and labels **every** occurrence of it in the
window, including runs like `llll`. Press a label to jump to that match.

- The character is matched literally, so regex metacharacters (`.`, `*`, `[`,
  `\`, ...) match themselves.
- Labels are lowercase only, `a` to `z` plus `?`. leap's default pool adds
  capitals once a screen has many matches; this keeps every label lowercase.
- With exactly one occurrence on screen (the one under the cursor doesn't
  count), leap jumps to it right away.
- With two or more, all of them are labeled and nothing is jumped to for you.
- With more matches than labels, `<space>` and `<backspace>` page through them.
- `Escape` cancels.

Works in normal and visual mode.

## Rust

`init.lua` configures rust-analyzer and hands it blink.cmp's capabilities, so
the server keeps sending parameterised insert text.

### rustlings needs its exercises registered as targets

rustlings only builds `src/main.rs`. Its `exercises/**/*.rs` files are not part
of any crate, so rust-analyzer treats them as **detached files** and offers no
completions for them at all — not just poor ones, none. Measured on
`exercises/01_variables/variables1.rs`: zero items returned with an upstream
manifest, twelve once the files are registered.

Registering them means adding a `[[bin]]` entry per exercise to rustlings'
`Cargo.toml`. Two details matter:

- `required-features = ["rustlings_exercises"]` on each, otherwise `cargo build`
  tries to compile exercises that are *meant* to fail.
- `default-run = "rustlings"` in `[package]`, because with 95 binaries `cargo run`
  can no longer pick one and errors out.

rustlings is not a git repository, so none of this is version controlled and a
fresh clone silently loses it. The symptom is only ever "no completions in
exercise files" — no error anywhere. If that happens, re-add the entries:

```sh
cd ~/rnd/rustlings
grep -q '^default-run' Cargo.toml || sed -i \
  '0,/^name = "rustlings"$/s//name = "rustlings"\ndefault-run = "rustlings"/' Cargo.toml
find exercises -name '*.rs' | sort | while IFS= read -r f; do
  grep -q "^path = \"$f\"$" Cargo.toml && continue
  printf '\n[[bin]]\nname = "%s"\npath = "%s"\nrequired-features = ["rustlings_exercises"]\n' \
    "$(basename "$f" .rs)" "$f" >>Cargo.toml
done
cargo metadata --format-version 1 --no-deps   # validate
```

That is idempotent, and `cargo run -- --version` should print `rustlings <ver>`.

## Theme

`theme.lua` holds the colorscheme name (`"light"` or `"dark"`). `init.lua`
polls that file, so editing it live-switches the running editor.
