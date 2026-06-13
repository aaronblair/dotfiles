# Global Agent Instructions

## Tooling Defaults

### Python
- Always use `uv` for environment and package management.
- Use `uv run` to execute scripts, `uv venv` to create virtual environments,
  `uv add` to add dependencies (pyproject.toml), `uv pip` when pip semantics
  are needed.
- Never use bare `pip`, `pip3`, `virtualenv`, `conda`, or `poetry`.

### JavaScript / TypeScript
- Prefer Node.js with `pnpm` as the safe default for JavaScript and TypeScript
  work.
- Respect the project's declared package manager first: check `packageManager`
  in `package.json` and existing lockfiles before running install commands.
- If no package manager is declared, use `pnpm`.
- Use `pnpm install`, `pnpm run <script>`, `pnpm exec <bin>`, `pnpm dlx <pkg>`,
  and `pnpm test` when using pnpm.
- Use `node` for direct script execution; do not use `bun` unless the project
  explicitly declares Bun.
- Do not introduce or replace lockfiles unless dependency changes are intended.

### Go
- Use the standard Go toolchain: `go run`, `go test`, `go build`,
  `go mod tidy`.

### Shell
- Interactive shell is `zsh`. Write shell scripts in `bash` for portability.
- Use POSIX-compatible commands where possible.

### Docker
- Use `docker compose` (v2), not `docker-compose`.

## Git Conventions

- Follow the repository's existing commit and branch conventions when they are
  documented or obvious from history.
- If no repository convention exists, use `type(scope): description` for commits.
  - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`
  - Scope is optional but encouraged
  - Use imperative mood, lowercase, no trailing period
- If no repository convention exists, use `type/short-description` for branches
  (e.g., `feat/user-auth`, `fix/null-pointer`).
- **Commit discipline**:
  - One logical change per commit
  - Run `git status` after committing to verify
  - Never force push to `main` or `master`
  - Never commit without being explicitly asked

## Code Style

- Prefer functional style: pure functions, immutability, composition over
  inheritance.
- Strong typing: avoid `any` in TypeScript, use type hints in Python.
- Self-documenting code: comments explain "why", not "what".
- Explicit error handling: no swallowed exceptions, no empty catch blocks.
- Prefer editing existing files over creating new ones. Never create
  documentation files unless explicitly asked.
- Do not reformat code outside the scope of the current task.

## Formatting and Linting

- Always check for and respect existing project formatters and linters
  (prettier, eslint, ruff, gofmt, etc.) before making changes.
- Run the project's configured formatter after editing files when one exists.
- Do not introduce new formatting tools or linting rules without asking.

## Testing

- Add or update tests for new behavior and bug fixes when the project has a
  relevant test pattern.
- Use TDD when practical or explicitly requested.
- Run focused checks after changes; run the broader test suite before committing
  when feasible.
- Report any tests or checks that could not be run.

## Security

- Never commit `.env` files, secrets, API keys, credentials, or tokens.
- Warn when staging files that may contain sensitive data.
- Flag common vulnerabilities: injection, XSS, SSRF, path traversal.
- Prefer environment variables over hardcoded configuration values.
- Treat `~/.config/env.d/**` as a local secret store. Do not read, grep, list, edit, summarize, or print files there unless the user explicitly asks and understands the risk.
- Bifrost-backed OpenCode hosts should each use their own local virtual key and point directly at Bifrost; do not route `smed` through OpenClaw or OpenClaw through `smed`.

## Dependency Management

- Use libraries when they save significant time; prefer stdlib for trivial
  operations.
- Verify a dependency is actively maintained before suggesting it.
- Python: add dependencies via `uv add`.
- JS/TS: add dependencies via `pnpm add`; use `pnpm add -D` for dev-only
  dependencies.

## Workflow

- Always explore existing code before writing new code. Understand the
  patterns and conventions already in use.
- Ask before making large refactors.
- Prefer small, incremental changes over large rewrites.
- When unsure about project conventions, ask rather than guess.

## Platform

- Development targets macOS and Linux.
- Avoid platform-specific assumptions in scripts.
