# Contributing to Hardened WP

Thank you for your interest in contributing. This project follows the Developmi engineering standard.

## Development setup

```bash
# Clone and install
git clone https://github.com/Developmi/hardened-wp.git
cd hardened-wp
cp .env.example .env
cp Caddyfile.example Caddyfile
# Edit .env with your local values
docker compose up -d
```

## Commit standard

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add FrankenPHP worker mode support
fix: resolve OPcache configuration conflict
docs: update README with Docker instructions
chore: bump WordPress to 6.9.x
```

Types: `feat` · `fix` · `docs` · `chore` · `refactor` · `perf` · `test`

## Branch naming

```
feat/short-description
fix/issue-number-description
docs/update-readme
chore/bump-dependencies
```

## Pull request process

1. Fork the repository and create your branch from `main`.
2. Ensure linting passes: `composer lint`
3. Test your changes with a local Docker build: `docker compose up -d --build`
4. Update documentation if your change affects public behavior (README.md, .env.example).
5. Open a PR with a clear title following the commit standard.
6. A maintainer will review within 5 business days.

## Reporting issues

Use [GitHub Issues](https://github.com/Developmi/hardened-wp/issues). Include:
- Steps to reproduce
- Expected vs. actual behavior
- Environment (OS, Docker version, Docker Compose version)

## Code of conduct

This project adheres to the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
