# Customize DNS, shells, and editors

Edit declarative source in `/etc/nixos`, then evaluate and test before making a
change the boot default. Nix-managed configuration files are read-only store
links after activation; change their source rather than editing the generated
files under `$HOME/.config`. Application-owned preferences, such as KeePassXC's
browser pairing and database history, remain writable.

### Blocky exceptions and emergency bypass

Blocky is enabled by default with HaGeZi Normal plus full TIF. If a site works
in Firefox but not in ungoogled Chromium or a system application, add a narrow
exception in `/etc/nixos/settings.nix`; the exception takes precedence over
both lists:

```nix
dns.filtering.allowlist = [
  "example.com"
  "*.example.com"
];
```

Apply it as a temporary generation and clear cached negative answers:

```bash
cd /etc/nixos
nix-check
nix-test
sudo systemctl restart blocky.service
resolvectl flush-caches
resolvectl query example.com
```

Use `nix-switch` only after the test succeeds. For diagnosis, set
`dns.filtering.enable = false` and run `nix-test`; this bypasses Blocky but keeps
the unfiltered provider and strict encrypted system DNS. Restore `true` after
identifying the cause. `docs/NETWORKING.md` covers UniFi split DNS and captive
portals.

### Zsh Nix aliases

Start a new shell after rebuilding, then inspect the managed aliases:

```bash
alias | grep '^nix-'
```

The workflow is intentionally explicit:

| Alias | Behavior |
| --- | --- |
| `nix-check` / `ncheck` | Evaluate flake checks without building outputs. |
| `nix-show` | Show flake outputs. |
| `nix-metadata` | Show pinned input revisions. |
| `nix-update` | Update `/etc/nixos/flake.lock`; review the change before activation. |
| `nix-dry` | Build the system closure without activating it. |
| `nix-test` | Activate temporarily; the boot default is unchanged. |
| `nix-boot` | Make the generation the next boot target without changing the running system. |
| `nix-switch` / `rebuild` | Build, activate now, and make the generation the boot default. |
| `nix-generations` | List system generations. |
| `nix-search SEARCH_TERM` | Search the pinned registry package set. |
| `nix-why STORE_PATH` | Explain why a path is in the current system closure. |

Do not alias garbage collection: deletion of generations and store paths should
remain a deliberate, fully typed operation.

### VSCodium and local agents

VSCodium's extension directory is immutable. Add or remove extensions only in
`home/modules/vscodium.nix`; do not use `codium --install-extension`. Continue
is the single agent extension and connects only to the loopback Ollama and
llama.cpp endpoints. The rest of the pinned extension list covers Nix, Python,
Go, Rust, YAML, TOML, EditorConfig, and local debugging.

Repository formatting should be declared in `.editorconfig` rather than by
changing the global profile for one project. For example:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.nix]
indent_style = space
indent_size = 2

[*.py]
indent_style = space
indent_size = 4
```

Generated `.direnv`, `.venv`, `node_modules`, `result`, and `target` trees are
excluded from editor watching/search for responsiveness. Remove an exclusion in
`home/modules/vscodium.nix` only when a project genuinely needs to search that
tree. Local model names and context limits are changed in the same module; see
`docs/LOCAL-AI-DEVELOPMENT.md` for the exact YAML snippet and resource limits.

### Vim and Neovim

`home/modules/vim.nix` shares the same settings and pinned EditorConfig plug-in
between Vim and Neovim. Vim remains `$EDITOR`; Neovim remains available as
`nvim`. Both disable modelines, use separate persistent undo directories under
`~/.local/state/vim/` and `~/.local/state/nvim/`, keep swap/backup data out of
project directories, and provide search, split, completion, and Wayland
clipboard defaults.

Verify the commands and clipboard helper:

```bash
command -v vim
command -v nvim
command -v wl-copy
vim --version | head -n 3
nvim --version | head -n 3
```

Change shared behavior once in the `commonConfig` block. Project indentation
should stay in `.editorconfig`; the four-space global fallback is for files
without project policy.

### Sublime Text packages and language servers

The editor is pinned to stable build 4213 (21 September 2026) in
`home/modules/sublime.nix`, using verified download hashes for x86-64 and ARM64
Linux. This is a targeted package update; `flake.lock` is unchanged. Rebuild
normally, fully quit Sublime, reopen it, and check:

```bash
subl --version
```

Expect build 4213. The managed setting `"disable_plugin_host_3.3": true`
keeps plugins on Python 3.14. Legacy Python 3.3 and bundled OpenSSL 1.1 are
removed, with build-time dependency checks on the surviving binaries. Do not
enable the legacy host to work around an incompatible plugin. Retest Package
Control, EditorConfig and each LSP server below; Nix evaluation is not a GUI
or plugin-runtime test. Release details: [official changelog](https://www.sublimetext.com/download).

On the first launch only, select **Tools > Install Package Control**, then
restart Sublime Text. The Nix-owned Package Control settings install only:

```text
EditorConfig
LSP
Nix
Package Control
```

Package Control usage reporting and prereleases are disabled, its official
channel is the only configured channel, and updates are checked once per day.
The Nix package is syntax-only. BasedPyright, Ruff, gopls, rust-analyzer, and
nixd are not downloaded by Sublime plug-ins: the LSP configuration points to
their pinned Nix store binaries.

On Linux, open **View > Show Console** after restarting and check for plugin
host crashes, missing-library errors, and failed package imports. Verify
EditorConfig changes indentation in a test project and each language server
starts. Plugins selecting the removed Python 3.3 host must be upgraded or
replaced; do not reintroduce OpenSSL 1.1 to make them load. This runtime check
is required even after a successful build. For tighter supply-chain control,
review and pin plugin archives in Nix with an explicit update process; this
build currently retains Package Control's independently updated packages.

Package Control packages are not rolled back with a Nix generation. The small
installation list is not an enforced allowlist: other packages can still be
installed manually, and updates are not individually reviewed by Nix. Daily
updates reduce exposure to stale plug-ins, but this remains
less reproducible than VSCodium's immutable extension set. Review a newly
requested Sublime package before adding it to `installed_packages`; never add a
private repository or alternate package channel merely for convenience.

Open one `.py`, `.go`, `.rs`, and `.nix` file inside a project folder. The LSP
status indicator should show the corresponding server. Use **Tools > LSP >
Troubleshoot Server** if one does not start. Settings and server commands live
in `home/modules/sublime.nix`; the Python 3.3 plug-in host remains removed and
must not be restored to accommodate an obsolete package.

After any customization, evaluate and activate temporarily. Stop if either
command fails:

```bash
cd /etc/nixos && nix-check && nix-test
```

Inspect failed services and verify the behavior you changed:

```bash
systemctl --failed
```

This command lists failures but is not an automatic health gate. Only after
checking the result, networking, a new terminal and the affected applications,
promote the configuration in a separate step:

```bash
nix-switch
```

Use the [upgrade guide](upgrade.md) for the full verification and rollback route.
