# Development Workflow

This guide covers the workflow for contributing code changes to HaLOS repositories.

## AI-Assisted Workflow

The fastest way to work on HaLOS is with Claude Code from the `halos-distro` workspace. Point it at a GitHub issue and it handles the workflow:

> *"Work on cockpit-apt issue #12. Follow the development workflow."*

Claude creates a feature branch, writes the code and tests, runs CI-matching checks locally via pre-commit hooks, and prepares a PR -- following the conventions documented below. For details on working effectively with AI assistants, see [Life with Claude](https://github.com/halos-org/halos-distro/blob/main/docs/LIFE_WITH_CLAUDE.md).

The rest of this page documents the conventions that Claude (and human developers) follow.

## Branching Strategy

All changes go through feature branches and pull requests. Never push directly to `main`.

```bash
# Create a feature branch from main
git checkout main
git pull origin main
git checkout -b feat/my-feature

# Branch naming convention
# feat/description   - New features
# fix/description    - Bug fixes
# docs/description   - Documentation
# chore/description  - Maintenance tasks
# refactor/description - Code restructuring
```

## Commit Conventions

Use [conventional commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

- **type**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`
- **scope**: Component or module (optional)
- **subject**: Imperative mood, max 50 characters, no period

Examples:

```
feat(search): add case-insensitive matching
fix(install): handle permission errors
docs: update README with container setup
test(backend): add search edge case tests
refactor(ui): extract PackageCard component
```

Keep commits small and atomic -- one logical change per commit. Rebase and clean up history before creating a PR.

## Pull Requests

### Creating a PR

```bash
# Push your branch
git push -u origin feat/my-feature

# Create PR via GitHub CLI
gh pr create --title "feat: add feature X" --body "Description..."
```

PR guidelines:

- **One logical change per PR** -- refactoring and behavior changes belong in separate PRs
- **Descriptive titles** -- they're often used for release notes
- **Explain motivation** in the description (why, not what -- the diff shows what changed)
- **Link issues** with `closes #N` or `fixes #N`

### CI Checks

All PRs run automated checks via GitHub Actions. Checks must pass before merging.

Common checks across repositories:

| Check | Purpose |
|-------|---------|
| Tests | Unit and integration tests |
| Lint | Code style enforcement (ruff, eslint, clippy) |
| Type check | Static type analysis (pyright, tsc) |
| Format | Code formatting verification |
| Version bump | Ensures version is bumped for package-affecting changes |

### Review and Merge

1. Wait for CI checks to pass
2. Address any review feedback
3. Merge using merge commits (not squash) to preserve commit history

## Version Bumps

PRs that change package-affecting files must include a version bump. CI enforces this.

### What Requires a Bump

Changes to source code, packaging files, or configuration that affect the built package.

### What's Exempt

CI automatically excludes these from the version bump requirement:

- Documentation (`*.md`, `docs/`)
- Tests (`tests/`, `*_test.*`)
- CI configuration (`.github/`)
- Development tooling (`docker-compose.dev*`, `tools/`)
- Lock files (`*.lock`)

### How to Bump

Most repositories use `./run bumpversion`:

```bash
# Bump patch version (0.2.0 → 0.2.1)
./run bumpversion patch

# Bump minor version (0.2.0 → 0.3.0)
./run bumpversion minor

# Bump major version (0.2.0 → 1.0.0)
./run bumpversion major
```

!!! warning "Clean Working Directory"
    The working directory must be clean before bumping. Commit all code changes first, then run `bumpversion`. It automatically commits the version change.

Container app repositories (like `halos-marine-containers`) version each app independently in its `metadata.yaml` file.

## Pre-commit Hooks

Repositories use [lefthook](https://github.com/evilmartians/lefthook) for pre-commit hooks. These run the same checks as CI locally before each commit.

```bash
# Install hooks (per repository)
./run hooks-install

# Skip hooks when needed (e.g., WIP commits)
git commit --no-verify -m "WIP: message"
```

## CI/CD Pipeline

### On Push to Main

1. CI builds the Debian package
2. Creates a pre-release tag (`v{version}+{N}_pre`)
3. Publishes `.deb` to `apt.hatlabs.fi` unstable channel
4. Creates a draft GitHub release

### Publishing Stable Releases

1. Test the unstable package on a device
2. Publish the draft release in GitHub UI
3. CI copies the `.deb` to the stable release
4. CI publishes to `apt.hatlabs.fi` stable channel

## Development Environments

### Docker-based (Recommended)

Most repositories provide Docker-based development commands:

```bash
./run docker-build    # Build development container
./run test            # Run tests in Docker
./run lint            # Run linting in Docker
./run shell           # Interactive shell in container
```

This ensures consistent environments across platforms and eliminates "works on my machine" issues.

### Local Development

For faster iteration, some repositories support local development. See each repository's `AGENTS.md` for specific instructions.
