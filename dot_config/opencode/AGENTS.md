# Global Agent Instructions

## Tooling Defaults

### Python
- Always use `uv` for environment and package management.
- Use `uv run` to execute scripts, `uv venv` to create virtual environments,
  `uv add` to add dependencies (pyproject.toml), `uv pip` when pip semantics
  are needed.
- Never use bare `pip`, `pip3`, `virtualenv`, `conda`, or `poetry`.

### JavaScript / TypeScript
- Prefer `bun` over `npm` for all operations.
- Use `bun run`, `bun install`, `bun add`, `bunx`, `bun test`.
- Fall back to `npm`/`npx` only when bun is incompatible (e.g., native
  Node.js-only modules or platform constraints).

### Go
- Use the standard Go toolchain: `go run`, `go test`, `go build`,
  `go mod tidy`.

### Shell
- Interactive shell is `zsh`. Write shell scripts in `bash` for portability.
- Use POSIX-compatible commands where possible.

### Docker
- Use `docker compose` (v2), not `docker-compose`.

## Git Conventions

- **Commit format**: `type(scope): description`
  - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`
  - Scope is optional but encouraged
  - Use imperative mood, lowercase, no trailing period
- **Branch naming**: `type/short-description` (e.g., `feat/user-auth`,
  `fix/null-pointer`)
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

- Follow TDD: write tests first when implementing new features.
- Run existing tests before committing to catch regressions.
- Suggest test coverage for new code paths.

## Security

- Never commit `.env` files, secrets, API keys, credentials, or tokens.
- Warn when staging files that may contain sensitive data.
- Flag common vulnerabilities: injection, XSS, SSRF, path traversal.
- Prefer environment variables over hardcoded configuration values.

## Dependency Management

- Use libraries when they save significant time; prefer stdlib for trivial
  operations.
- Verify a dependency is actively maintained before suggesting it.
- Python: add dependencies via `uv add`.
- JS/TS: add dependencies via `bun add`.

## Workflow

- Always explore existing code before writing new code. Understand the
  patterns and conventions already in use.
- Ask before making large refactors.
- Prefer small, incremental changes over large rewrites.
- When unsure about project conventions, ask rather than guess.

## Platform

- Development targets macOS and Linux.
- Avoid platform-specific assumptions in scripts.
