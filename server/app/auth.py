"""Sign in with Apple authentication.

Clients (Watch/iOS) perform Sign in with Apple and send the resulting identity
token as `Authorization: Bearer <token>`. We verify that JWT against Apple's
public keys and map its stable `sub` claim to a user account.

Config (environment variables):
  APPLE_CLIENT_ID   the token audience — your app's bundle id / Services id.
                    REQUIRED in production; verification fails without it.
  APPLE_ISSUER      defaults to https://appleid.apple.com
  APPLE_JWKS_URL    defaults to https://appleid.apple.com/auth/keys

Testing note: routes depend on `get_current_user`, which tests override via
`app.dependency_overrides` — so the network-backed verification here is not
exercised in unit tests. The verification path is only hit for real tokens.
"""

import os

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from .models import User
from .storage import GameStore, make_engine

APPLE_ISSUER = os.environ.get("APPLE_ISSUER", "https://appleid.apple.com")
APPLE_JWKS_URL = os.environ.get("APPLE_JWKS_URL", "https://appleid.apple.com/auth/keys")
APPLE_CLIENT_ID = os.environ.get("APPLE_CLIENT_ID")

# Constructing the client does not hit the network; keys are fetched and cached
# lazily on first verification.
_jwk_client = PyJWKClient(APPLE_JWKS_URL)

_bearer = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Missing, invalid, or expired authentication token",
    headers={"WWW-Authenticate": "Bearer"},
)


def verify_apple_identity_token(token: str) -> str:
    """Verify an Apple identity token and return its `sub` (stable user id)."""
    if not APPLE_CLIENT_ID:
        # Misconfiguration, not a client error — don't mask it as a 401.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="APPLE_CLIENT_ID is not configured",
        )
    try:
        signing_key = _jwk_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=APPLE_CLIENT_ID,
            issuer=APPLE_ISSUER,
        )
    except jwt.PyJWTError:
        raise _UNAUTHORIZED
    sub = claims.get("sub")
    if not sub:
        raise _UNAUTHORIZED
    return sub


# Store used by the default auth dependency. Kept module-level so it shares the
# app's database; tests override get_current_user entirely and never touch this.
_store = GameStore(make_engine())


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> User:
    """FastAPI dependency: resolve the caller to a User, or raise 401."""
    if credentials is None or not credentials.credentials:
        raise _UNAUTHORIZED
    apple_sub = verify_apple_identity_token(credentials.credentials)
    return _store.get_or_create_user(apple_sub)
