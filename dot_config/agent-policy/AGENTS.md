# Global Agent Instructions

These are personal defaults for all projects. Follow repository-specific instructions and established project conventions when they conflict with these defaults.

## Execution And Communication

- Inspect relevant project files and existing patterns before proposing or making changes.
- Unless the user asks only for advice, a plan, review, or explanation, implement the requested change and carry it through verification when feasible.
- Persist through routine failures and resolve blockers independently when the safe next step is clear.
- Ask focused questions only when ambiguity materially affects behavior, safety, scope, privacy, or an irreversible decision.
- Keep updates brief and limited to meaningful discoveries, decisions, blockers, changes, or verification.
- Keep final responses concise: state the outcome, verification, and anything incomplete. Avoid generic acknowledgements, routine narration, and repetition.
- For reviews, present findings first, ordered by severity, with file and line references where possible.
- Name things in plain words, not internal IDs or shorthand. Add an ID only when it helps the user find the item; documents may use IDs they define.
- Answer first. The first line of a reply states what was found, done or needed; detail follows.
- End a reply that needs something from the user with a single `Your move:` line naming the one action or answer required.
- State deadlines as real days and times ("tomorrow, 2:00 pm"), not as references to a slot or meeting name.

## Tooling Defaults

- Respect declared runtimes, environment managers, package managers, version pins, and lockfiles. Global maintenance is not permission to migrate project versions.
- When a Python project declares no environment or package manager, use `uv`.
- When a JavaScript or TypeScript project declares no package manager, use Node.js with `pnpm`.
- Do not introduce or replace lockfiles unless dependency changes are intended.
- Use the standard Go toolchain.
- Use `docker compose` (v2), not `docker-compose`.
- The interactive shell is `zsh`. Write portable shell scripts in `bash` and prefer POSIX-compatible commands when practical.
- Do not use Bun unless the project explicitly declares it.

## Git

- Without repository conventions, use `type(scope): description` for commits and `type/short-description` for branches. Use lowercase, imperative descriptions without a trailing period.
- Never commit, amend, push, or create a pull request unless explicitly requested.
- Before committing, inspect status, the intended diff, and recent history; stage only intended files and keep one logical change per commit. Check status afterward.
- Never force-push `main` or `master`, skip hooks, or use destructive Git commands unless explicitly approved.
- Preserve unrelated and pre-existing worktree changes.

## Changes And Dependencies

- Prefer the smallest correct change and avoid unrelated reformatting.
- Ask before large refactors or other materially broader changes.
- In software repositories, avoid standalone documentation unless requested or required; follow project documentation workflows.
- Prefer the standard library for trivial work and libraries when they provide meaningful value.
- Before adding a new dependency, verify that it is maintained and compatible with the project.
- Ask before adding a new production dependency unless the user explicitly requested it.

## Formatting And Testing

- Check for and follow existing formatters, linters, type checkers, and test conventions.
- Run focused checks after changes and the broader suite before committing when feasible.
- Add or update tests for changed behavior when the project has a relevant test pattern.
- Verify changed behavior through a representative real workflow when feasible; report verification gaps and required restarts. Ask before interrupting active work.

## Security

- Never commit `.env` files or secrets. Warn before staging potentially sensitive files.
- Prefer environment variables or the project's secret-management mechanism over hardcoded credentials.
- Flag relevant security vulnerabilities. Do not bypass security checks or weaken trust policies without explicit approval.
- Treat `~/.config/env.d/**` as a local secret store. Do not read, list, search, edit, summarize, or print files there unless the user explicitly asks and understands the risk.

## Platform

- Target macOS and Linux unless a project says otherwise; avoid unnecessary platform-specific assumptions.
