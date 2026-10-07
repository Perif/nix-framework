"""Safe unit checks for the Open WebUI first-admin bootstrap helper."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import importlib.util
import io
import os
import threading
import signal
import sqlite3
import stat
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

TEST_EMAIL = "owner@example.invalid"
TEST_PASSWORD = "synthetic test passphrase"


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("webui_bootstrap", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def make_config(module, root: Path, *, timeout: float = 0.05):
    return module.BootstrapConfig(
        state_dir=root / "state",
        env_file=root / "bootstrap.env",
        permit_file=root / "bootstrap.start",
        service="open-webui.service",
        timeout=timeout,
        poll_interval=0.01,
    )


def make_user_database(path: Path, rows: list[tuple[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path)
    try:
        connection.execute('CREATE TABLE "user" (email TEXT, role TEXT)')
        connection.executemany('INSERT INTO "user" (email, role) VALUES (?, ?)', rows)
        connection.commit()
    finally:
        connection.close()


class WebuiBootstrapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module(Path(ARGUMENTS.script))

    def test_environment_file_is_quoted_and_signup_disabled(self) -> None:
        rendered = self.module.render_environment(
            "Owner@Example.Invalid",
            'synthetic passphrase with "quotes" and \\slashes',
            "Owner Admin",
        )
        self.assertIn('WEBUI_ADMIN_EMAIL="owner@example.invalid"', rendered)
        self.assertIn('WEBUI_ADMIN_NAME="Owner Admin"', rendered)
        self.assertIn('ENABLE_SIGNUP="False"', rendered)
        self.assertIn('WEBUI_AUTH="True"', rendered)
        self.assertNotIn("\nWEBUI_ADMIN_PASSWORD=synthetic passphrase", rendered)

    def test_rejects_newline_in_secret_values(self) -> None:
        with self.assertRaisesRegex(self.module.Stop, "control characters"):
            self.module.render_environment(TEST_EMAIL, "synthetic pass\nINJECT=1", "Admin")

    def test_rejects_short_password(self) -> None:
        with self.assertRaisesRegex(self.module.Stop, "at least 12"):
            self.module.render_environment(TEST_EMAIL, "short", "Admin")

    def test_private_env_and_permit_files_modes_and_no_overwrite(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            env_file = root / "bootstrap.env"
            permit_file = root / "bootstrap.start"
            self.module.write_private_env_file(env_file, 'A="B"\n')
            self.module.write_permit_file(permit_file)
            self.assertEqual(stat.S_IMODE(env_file.stat().st_mode), stat.S_IRUSR | stat.S_IWUSR)
            self.assertEqual(
                stat.S_IMODE(permit_file.stat().st_mode),
                stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH,
            )
            with self.assertRaisesRegex(self.module.Stop, "Refusing to overwrite"):
                self.module.write_private_env_file(env_file, 'A="C"\n')
            with self.assertRaisesRegex(self.module.Stop, "Refusing to overwrite"):
                self.module.write_permit_file(permit_file)

    def test_failed_early_writes_remove_owned_files_and_restore_handler(self) -> None:
        for failed_write in ("environment", "permit"):
            with self.subTest(failed_write=failed_write), tempfile.TemporaryDirectory() as temporary:
                config = make_config(self.module, Path(temporary))
                previous_sigterm = signal.getsignal(signal.SIGTERM)
                real_fsync = os.fsync
                calls = 0

                def fail_selected_write(fd: int) -> None:
                    nonlocal calls
                    calls += 1
                    if (failed_write == "environment" and calls == 1) or (
                        failed_write == "permit" and calls == 2
                    ):
                        raise OSError("synthetic write failure")
                    real_fsync(fd)

                with patch.object(self.module.os, "fsync", fail_selected_write), \
                    patch.object(self.module, "stop_service") as stop, \
                    patch.object(self.module, "start_service") as start:
                    with self.assertRaisesRegex(OSError, "synthetic write failure"):
                        self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
                self.assertFalse(config.env_file.exists())
                self.assertFalse(config.permit_file.exists())
                self.assertEqual(signal.getsignal(signal.SIGTERM), previous_sigterm)
                start.assert_not_called()
                stop.assert_not_called()

    def test_sigterm_during_secret_write_removes_partial_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = make_config(self.module, Path(temporary))
            previous_sigterm = signal.getsignal(signal.SIGTERM)
            with patch.object(self.module.os, "fsync", side_effect=lambda _: os.kill(os.getpid(), signal.SIGTERM)), \
                patch.object(self.module, "stop_service") as stop:
                with self.assertRaisesRegex(self.module.Stop, "Interrupted by SIGTERM"):
                    self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
            self.assertFalse(config.env_file.exists())
            self.assertFalse(config.permit_file.exists())
            self.assertEqual(signal.getsignal(signal.SIGTERM), previous_sigterm)
            stop.assert_not_called()

    def test_cleanup_keeps_concurrent_replacement_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root)
            previous_sigterm = signal.getsignal(signal.SIGTERM)

            def replace_env_then_fail(service: str) -> None:
                config.env_file.rename(root / "original.env")
                self.module.write_private_env_file(config.env_file, 'CONCURRENT="1"\n')
                raise self.module.Stop("synthetic startup failure")

            with patch.object(self.module, "start_service", replace_env_then_fail), \
                patch.object(self.module, "stop_service") as stop:
                with self.assertRaisesRegex(self.module.Stop, "synthetic startup failure"):
                    self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
            self.assertEqual(config.env_file.read_text(), 'CONCURRENT="1"\n')
            self.assertFalse(config.permit_file.exists())
            self.assertEqual(signal.getsignal(signal.SIGTERM), previous_sigterm)
            stop.assert_called_once_with(config.service)

    def test_allows_retry_when_database_is_empty(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            make_user_database(root / "state" / "data" / "webui.db", [])
            state = self.module.assert_bootstrap_allowed(root / "state", TEST_EMAIL)
            self.assertTrue(state.empty)

    def test_refuses_repeated_or_ambiguous_bootstrap(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "state" / "data" / "webui.db"
            make_user_database(database, [(TEST_EMAIL, "admin")])
            with self.assertRaisesRegex(self.module.Stop, "already has this admin"):
                self.module.assert_bootstrap_allowed(root / "state", TEST_EMAIL)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "state" / "data" / "webui.db"
            make_user_database(database, [("user@example.invalid", "user")])
            with self.assertRaisesRegex(self.module.Stop, "user rows but no admin"):
                self.module.assert_bootstrap_allowed(root / "state", TEST_EMAIL)

    def test_start_condition_requires_users_or_fresh_permit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root)
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(self.module.check_service_may_start(config), 1)
            self.module.write_permit_file(config.permit_file)
            self.assertEqual(self.module.check_service_may_start(config), 0)
            old_time = time.time() - config.permit_max_age - 1
            os.utime(config.permit_file, (old_time, old_time))
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(self.module.check_service_may_start(config), 1)
            config.permit_file.unlink()
            make_user_database(config.state_dir / "data" / "webui.db", [(TEST_EMAIL, "admin")])
            self.assertEqual(self.module.check_service_may_start(config), 0)

    def test_main_reports_transient_database_error_without_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root)
            argv = ["webui-bootstrap", "--check-start", "--state-dir", str(config.state_dir),
                    "--permit-file", str(config.permit_file)]
            stderr = io.StringIO()
            with patch.object(self.module, "database_state",
                              side_effect=self.module.RetryableDatabase("database is locked")), \
                 patch.object(sys, "argv", argv), contextlib.redirect_stderr(stderr):
                try:
                    self.module.main()
                except SystemExit as exit_info:
                    code = exit_info.code
                except self.module.RetryableDatabase:
                    self.fail("RetryableDatabase escaped main() as an uncaught exception")
                else:
                    self.fail("main() returned instead of exiting")
            self.assertEqual(code, 1)
            self.assertIn("webui-bootstrap: ", stderr.getvalue())
            self.assertIn("database is locked", stderr.getvalue())
            self.assertNotIn("Traceback", stderr.getvalue())

    def test_readiness_probe_ignores_proxy_environment(self) -> None:
        class Ready(http.server.BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                self.send_response(200)
                self.end_headers()

            def log_message(self, *args: object) -> None:
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Ready)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            # A proxy that refuses connections; a probe routed through it fails.
            with patch.dict(os.environ, {"http_proxy": "http://127.0.0.1:9", "HTTP_PROXY": "http://127.0.0.1:9",
                                         "no_proxy": "example.invalid", "NO_PROXY": "example.invalid"}):
                self.assertTrue(self.module.check_http_ready("127.0.0.1", server.server_address[1]))
        finally:
            server.shutdown()
            server.server_close()

    def test_timeout_stops_service_and_removes_runtime_files_for_empty_db_retry(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root)
            calls: list[str] = []

            def start_with_empty_database(service: str) -> None:
                calls.append(f"start:{service}")
                make_user_database(config.state_dir / "data" / "webui.db", [])

            with patch.object(self.module, "start_service", start_with_empty_database), \
                patch.object(self.module, "stop_service", lambda service: calls.append(f"stop:{service}")), \
                patch.object(self.module, "restart_service", lambda service: calls.append(f"restart:{service}")), \
                patch.object(self.module, "check_http_ready", lambda host, port: False):
                with self.assertRaisesRegex(self.module.Stop, "Timed out"):
                    self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
            self.assertEqual(calls, ["start:open-webui.service", "stop:open-webui.service"])
            self.assertFalse(config.env_file.exists())
            self.assertFalse(config.permit_file.exists())
            state = self.module.assert_bootstrap_allowed(config.state_dir, TEST_EMAIL)
            self.assertTrue(state.empty)

    def test_success_waits_for_admin_then_restarts_without_bootstrap_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root, timeout=1.0)
            calls: list[str] = []

            def start(service: str) -> None:
                calls.append(f"start:{service}")
                make_user_database(config.state_dir / "data" / "webui.db", [(TEST_EMAIL, "admin")])

            with patch.object(self.module, "start_service", start), \
                patch.object(self.module, "stop_service", lambda service: calls.append(f"stop:{service}")), \
                patch.object(self.module, "restart_service", lambda service: calls.append(f"restart:{service}")), \
                patch.object(self.module, "check_http_ready", lambda host, port: True):
                self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
            self.assertEqual(calls, ["start:open-webui.service", "restart:open-webui.service"])
            self.assertFalse(config.env_file.exists())
            self.assertFalse(config.permit_file.exists())

    def test_wait_retries_transient_sqlite_startup_errors(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root, timeout=1.0)
            attempts = {"count": 0}

            def flaky_database_state(state_dir: Path, admin_email: str | None = None):
                attempts["count"] += 1
                if attempts["count"] == 1:
                    raise self.module.RetryableDatabase("database is locked")
                return self.module.DatabaseState(
                    database=state_dir / "data" / "webui.db",
                    has_user_table=True,
                    user_count=1,
                    admin_count=1,
                    matching_admin=True,
                )

            with patch.object(self.module, "database_state", flaky_database_state), \
                patch.object(self.module, "check_http_ready", lambda host, port: True):
                state = self.module.wait_for_bootstrap(config, TEST_EMAIL, require_http=True)
            self.assertTrue(state.matching_admin)
            self.assertEqual(attempts["count"], 2)

    def test_sigterm_cleanup_removes_runtime_files_and_stops_service(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = make_config(self.module, root, timeout=1.0)
            calls: list[str] = []
            original_sigterm = signal.getsignal(signal.SIGTERM)

            def start_then_sigterm(service: str) -> None:
                calls.append(f"start:{service}")
                os.kill(os.getpid(), signal.SIGTERM)

            with patch.object(self.module, "start_service", start_then_sigterm), \
                patch.object(self.module, "stop_service", lambda service: calls.append(f"stop:{service}")), \
                patch.object(self.module, "restart_service", lambda service: calls.append(f"restart:{service}")), \
                patch.object(self.module, "check_http_ready", lambda host, port: False):
                with self.assertRaisesRegex(self.module.Stop, "Interrupted by SIGTERM"):
                    self.module.bootstrap(config, TEST_EMAIL, TEST_PASSWORD, "Admin")
            self.assertEqual(calls, ["start:open-webui.service", "stop:open-webui.service"])
            self.assertFalse(config.env_file.exists())
            self.assertFalse(config.permit_file.exists())
            self.assertEqual(signal.getsignal(signal.SIGTERM), original_sigterm)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--script", "--helper", dest="script", required=True)
    ARGUMENTS, remaining = parser.parse_known_args()
    unittest.main(argv=[__file__, *remaining])
