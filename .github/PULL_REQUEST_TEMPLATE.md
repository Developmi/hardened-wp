## Summary

<!-- 1-3 bullets describing what this PR does and why. -->

## Changes

| File | Change |
|------|--------|
| `path/to/file` | What changed and why |

## Test Plan

- [ ] `make lint` - all checks pass (Pint, Composer, shellcheck, actionlint, hadolint)
- [ ] `make audit` - dependency security audit passes (0 CVEs)
- [ ] `docker compose config` - valid compose file
- [ ] `make test` - healthcheck probe returns 200 OK (if runtime behavior changed)
- [ ] Manual validation against running stack (`make dev`, `make backup`)

## Checklist

- [ ] Conventional commit format used in every commit (`feat:`, `fix:`, `docs:`, `chore:`, `ci:`)
- [ ] Branch name follows `type/description` convention
- [ ] No `Co-Authored-By` or AI attribution trailers in commit messages
- [ ] Docs updated if behavior changed (`README.md`, `docs/runbooks/`, `docs/deployment-checklist.md`)
- [ ] `CHANGELOG.md` entry added if this is a user-visible change

## Closes

<!-- Link the issue this PR resolves, if any. e.g. `Closes #12` -->
