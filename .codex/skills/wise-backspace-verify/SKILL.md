---
name: wise-backspace-verify
description: Run repeatable verification for wise-backspace.nvim. Use when Codex is implementing, changing, or reviewing this repository and needs the standard reproducible checks for headless Neovim behavior, dot-repeat behavior, line endings, and repository hygiene.
---

# Wise Backspace Verify

Use this skill when validation must be repeatable for `wise-backspace.nvim`.

## Workflow

1. Run `scripts/verify.ps1` from this skill.
2. Treat a non-zero exit as a blocker before final delivery.
3. Read the printed output. The script reports the Neovim binary used, line-ending scan result, headless test result, `git diff --check`, and `git status --short`.
4. If a check fails, fix the implementation or tests and run the script again.

## Commands

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/skills/wise-backspace-verify/scripts/verify.ps1
```

From elsewhere:

```powershell
powershell -ExecutionPolicy Bypass -File C:/path/to/wise-backspace.nvim/.codex/skills/wise-backspace-verify/scripts/verify.ps1 -Repo C:/path/to/wise-backspace.nvim
```

## Expectations

- Use headless Neovim as the behavior source of truth.
- Keep validation deterministic and local.
- Do not replace failing checks with notifications or swallowed errors.
- Prefer adding a focused regression test before changing behavior.
