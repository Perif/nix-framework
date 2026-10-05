# Workstation applications

## Selectable software groups

The current workstation remains the default. Edit `settings.nix` before a
rebuild to remove groups or individual optional applications:

| Setting | What it controls |
| --- | --- |
| `features.devCore` | Common developer commands, Zsh fuzzy finder and directory-jump integrations, Git diff pager, and rootless Podman. |
| `features.languageTools.c` | GCC, Make, CMake, Ninja, and pkg-config. |
| `features.languageTools.python` | Python, uv, BasedPyright, and Ruff. |
| `features.languageTools.go` | Go, gopls, Delve, and golangci-lint. |
| `features.languageTools.rust` | Rust, Cargo, rust-analyzer, rustfmt, and Clippy. |
| `features.languageTools.nodejs` | Node.js. |
| `features.languageTools.nix` | nixd and nixfmt. |
| `features.localAI` | Home Manager local-model CLI/runtime integration and Continue's loopback-only provider config. The system AI services use the same switch. |
| `features.extraBrowsers` | Brave and ungoogled Chromium. Firefox and Tor Browser remain installed. |
| `features.extraEditors` | VSCodium and Sublime Text/Merge. Vim and Neovim remain available. |
| `features.office.libreOffice` | LibreOffice Qt build. |
| `features.office.thunderbird` | Thunderbird. |
| `features.office.kdeConnect` | KDE Connect package. |
| `features.office.syncthing` | Syncthing package. |

All switches default to `true` to preserve the existing installation. Project
versions and project-only tools belong in each repository's Nix `devShell`; see
the language-specific examples in the repository `flake.nix` when available.

KDE Connect and Syncthing are installed as applications only. This configuration
does not enable a Syncthing service or open firewall ports. KDE Connect uses
TCP and UDP ports 1714–1764 when pairing. If pairing is wanted, allow those ports
only on the verified interface for the trusted network. For example, replace
`wlp0s20f3` with the interface shown by `ip -brief link`:

```nix
# Add to the NixOS configuration only when KDE Connect pairing is wanted.
networking.firewall.interfaces."wlp0s20f3" = {
  allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
  allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
};
```

Do not add the range to the global firewall, and remove the interface rule when
you no longer need pairing. This profile masks KDE Connect's login autostart
entry; launch it from the application menu only when you want to use it. Manual
launch may D-Bus-activate its user daemon. This profile does not enable the
NixOS KDE Connect firewall module.

No Syncthing service or login autostart is enabled, and this Nix configuration
supplies no device or folder entries. Start it manually in a terminal with
`syncthing serve --no-browser` only when you are ready to configure it, then open
<http://127.0.0.1:8384>. Syncthing's fresh first run creates an unshared
`Default Folder`; remove it in the GUI before adding any devices if you do not
want it. The GUI defaults to loopback. The sync protocol can still make outbound
connections while Syncthing is running; the system firewall stays closed to
unsolicited inbound traffic. Do not open the sync/discovery ports unless you
deliberately choose a network and sharing arrangement.

## Wine

`features.wine = true` installs stable Wine's modern WoW64 build and Winetricks.
It runs supported 32-bit and 64-bit Windows applications with the existing Intel
graphics stack. Compatibility is application-specific; no Windows applications,
registry tweaks, DXVK overrides or background Wine process are installed.

Give each application its own prefix, for example:

```bash
mkdir -p "$HOME/.local/share/wineprefixes"
WINEPREFIX="$HOME/.local/share/wineprefixes/my-app" winecfg
WINEPREFIX="$HOME/.local/share/wineprefixes/my-app" wine /path/to/installer.exe
```

Keep the same `WINEPREFIX` when launching the installed program or Winetricks.
Use the default 64-bit prefix with this WoW64 build; do not force `WINEARCH=win32`.
Install only the Winetricks components an application needs. Wine prefixes
separate app configuration; they do not sandbox a program from your home files.
Use native Strawberry/qobuz-player for the documented direct DC-Elite path.

## KeePassXC and 1Password migration

`features.keepassxc = true` installs KeePassXC, the Firefox KeePassXC-Browser
extension and native messaging manifests for Firefox, Brave and Chromium.
KeePassXC is a local encrypted database application, not a hosted vault service.

Use **1Password Export (.1pux)** in 1Password 8 and import it with KeePassXC's
database import wizard. CSV omits important fields and is not the recommended
migration route. Repeat for every account you intend to migrate. Save the
result as a new encrypted `.kdbx` database with its own strong master password.

The 1PUX importer is the broadest built-in migration path, but a completely
lossless transfer cannot be promised. Compare vault/item counts and verify
representative logins, notes, cards, custom fields, TOTP codes, documents and
attachments before retiring the old vault. Check any reported import errors.
No real vault has been imported or validated by this repository.

**Passkeys:** 1Password's desktop exports do not contain them. Its mobile apps
support Credential Exchange with compatible destinations, but this is not a
KeePassXC 1PUX import route. Re-enroll passkeys in KeePassXC where supported,
keeping the old sign-in method until the replacement has been tested.

1PUX exports contain plaintext secrets. Export into a private location outside
Git, synchronization and snapshot/backup coverage; `$XDG_RUNTIME_DIR` is suitable
when the export fits available memory. Remove the export after verification.
Keep a separate recoverable backup of the encrypted database and its recovery
material; local filesystem snapshots do not protect against disk loss.

Enable Browser Integration in KeePassXC, then pair Firefox using the extension.
Under Browser Integration / Advanced, turn off **Update native messaging manifest
files at startup**: Home Manager owns those files. Brave/Chromium users can
install the official KeePassXC-Browser extension and pair it the same way.
Application preferences remain writable so pairing and database history work.

References: [1Password export](https://support.1password.com/export/),
[KeePassXC import guide](https://github.com/keepassxreboot/keepassxc/blob/2.7.12/docs/topics/ImportExport.adoc).

## Project environments and rebuilds

Direnv and nix-direnv are enabled in Zsh. In a trusted project with a flake
development shell, add `use flake` to `.envrc`, review it, then run `direnv allow`.
Changes to `.envrc` require approval again. Project tool versions belong in the
project's `devShell`; global tools remain available for ad-hoc use.

NH uses `/etc/nixos` as its default OS flake:

```bash
nh os build
nh os test
nh os switch
```

Build prepares a generation; test activates temporarily; switch activates and
updates the boot default. Use NH's help to select a different flake location.
NH cleanup is disabled: the existing AC-aware Nix GC retains sole ownership.

## mpv

mpv uses `gpu-next` rendering, `hwdec=auto-safe` and PipeWire desktop audio.
Supported codecs can use hardware decoding; unsupported ones fall back to CPU.
Check mpv's statistics/terminal output on representative video. Use
`mpv --hwdec=no /path/to/video` if a driver/codec combination produces artifacts.
The DC-Elite stays reserved for explicit direct-ALSA players.

## Open WebUI

Open WebUI is installed through the NixOS module and starts only on demand.
For a new installation, create the first administrator from a local terminal:

```bash
sudo webui-bootstrap
```

The helper asks for the administrator email, name and password without echoing
the password or storing it in the Nix configuration. It refuses to replace an
existing account. Signup is always disabled. See the [security guide](SECURITY-PRIVACY.md)
for bootstrap failure recovery and the temporary credential file's lifecycle.
After first setup, use:

```bash
webui-on
webui-status
```

Open <http://127.0.0.1:3000>. Starting it also starts the existing Ollama service.
Authentication remains enabled. Nix owns the
managed environment settings, so corresponding Admin UI changes do not persist.

The service binds only to localhost, opens no firewall port, and uses the local
Ollama endpoint. Port 8080 remains available for llama.cpp. Its session key is
generated locally and retained in its private state directory; no password or
session secret is committed. Chats/accounts live under `/var/lib/open-webui`
(backed by systemd's private state directory); include that data in future backups.
Deleting chats or uploads does not remove their older copies in root snapshots;
see [snapshot retention](SECURITY-PRIVACY.md#open-webui-state-and-first-admin-setup).

Automatic model downloads and update checks are disabled, and the OpenAI
provider is disabled. This is a local-chat starting configuration: document
embedding/RAG and speech models are not pre-downloaded. Offline mode is not a
network sandbox. Deliberately configure any additional model-dependent features
before using them. Set per-model context/output limits consistently with
`settings.ai`; a WebUI model override can supersede Ollama's context default.

```bash
webui-off
ollama-off  # when no other local client needs inference
```

Stopping the UI leaves Ollama available to Continue and other clients. Set
`ai.webui.enable = false` to remove the service, preserving its existing data.
See [upstream environment settings](https://docs.openwebui.com/reference/env-configuration/).
