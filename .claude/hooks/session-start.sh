#!/bin/bash
# SessionStart hook — provisions the Python server env so tests/linters/uvicorn
# work immediately in Claude Code on the web. See DEVELOPMENT.md.
#
# The Apple apps (ios-app/, watch-app/) build only on macOS with Xcode, so this
# hook intentionally sets up only the server; the cloud container is Linux.
set -euo pipefail

# Only needed in Claude Code on the web (remote). Locally you manage your own env.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

VENV="$CLAUDE_PROJECT_DIR/server/.venv"

# 1) Virtualenv + server package (editable, so code edits are picked up live).
#    Idempotent: reuse a cached venv; pip install is safe to re-run.
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -e "$CLAUDE_PROJECT_DIR/server[dev]"

# 2) Persist environment for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    # Put the venv first on PATH so python/pytest/alembic/uvicorn resolve to it.
    echo "export PATH=\"$VENV/bin:\$PATH\""
    # The server requires this for Sign in with Apple; dev default == iOS bundle id.
    echo "export APPLE_CLIENT_ID=\"com.hockeytracker.ios\""
  } >> "$CLAUDE_ENV_FILE"
fi

# 3) Create/upgrade the local SQLite dev database so the server can run.
(cd "$CLAUDE_PROJECT_DIR/server" && APPLE_CLIENT_ID=com.hockeytracker.ios \
  "$VENV/bin/alembic" upgrade head >/dev/null)

echo "Hockey-Tracker server env ready: .venv + dev deps + migrated SQLite DB."
