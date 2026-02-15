# Contributing

Contributions to HaLOS are welcome. Each component repository accepts pull requests independently.

## Getting Started

1. Set up the [development workspace](workspace-setup.md) -- this also sets up the AI-assisted workflow
2. Read the [development workflow](development-workflow.md)
3. Find an issue to work on in the relevant repository

If you're using Claude Code or a similar AI assistant, you can ask it to survey open issues across repositories and suggest what to work on next.

## Reporting Issues

Report bugs and feature requests on the appropriate GitHub repository:

- **General / cross-cutting**: [halos-distro](https://github.com/halos-org/halos-distro/issues)
- **Image builds**: [halos-pi-gen](https://github.com/halos-org/halos-pi-gen/issues)
- **Package manager UI**: [cockpit-apt](https://github.com/halos-org/cockpit-apt/issues)
- **Container app store**: [cockpit-container-apps](https://github.com/halos-org/cockpit-container-apps/issues)
- **Container packaging tools**: [container-packaging-tools](https://github.com/halos-org/container-packaging-tools/issues)
- **Marine apps**: [halos-marine-containers](https://github.com/halos-org/halos-marine-containers/issues)
- **mDNS publisher**: [halos-mdns-publisher](https://github.com/halos-org/halos-mdns-publisher/issues)
- **Dashboard adapter**: [homarr-container-adapter](https://github.com/halos-org/homarr-container-adapter/issues)

When reporting a bug, include:

- HaLOS image variant and version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (from Cockpit Logs or `journalctl`)

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`feat/description`, `fix/description`)
3. Make your changes following the coding standards below
4. Run tests and linting locally
5. Submit a pull request with a clear description

See [Development Workflow](development-workflow.md) for the full process.

## Coding Standards

### General

- Write self-documenting code; comments explain "why", not "what"
- Keep functions small and focused
- No magic numbers -- use named constants
- Validate inputs at system boundaries

### Language-Specific

| Language | Linter | Formatter | Type Checker |
|----------|--------|-----------|-------------|
| Python | ruff | ruff | pyright or ty |
| TypeScript | ESLint | Prettier | tsc (strict mode) |
| Rust | clippy | rustfmt | (built-in) |
| Shell | shellcheck | -- | -- |

### Testing

- All new code should have tests
- Test behavior, not implementation details
- Run tests locally before pushing: `./run test`

### Debian Packaging

- Never edit `debian/changelog` directly -- use `./run bumpversion`
- Include a version bump for package-affecting changes
- Test package installation and removal on a test device

## Communication

- **Discussions**: [GitHub Discussions](https://github.com/halos-org/halos-distro/discussions) for questions, ideas, and general conversation
- **Issues**: For specific bugs and feature requests
- **Pull Requests**: For code contributions
