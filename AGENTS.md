# AGENTS.md

## Product

`wise-backspace.nvim` provides smart Backspace for Neovim insert mode. It keeps ordinary text deletion native so dot-repeat records Backspace correctly, handles simple pair deletion, and takes over indentation only when the cursor is in leading whitespace.

## Scope

- Implement a small Lua plugin, not a dotfiles-only script.
- Expose only one user option: `ignored_filetypes`.
- Use `vim.bo.filetype` for filetype checks.
- Support simple matched pair deletion with returned key sequences.
- Do not replace buffer text directly during Backspace. Return key sequences from an expression mapping.
- Keep `nvim-autopairs` compatibility by letting users keep `map_bs = false`.

## Behavior

- Non-leading-whitespace Backspace returns native `<BS>`.
- When the cursor is between a simple matched pair, return `<BS><Del>`.
- When the cursor's left side contains only spaces or tabs, behave as if the cursor were at the first non-whitespace character or at end of line.
- First-line leading indentation is removed without joining upward.
- Over-indented lines reduce to the previous non-empty line's indentation.
- After an opening pair or before a dot-prefixed continuation, over-indentation reduces to one `shiftwidth` deeper than the previous non-empty line; already-correct indentation joins upward.
- Whitespace-only empty bracket blocks collapse onto one line.
- Otherwise, leading indentation is removed and native line deletion joins upward.

## Code Style

- Keep the implementation direct and reviewable.
- Avoid defensive branches for states Neovim guarantees.
- Do not swallow errors or replace them with notifications.
- Add helpers only when they clarify the indentation algorithm or make tests precise.

## Testing

- Use headless Neovim tests as the source of truth.
- Test expression return values and real buffer effects.
- Cover ordinary text deletion, dot-repeat behavior, indentation reduction, indentation-sensitive joining, empty bracket block collapse, pair deletion, ignored filetypes, tabs in leading whitespace, setup idempotence, and command-line mapping installation.
- Keep repeatable validation steps in the repository skill at `.codex/skills/wise-backspace-verify`.
- Before final delivery, run that skill's `scripts/verify.ps1` workflow unless the environment blocks it.
