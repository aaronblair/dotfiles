# Global Agent Instructions

These are personal defaults for all projects. Follow repository-specific instructions and established project conventions when they conflict with these defaults.

## Execution And Communication

- Inspect relevant project files and existing patterns before proposing or making changes.
- Unless the user asks only for advice, a plan, review, or explanation, implement the requested change and carry it through verification when feasible.
- Persist through routine failures and resolve blockers independently when the safe next step is clear.
- Ask a focused question only when ambiguity materially affects behavior, safety, scope, privacy, or an irreversible decision.
- Provide brief progress updates only when they communicate a meaningful discovery, decision, blocker, substantial edit, or verification step.
- Keep final responses concise and state what changed, what was verified, and anything that could not be completed.
- For reviews, present findings first, ordered by severity, with file and line references where possible.
- Avoid generic acknowledgements, unnecessary narration, and repeating information the user already has.

## Tooling Defaults

- Respect the repository's declared runtime, environment manager, package manager, and lockfile.
- When a Python project declares no environment or package manager, use `uv` (`uv run`, `uv venv`, `uv add`, or `uv pip` as appropriate).
- When a JavaScript or TypeScript project declares no package manager, use Node.js with `pnpm`.
- Do not introduce or replace lockfiles unless dependency changes are intended.
- Use the standard Go toolchain: `go run`, `go test`, `go build`, and `go mod tidy`.
- Use `docker compose` (v2), not `docker-compose`.
- The interactive shell is `zsh`. Write portable shell scripts in `bash` and prefer POSIX-compatible commands when practical.
- Do not use Bun unless the project explicitly declares it.

## Git

- Follow documented or clearly established repository conventions.
- If none exist, use `type(scope): description` for commits and `type/short-description` for branches.
- Common commit types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`.
- Use imperative mood, lowercase descriptions, and no trailing period.
- Keep one logical change per commit.
- Never commit, amend, push, or create a pull request unless explicitly requested.
- Before committing, inspect `git status`, the intended diff, and recent history; stage only intended files.
- Run `git status` after committing.
- Never force-push `main` or `master`, skip hooks, or use destructive Git commands unless explicitly approved.
- Preserve unrelated and pre-existing worktree changes.

## Engineering Defaults

- Prefer the smallest correct change and avoid unrelated reformatting.
- Ask before large refactors or other materially broader changes.
- When the project has no contrary convention, prefer composition, immutability, strong typing, and explicit error handling.
- Comments should explain why rather than restate what the code does.
- In software repositories, avoid creating standalone documentation unless requested or required by the task. Follow project-specific documentation workflows where present.

## Dependencies

- Prefer the standard library for trivial work and libraries when they provide meaningful value.
- Before adding a new dependency, verify that it is maintained and compatible with the project.
- Ask before adding a new production dependency unless the user explicitly requested it.
- Use the project's declared package manager for dependency changes.

## Formatting And Testing

- Check for and follow existing formatters, linters, type checkers, and test conventions.
- Run focused checks after changes and the broader suite before committing when feasible.
- Add or update tests for changed behavior when the project has a relevant test pattern.
- Use TDD when practical or explicitly requested, not as a universal requirement.
- Report checks that could not be run.

## Security

- Never commit `.env` files, secrets, API keys, credentials, or tokens.
- Warn before staging files that may contain sensitive data.
- Prefer environment variables or the project's secret-management mechanism over hardcoded credentials.
- Flag common vulnerabilities such as injection, XSS, SSRF, and path traversal when relevant.
- Treat `~/.config/env.d/**` as a local secret store. Do not read, list, search, edit, summarize, or print files there unless the user explicitly asks and understands the risk.

## Platform

- Development targets macOS and Linux unless a project says otherwise.
- Avoid unnecessary platform-specific assumptions.
