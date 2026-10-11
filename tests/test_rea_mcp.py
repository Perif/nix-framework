#!/usr/bin/env python3
"""Exercise real stdio MCP packages, without model downloads or an LLM."""

import argparse
import json
import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time


class MCP:
    def __init__(self, executable, directory):
        self.log = tempfile.TemporaryFile()
        self.process = subprocess.Popen(
            [executable, "mcp"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.log,
            cwd=directory,
            env={**os.environ, "HOME": directory},
        )
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer = b""
        self.identifier = 0

    def send(self, message):
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", **message}).encode() + b"\n")
        self.process.stdin.flush()

    def request(self, method, params, timeout=60):
        self.identifier += 1
        self.send({"id": self.identifier, "method": method, "params": params})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                if not line.strip():
                    continue
                message = json.loads(line)
                if message.get("id") == self.identifier:
                    assert "error" not in message, message
                    return message["result"]
            if self.selector.select(max(0, deadline - time.monotonic())):
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise AssertionError("MCP exited before replying")
                self.buffer += chunk
        raise AssertionError(f"MCP timed out: {method}")

    def initialize(self):
        result = self.request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "nix-integration-check", "version": "1.0"},
        })
        assert "tools" in result["capabilities"], result
        self.send({"method": "notifications/initialized"})

    def tool(self, name, arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments}, timeout=300)
        assert not result.get("isError"), result
        return result

    def close(self):
        self.process.stdin.close()
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.selector.close()
        self.process.stdout.close()
        self.log.seek(0)
        logs = self.log.read().decode(errors="replace")
        self.log.close()
        return logs


def diagnose_headless(executable, target, directory):
    """Expose JVM/launcher output when the MCP provider hides a launch cause."""
    project = Path(directory) / "headless-diagnostic"
    project.mkdir()
    command = [executable, str(project), "Fixture", "-import", str(Path(target).resolve()),
               "-readOnly", "-deleteProject"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=120,
                                env={**os.environ, "HOME": directory})
        print(f"Direct Ghidra diagnostic exit: {result.returncode}")
        print("Ghidra stdout:\n" + result.stdout[-32000:])
        print("Ghidra stderr:\n" + result.stderr[-32000:])
    except subprocess.TimeoutExpired as error:
        print("Direct Ghidra diagnostic timed out:", error.stdout, error.stderr)
    except OSError as error:
        print("Direct Ghidra diagnostic could not start:", error)


def check(executable, target, ollaya=False, ghidra_headless=None):
    with tempfile.TemporaryDirectory(prefix="rea-mcp-") as directory:
        client = MCP(executable, directory)
        try:
            client.initialize()
            catalog = client.request("tools/list", {})
            tools = {tool["name"]: tool for tool in catalog["tools"]}
            assert not catalog.get("nextCursor"), "Handle pagination before checking the catalog"
            if ollaya:
                assert {"decide", "list_models", "show_model", "pull_model"} <= tools.keys()
                # Tool calls can start the daemon or download weights. Discovery
                # alone verifies the optional transport without those side effects.
            else:
                assert {"open_binary", "close_binary", "binary_session"} <= tools.keys()
                client.tool("binary_session", {})
                if target:
                    client.tool("open_binary", {"path": str(Path(target).resolve()), "provider_id": "ghidra"})
                    result = client.tool("list_procedures", {})
                    assert "main" in json.dumps(result), result
                    result = client.tool("procedure_pseudo_code", {"procedure": "main"})
                    assert "return" in json.dumps(result), result
                    client.tool("close_binary", {})
            print(f"{'Ollaya' if ollaya else 'REA'} MCP: {len(tools)} tools; checks passed")
        except BaseException:
            print(client.close())
            if target and ghidra_headless:
                diagnose_headless(ghidra_headless, target, directory)
            raise
        else:
            client.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rea", required=True)
    parser.add_argument("--target", help="Small compiled fixture to analyze with Ghidra")
    parser.add_argument("--ghidra-headless", help="Direct launcher for failure-only diagnostics")
    parser.add_argument("--ollaya", help="Also check Ollaya's optional stdio transport")
    args = parser.parse_args()
    check(args.rea, args.target, ghidra_headless=args.ghidra_headless)
    if args.ollaya:
        check(args.ollaya, None, ollaya=True)
