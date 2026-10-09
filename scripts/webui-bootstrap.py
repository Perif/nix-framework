#!/usr/bin/env python3
"""Bootstrap the first local Open WebUI administrator without storing secrets in Nix."""

from __future__ import annotations

import argparse
import getpass
import os
import re
import signal
import sqlite3
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

DEFAULT_STATE_DIR = Path("/var/lib/open-webui")
DEFAULT_ENV_FILE = Path("/run/open-webui-bootstrap.env")
DEFAULT_PERMIT_FILE = Path("/run/open-webui-bootstrap.start")
DEFAULT_SERVICE = "open-webui.service"
DEFAULT_ADMIN_NAME = "Admin"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 3000
DEFAULT_TIMEOUT_SECONDS = 120.0
DEFAULT_POLL_SECONDS = 2.0
DEFAULT_PERMIT_MAX_AGE_SECONDS = 300.0

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")


class Stop(RuntimeError):
    pass


class RetryableDatabase(RuntimeError):
    pass


@dataclass(frozen=True)
class BootstrapConfig:
    state_dir: Path = DEFAULT_STATE_DIR
    env_file: Path = DEFAULT_ENV_FILE
    permit_file: Path = DEFAULT_PERMIT_FILE
    service: str = DEFAULT_SERVICE
    host: str = DEFAULT_HOST
    port: int = DEFAULT_PORT
    timeout: float = DEFAULT_TIMEOUT_SECONDS
    poll_interval: float = DEFAULT_POLL_SECONDS
    permit_max_age: float = DEFAULT_PERMIT_MAX_AGE_SECONDS


@dataclass(frozen=True)
class DatabaseState:
    database: Path | None
    has_user_table: bool
    user_count: int
    admin_count: int
    matching_admin: bool

    @property
    def empty(self) -> bool:
        return self.database is None or not self.has_user_table or self.user_count == 0

    @property
    def bootstrapped(self) -> bool:
        return self.admin_count > 0


def open_webui_databases(state_dir: Path) -> list[Path]:
    return [state_dir / "data" / "webui.db", state_dir / "webui.db"]


def existing_databases(state_dir: Path) -> list[Path]:
    return [path for path in open_webui_databases(state_dir) if path.exists()]


def database_state(state_dir: Path, admin_email: str | None = None) -> DatabaseState:
    databases = existing_databases(state_dir)
    if not databases:
        return DatabaseState(None, False, 0, 0, False)
    if len(databases) > 1:
        raise Stop(
            "Open WebUI has more than one possible database path; inspect state before bootstrapping: "
            + ", ".join(str(path) for path in databases)
        )

    database = databases[0]
    try:
        connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True, timeout=1.0)
    except sqlite3.OperationalError as error:
        raise RetryableDatabase(f"Open WebUI database is not ready at {database}: {error}") from error
    except sqlite3.Error as error:
        raise Stop(f"Could not read Open WebUI database at {database}: {error}") from error

    try:
        cursor = connection.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'user'")
        if cursor.fetchone() is None:
            return DatabaseState(database, False, 0, 0, False)
        user_count = int(connection.execute('SELECT COUNT(*) FROM "user"').fetchone()[0])
        admin_count = int(connection.execute('SELECT COUNT(*) FROM "user" WHERE role = ?', ("admin",)).fetchone()[0])
        matching_admin = False
        if admin_email is not None:
            matching_admin = (
                int(
                    connection.execute(
                        'SELECT COUNT(*) FROM "user" WHERE lower(email) = lower(?) AND role = ?',
                        (admin_email, "admin"),
                    ).fetchone()[0]
                )
                > 0
            )
        return DatabaseState(database, True, user_count, admin_count, matching_admin)
    except sqlite3.OperationalError as error:
        raise RetryableDatabase(f"Open WebUI database schema is not ready at {database}: {error}") from error
    except sqlite3.Error as error:
        raise Stop(f"Could not inspect Open WebUI users in {database}: {error}") from error
    finally:
        connection.close()


def validate_plain_value(label: str, value: str, *, allow_empty: bool = False) -> str:
    if not allow_empty and not value:
        raise Stop(f"{label} must not be empty")
    if CONTROL_RE.search(value):
        raise Stop(f"{label} must not contain control characters")
    return value


def validate_email(email: str) -> str:
    email = validate_plain_value("Admin email", email.strip())
    if not EMAIL_RE.match(email):
        raise Stop("Admin email must look like a single email address")
    return email.lower()


def validate_password(password: str) -> str:
    password = validate_plain_value("Admin password", password)
    if len(password) < 12:
        raise Stop("Admin password must be at least 12 characters")
    return password


def systemd_env_quote(value: str) -> str:
    validate_plain_value("Environment value", value, allow_empty=True)
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render_environment(email: str, password: str, name: str) -> str:
    values = {
        "WEBUI_ADMIN_EMAIL": validate_email(email),
        "WEBUI_ADMIN_PASSWORD": validate_password(password),
        "WEBUI_ADMIN_NAME": validate_plain_value("Admin display name", name),
        "WEBUI_AUTH": "True",
        "ENABLE_SIGNUP": "False",
    }
    return "".join(f"{key}={systemd_env_quote(value)}\n" for key, value in values.items())


def assert_bootstrap_allowed(state_dir: Path, admin_email: str | None = None) -> DatabaseState:
    state = database_state(state_dir, admin_email)
    if state.empty:
        return state
    if state.matching_admin:
        raise Stop("Open WebUI already has this admin account; refusing to run bootstrap again")
    if state.bootstrapped:
        raise Stop("Open WebUI already has an admin account; refusing to overwrite existing state")
    raise Stop("Open WebUI already has user rows but no admin; inspect the database before bootstrapping")


FileIdentity = tuple[int, int]


def remove_owned_file(path: Path, identity: FileIdentity | None) -> None:
    if identity is None:
        return
    try:
        current = path.lstat()
    except FileNotFoundError:
        return
    if (current.st_dev, current.st_ino) == identity:
        path.unlink()


def write_new_file(
    path: Path, content: str, mode: int, label: str,
    owned: dict[Path, FileIdentity] | None = None,
) -> FileIdentity:
    if path.exists() or path.is_symlink():
        raise Stop(f"Refusing to overwrite existing {label}: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    except FileExistsError as error:
        raise Stop(f"Refusing to overwrite existing {label}: {path}") from error
    created = os.fstat(fd)
    identity = (created.st_dev, created.st_ino)
    if owned is not None:
        owned[path] = identity
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            fd = -1
            handle.write(content)
            os.fchmod(handle.fileno(), mode)
            handle.flush()
            os.fsync(handle.fileno())
    except BaseException:
        if fd >= 0:
            os.close(fd)
        try:
            remove_owned_file(path, identity)
        finally:
            if owned is not None:
                owned.pop(path, None)
        raise
    return identity


def write_private_env_file(
    path: Path, content: str, owned: dict[Path, FileIdentity] | None = None,
) -> FileIdentity:
    return write_new_file(path, content, stat.S_IRUSR | stat.S_IWUSR,
                          "bootstrap environment file", owned)


def write_permit_file(path: Path, owned: dict[Path, FileIdentity] | None = None) -> FileIdentity:
    return write_new_file(path, "open-webui bootstrap start permitted\n",
                          stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH,
                          "bootstrap start permit", owned)


def permit_is_fresh(path: Path, max_age: float) -> bool:
    try:
        stat_result = path.stat()
    except FileNotFoundError:
        return False
    return time.time() - stat_result.st_mtime <= max_age


def systemctl(action: str, service: str) -> None:
    subprocess.run(["systemctl", action, service], check=True)


def start_service(service: str) -> None:
    systemctl("start", service)


def stop_service(service: str) -> None:
    systemctl("stop", service)


def restart_service(service: str) -> None:
    systemctl("restart", service)


def check_http_ready(host: str, port: int) -> bool:
    request = urllib.request.Request(f"http://{host}:{port}/", method="GET")
    # The service is loopback-only; never route the probe through a proxy
    # inherited from the invoking shell's environment.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=2.0) as response:
            return response.status < 500
    except urllib.error.HTTPError as error:
        return error.code < 500
    except OSError:
        return False


def wait_for_bootstrap(config: BootstrapConfig, admin_email: str, *, require_http: bool) -> DatabaseState:
    deadline = time.monotonic() + config.timeout
    last_state = DatabaseState(None, False, 0, 0, False)
    last_retryable = ""
    while time.monotonic() <= deadline:
        try:
            last_state = database_state(config.state_dir, admin_email)
            last_retryable = ""
        except RetryableDatabase as error:
            last_retryable = str(error)
            time.sleep(config.poll_interval)
            continue
        if last_state.matching_admin and (not require_http or check_http_ready(config.host, config.port)):
            return last_state
        time.sleep(config.poll_interval)
    database = str(last_state.database) if last_state.database else "no database"
    suffix = f"; last transient database state: {last_retryable}" if last_retryable else ""
    raise Stop(
        "Timed out waiting for Open WebUI to create the bootstrap admin "
        f"({database}, users={last_state.user_count}, admins={last_state.admin_count}{suffix})"
    )


def check_service_may_start(config: BootstrapConfig) -> int:
    state = database_state(config.state_dir)
    if state.user_count > 0:
        return 0
    if permit_is_fresh(config.permit_file, config.permit_max_age):
        return 0
    print(
        "Open WebUI has no local users yet. Run "
        "`sudo webui-bootstrap` once to create the first admin account without enabling signup.",
        file=sys.stderr,
    )
    return 1


def prompt_credentials(default_name: str) -> tuple[str, str, str]:
    email = validate_email(input("Admin email: "))
    name_input = input(f"Admin display name [{default_name}]: ").strip()
    name = validate_plain_value("Admin display name", name_input or default_name)
    password = validate_password(getpass.getpass("Admin password: "))
    confirmation = getpass.getpass("Confirm admin password: ")
    if password != confirmation:
        raise Stop("Passwords did not match")
    return email, password, name


def bootstrap(config: BootstrapConfig, email: str, password: str, name: str) -> None:
    email = validate_email(email)
    assert_bootstrap_allowed(config.state_dir, email)
    content = render_environment(email, password, name)
    owned: dict[Path, FileIdentity] = {}
    service_attempted = False
    previous_sigterm = signal.getsignal(signal.SIGTERM)

    def handle_sigterm(signum: int, frame: object) -> None:
        raise Stop("Interrupted by SIGTERM; bootstrap files were cleaned up")

    signal.signal(signal.SIGTERM, handle_sigterm)
    try:
        write_private_env_file(config.env_file, content, owned)
        write_permit_file(config.permit_file, owned)
        service_attempted = True
        start_service(config.service)
        wait_for_bootstrap(config, email, require_http=True)
        remove_owned_file(config.env_file, owned.get(config.env_file))
        owned.pop(config.env_file, None)
        restart_service(config.service)
        wait_for_bootstrap(config, email, require_http=True)
    except BaseException:
        if service_attempted:
            try:
                stop_service(config.service)
            finally:
                raise
        raise
    finally:
        try:
            try:
                remove_owned_file(config.env_file, owned.get(config.env_file))
            finally:
                remove_owned_file(config.permit_file, owned.get(config.permit_file))
        finally:
            signal.signal(signal.SIGTERM, previous_sigterm)


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create the first Open WebUI admin through a root-only one-shot environment file."
    )
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE_DIR)
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE)
    parser.add_argument("--permit-file", type=Path, default=DEFAULT_PERMIT_FILE)
    parser.add_argument("--service", default=DEFAULT_SERVICE)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--poll-interval", type=float, default=DEFAULT_POLL_SECONDS)
    parser.add_argument("--permit-max-age", type=float, default=DEFAULT_PERMIT_MAX_AGE_SECONDS)
    parser.add_argument("--admin-name", default=DEFAULT_ADMIN_NAME)
    parser.add_argument(
        "--check-start",
        action="store_true",
        help="systemd ExecCondition mode: allow service start only after bootstrap permit or local users exist",
    )
    return parser.parse_args(list(argv))


def config_from_args(args: argparse.Namespace) -> BootstrapConfig:
    return BootstrapConfig(
        state_dir=args.state_dir,
        env_file=args.env_file,
        permit_file=args.permit_file,
        service=args.service,
        host=args.host,
        port=args.port,
        timeout=args.timeout,
        poll_interval=args.poll_interval,
        permit_max_age=args.permit_max_age,
    )


def run(argv: Iterable[str]) -> int:
    args = parse_args(argv)
    config = config_from_args(args)
    if args.check_start:
        return check_service_may_start(config)

    if os.geteuid() != 0:
        raise Stop("Run as root so the bootstrap environment file is readable only by systemd")
    if not sys.stdin.isatty():
        raise Stop("Run from an interactive terminal so the password prompt is not echoed")

    email, password, name = prompt_credentials(args.admin_name)
    bootstrap(config, email, password, name)
    print("Open WebUI created the first admin account and was restarted without bootstrap credentials.")
    print("The bootstrap files were removed; keep the admin password in your password manager.")
    return 0


def main() -> None:
    try:
        raise SystemExit(run(sys.argv[1:]))
    except Stop as error:
        print(f"webui-bootstrap: {error}", file=sys.stderr)
        raise SystemExit(1)
    except RetryableDatabase as error:
        print(f"webui-bootstrap: {error}; retry once the Open WebUI database is idle", file=sys.stderr)
        raise SystemExit(1)
    except subprocess.CalledProcessError as error:
        print(f"webui-bootstrap: systemctl failed with exit code {error.returncode}", file=sys.stderr)
        raise SystemExit(error.returncode)


if __name__ == "__main__":
    main()
