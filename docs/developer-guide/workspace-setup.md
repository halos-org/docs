# Workspace Setup

HaLOS development uses a central workspace repository (`halos-distro`) that brings together all component repositories. This workspace is designed from the ground up for AI-assisted development.

## AI-First Development

The recommended way to develop for HaLOS is with an AI coding assistant like [Claude Code](https://docs.anthropic.com/en/docs/claude-code). The workspace structure, documentation, and `AGENTS.md` files are optimized for this workflow.

**Always work from the `halos-distro` workspace root** -- this gives the assistant full context across all repositories, enabling it to understand cross-cutting concerns, follow established patterns, and produce consistent code.

With this setup, tasks that would otherwise require navigating multiple config formats and conventions become straightforward conversations:

- *"Add a new marine container app for yacht-radar"* -- Claude reads the existing apps, follows the conventions, and produces the full set of files
- *"Fix the search filtering in cockpit-apt"* -- Claude navigates the three-tier architecture, writes the fix, adds tests, and creates a PR
- *"Why is the Grafana OIDC login failing?"* -- Claude checks the SSO config, Docker labels, prestart script, and Authelia client registration

For practical tips on working with AI assistants, see [Life with Claude](https://github.com/hatlabs/halos-distro/blob/main/docs/LIFE_WITH_CLAUDE.md) in the workspace.

## Clone the Workspace

```bash
# Clone the workspace repository
git clone https://github.com/hatlabs/halos-distro.git
cd halos-distro

# Clone all component repositories
./run repos:clone
```

This clones all HaLOS repositories into the workspace directory. Each repository is independent -- there are no git submodules.

## Prerequisites

- **Git** for version control
- **Docker** for containerized builds and tests
- **lefthook** for pre-commit hooks (`brew install lefthook` on macOS)
- **SSH key** registered with GitHub for cloning private repositories

Language-specific tools are needed only for the repositories you work on:

| Repository | Tools |
|-----------|-------|
| Container packaging tools | Python 3.11+, [uv](https://docs.astral.sh/uv/) |
| Cockpit modules | Node.js 18+, npm |
| mDNS publisher, Homarr adapter | Rust (via Docker -- no local install needed) |
| Pi-gen image builder | Docker only |

## Update Repositories

```bash
# Pull latest changes for all repositories
./run repos:pull-all-main

# Check status across all repositories
./run repos:status
```

## Install Pre-commit Hooks

Each repository that supports pre-commit hooks has a `lefthook.yml` configuration:

```bash
# Per-repository setup
cd cockpit-apt
./run hooks-install

cd ../halos-mdns-publisher
./run hooks-install
```

Pre-commit hooks run format and lint checks matching what CI runs, catching issues before they reach the pipeline.

## Repository Overview

```
halos-distro/                       # Workspace root
├── docs/                           # Shared development documentation
│   ├── DEVELOPMENT_WORKFLOW.md
│   ├── IMPLEMENTATION_CHECKLIST.md
│   ├── LIFE_WITH_CLAUDE.md
│   └── ...
├── AGENTS.md                       # Central agent context file
├── run                             # Workspace management script
│
├── halos-pi-gen-wt2/               # Image builder (pi-gen)
├── cockpit-apt/                    # APT package manager UI
├── cockpit-container-apps/         # Container app store UI
├── cockpit-authelia-users/         # Authelia user management
├── container-packaging-tools/      # App → .deb converter
├── halos-core-containers/          # Core apps (Traefik, Authelia, Homarr)
├── halos-marine-containers/        # Marine app definitions + store
├── halos-mdns-publisher/           # mDNS subdomain service (Rust)
├── homarr-container-adapter/       # Dashboard auto-discovery (Rust)
├── halos-homarr-branding/          # Homarr HaLOS theming
├── halos-metapackages/             # halos & halos-marine metapackages
├── halos-cockpit-config/           # Cockpit branding
├── halos-imported-containers/      # Auto-imported community apps
├── shared-workflows/               # Reusable GitHub Actions
└── ...
```

Each repository has its own `AGENTS.md` with detailed development documentation, build commands, and architecture notes.

## Working in a Repository

```bash
# Navigate to a repository
cd cockpit-apt

# Create a feature branch
git checkout -b feat/my-feature

# Build and test (commands vary by repo)
./run test
./run lint

# Commit and push
git add -p
git commit -m "feat(scope): description"
git push -u origin feat/my-feature
```

See [Development Workflow](development-workflow.md) for the full process.
