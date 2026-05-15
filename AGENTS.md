# AGENTS.md

## Product

`wise-backspace.nvim` provides smart Backspace for Neovim insert mode. It keeps ordinary text deletion native so dot-repeat records Backspace correctly, and only takes over when the cursor is in leading whitespace.

## Scope

- Implement a small Lua plugin, not a dotfiles-only script.
- Expose only one user option: `ignored_filetypes`.
- Use `vim.bo.filetype` for filetype checks.
- Do not implement pair deletion.
- Do not replace buffer text directly during Backspace. Return key sequences from an expression mapping.
- Keep `nvim-autopairs` compatibility by letting users keep `map_bs = false`.

## Behavior

- Non-leading-whitespace Backspace returns native `<BS>`.
- Whitespace-only lines remove all spaces and then return native line deletion to join upward.
- Leading whitespace Backspace moves to the previous proper indent position.
- Prefer a smaller indent returned by `indentexpr`.
- Fall back to the nearest lower `shiftwidth` boundary.
- When the previous non-empty line ends with an opener, keep the fallback target at least one `shiftwidth` deeper than that line.
- If the leading whitespace contains a tab, return native `<BS>` for the initial version.

## Code Style

- Keep the implementation direct and reviewable.
- Avoid defensive branches for states Neovim guarantees.
- Do not swallow errors or replace them with notifications.
- Add helpers only when they clarify the indentation algorithm or make tests precise.

## Testing

- Use headless Neovim tests as the source of truth.
- Test expression return values and real buffer effects.
- Cover ordinary text deletion, dot-repeat behavior, shiftwidth fallback, `indentexpr`, opener fallback, ignored filetypes, tabs in leading whitespace, setup idempotence, and command-line mapping installation.
- Keep repeatable validation steps in the repository skill at `.codex/skills/wise-backspace-verify`.
- Before final delivery, run that skill's `scripts/verify.ps1` workflow unless the environment blocks it.
