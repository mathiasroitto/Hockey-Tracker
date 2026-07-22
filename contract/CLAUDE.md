# contract/ — the source of truth

`openapi.yaml` defines every data shape and endpoint in the system. The Watch
app, iOS app, and server all implement against it.

## Rules

- **Only `contract-agent` edits this directory.** Other agents request changes.
- Every change bumps `info.version` (semver) and gets an entry in `CHANGELOG.md`.
- Prefer **additive, backward-compatible** changes. A breaking change (removing
  or retyping a field, changing an endpoint's meaning) bumps the **major**
  version and must be justified in the changelog.
- Before adding/altering a field, confirm all three sides can honor it:
  - **Watch** can *capture* it (does the sensor / UI produce this?).
  - **Server** can *store & compute* it.
  - **iOS** can *display* it meaningfully.

## Downstream implementations to keep in sync

When a schema changes, these must be updated to match (by their owning agents):

- `server/app/models.py` — Pydantic models mirroring the schemas.
- `watch-app/` and `ios-app/` — Swift `Codable` structs (hand-written or
  generated) mirroring the schemas.

## Validating the spec

```bash
python -c "import yaml; yaml.safe_load(open('contract/openapi.yaml'))"  # parses
```
For richer linting, `openapi-spec-validator contract/openapi.yaml`.
