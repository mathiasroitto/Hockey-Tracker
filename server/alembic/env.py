from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from sqlmodel import SQLModel

from alembic import context

# Import the app's models so their tables register on SQLModel.metadata.
from app import storage  # noqa: F401  (registers GameRow/EventRow/ShiftRow)
from app.storage import DEFAULT_DB_URL, make_engine

# Alembic Config object (values from alembic.ini).
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Autogenerate compares this metadata against the live DB.
target_metadata = SQLModel.metadata


def _db_url() -> str:
    """Prefer HOCKEY_DB_URL (via make_engine), fall back to alembic.ini."""
    return config.get_main_option("sqlalchemy.url") or DEFAULT_DB_URL


def run_migrations_offline() -> None:
    context.configure(
        url=_db_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,  # SQLite needs batch mode for ALTER TABLE
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    # make_engine() applies HOCKEY_DB_URL and the SQLite connect args.
    connectable = make_engine(poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=True,  # SQLite needs batch mode for ALTER TABLE
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
