# Configure editors

1. Edit the source file listed below in `/etc/nixos`.
2. Follow [apply and verify a change](install/customization.md).
3. Fully quit and reopen the editor, then run its checks below.

## VSCodium and local agents

VSCodium's extension directory is immutable. Add or remove extensions only in
`home/modules/vscodium.nix`; do not use `codium --install-extension`. Continue
is the single agent extension and connects only to the loopback Ollama and
llama.cpp endpoints. The rest of the pinned extension list covers Nix, Python,
Go, Rust, YAML, TOML, EditorConfig, and local debugging.

For project-specific formatting, add or edit `.editorconfig` in that project
rather than changing the global profile. For example:

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
tree. Change Continue providers and model entries in `home/modules/continue-config.nix`.
Set context/output limits with `ai.contextLength` and `ai.maxOutputTokens` in
`settings.nix`; set the REA model with `rea.ollamaModel`. Do not edit the generated
`~/.continue/config.yaml`. Follow [local AI setup](LOCAL-AI-DEVELOPMENT.md).

## Vim and Neovim

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

## Sublime Text packages and language servers

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
