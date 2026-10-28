# Workstation applications

Guide 12 · [All guides](README.md).

1. Choose the feature below and edit only its existing field in `/etc/nixos/settings.nix`.
2. Follow [apply a change](install/06-customization.md).
3. Complete the app-specific first-use steps below and verify it opens.

## Selectable software groups

The current workstation remains the default. Edit `settings.nix` before a
rebuild to remove groups or individual optional applications:

| Setting | What it controls |
| --- | --- |
| `features.wine` | Wine WoW64 and Winetricks. |
| `features.keepassxc` | KeePassXC and managed Firefox native integration. |
| `features.devCore` | Common developer commands, ncdu, Zsh fuzzy finder and directory-jump integrations, Git diff pager, and rootless Podman. |
| `features.languageTools.c` | GCC, GDB, Make, CMake, Ninja, and pkg-config. |
| `features.languageTools.llvm` | LLVM, Clang, clangd/Clang tools, LLD and LLDB. |
| `features.languageTools.python` | Python, uv, BasedPyright, and Ruff. |
| `features.languageTools.go` | Go, gopls, Delve, and golangci-lint. |
| `features.languageTools.rust` | Rust, Cargo, rust-analyzer, rustfmt, and Clippy. |
| `features.languageTools.guile` | Guile 3 Scheme interpreter, REPL, and `guild` compiler. |
| `features.languageTools.nodejs` | Node.js. |
| `features.languageTools.nix` | nixd and nixfmt. |
| `features.localAI` | Home Manager local-model CLI/runtime integration and Continue's loopback-only provider config. The system AI services use the same switch. |
| `features.rea` | REA CLI/MCP with Ghidra and Java; Continue uses Ollama, with optional Ollaya decision tools. See [REA](19-rea.md). |
| `features.extraBrowsers` | Brave and ungoogled Chromium. Firefox and Tor Browser remain installed. |
| `features.extraEditors` | VSCodium and Sublime Text/Merge. Vim and Neovim remain available. |
| `features.gaming.beyondAllReason` | Beyond All Reason native Linux launcher. |
| `features.gaming.gamescope` | Gamescope nested compositor for manually launched games. |
| `features.office.libreOffice` | LibreOffice Qt build. |
| `features.office.thunderbird` | Thunderbird. |
| `features.office.kdeConnect` | KDE Connect package. |
| `features.office.syncthing` | Syncthing package. |
| `features.utilities.filezilla` | FileZilla SFTP/FTP client. |
| `features.utilities.filelight` | Filelight graphical disk-usage viewer. |
| `features.utilities.bruno` | Bruno API client with local request collections. |
| `features.utilities.rclone` | rclone cloud and object-storage transfers. |
| `features.utilities.aria2` | aria2 command-line downloader (`aria2c`). |
| `features.utilities.pdfarranger` | PDF Arranger page merging, splitting and reordering. |
| `features.utilities.qpwgraph` | PipeWire connection graph and patchbay. |
| `features.utilities.dbeaver` | DBeaver Community database client. |
| `features.utilities.audacity` | Audacity audio recording and editing. |
| `features.utilities.naps2` | NAPS2 plus local SANE scanner drivers and user access. |

All switches default to `true` to preserve the existing installation. Project
versions and project-only tools belong in each repository's Nix `devShell`; see
the [project template and language shells](../templates/project/README.md).

## First use of the additional tools

1. Keep the wanted switches above enabled, then [apply the change](install/06-customization.md).
2. Open graphical tools from Plasma's application launcher. For transfers,
   choose SFTP in FileZilla; run `rclone config` to add a cloud account. Keep
   account credentials outside the repository.
3. Run `ncdu ~` or open Filelight to inspect disk usage. Remove Nix generations
   through the existing maintenance workflow, never by deleting `/nix/store` entries.
4. Download a file with `aria2c --continue=true 'https://host/path/file'`, replacing
   the example URL. No aria2 RPC server or download service is enabled.
5. In Bruno, create a collection and send a GET request to
   `http://127.0.0.1:11434/api/tags` after running `ollama-on`. In DBeaver, create
   a connection to an existing database; its first connection may download a driver.
6. For scanning, log out and back in after the first activation, connect the
   scanner, then select **New Profile → SANE** in NAPS2 and scan one page.
   Verify detection with `scanimage -L`. Network discovery and scanner sharing
   are not enabled; configure a network scanner explicitly if needed. OCR may
   require downloading language data in NAPS2.

PDF Arranger edits PDF pages; Okular remains the viewer. Use qpwgraph for desktop
PipeWire/EasyEffects routing and Audacity for recording/editing. Keep the existing
[direct DC-Elite playback procedure](10-audio.md) for exclusive DAC playback.

## LLVM and native debugging

1. Keep `features.languageTools.llvm = true` and [apply the change](install/06-customization.md).
2. Verify `clang --version`, `llvm-config --version`, `ld.lld --version` and
   `lldb --version`. The C switch also supplies `gdb`.
3. Select Clang per project with `CC=clang CXX=clang++ cmake -S . -B build-clang`.
   For an isolated toolchain, use `nix develop .#llvm` in this repository or
   `use flake .#llvm` in the project template's `.envrc`.

All LLVM components come from the same pinned `llvmPackages` set. GCC remains
available; installing LLVM does not change the system compiler, linker or CPU flags.

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
you no longer need pairing. An interface rule applies to **every network on that
interface**, not a particular Wi-Fi SSID: remove it before using that adapter on
an untrusted network, or use a dedicated trusted VPN interface and pair by IP.
This profile masks KDE Connect's login autostart
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

## Guile / Scheme

Guile 3 is enabled by default with `features.languageTools.guile = true`.
Run `guile` for the REPL, `guile hello.scm` for a script, or
`guile -c '(display (+ 20 22)) (newline)'` for a quick check. The pinned package
also provides `guild compile -o hello.go hello.scm` for explicit bytecode
compilation. Guile normally compiles source automatically; its JIT needs no
global CPU flags in this configuration. See the GNU Guile documentation for
[compilation](https://www.gnu.org/software/guile/manual/html_node/Compilation.html)
and [native JIT compilation](https://www.gnu.org/software/guile/manual/html_node/Just_002dIn_002dTime-Native-Code.html).

Set the global switch to `false` if Guile is only needed for individual
projects. `nix develop .#guile` still provides it from this repository, and the
project template supports `use flake .#guile` with direnv. This switch works
independently of `features.devCore` and installs no editor-specific extension.

## Beyond All Reason and Gamescope

1. Keep `features.gaming.beyondAllReason = true` and
   `features.gaming.gamescope = true`, then [apply the change](install/06-customization.md).
   Each switch works independently; set either to `false` to remove that package.
2. Open **Beyond All Reason** from the application menu, or run
   `beyond-all-reason`. On first launch, select **Update** to download the engine
   and game data, then **Start**. Allow roughly 20 GB for maps, replays and updates.
3. Verify a skirmish launches directly before trying Gamescope. Exit the game
   and launcher, then run:

   ```bash
   gamescope -f -w 1920 -h 1200 -r 60 -- beyond-all-reason
   ```

4. Select **Start** in the launcher. This starts with a 1920×1200 game surface
   and a 60 FPS limit; adjust those values after checking performance on the laptop.
   Use `Super+F` to toggle fullscreen. If nesting causes input or rendering issues,
   exit both programs and launch `beyond-all-reason` directly again.

The Gamescope limit applies to the nested game, not the physical panel refresh
policy. These instructions use SDR; do not add `--hdr-enabled`. Built-in panel
HDR remains disabled by `display.disableHdr`. Gamescope runs as a normal user
inside Plasma with no login autostart. Game data updates belong to the BAR
launcher; the packaged launcher and Gamescope follow this repository's pinned
Nixpkgs revision. Removing the packages does not remove downloaded game data.

References: [BAR first launch](https://www.beyondallreason.info/download),
[Gamescope controls](https://github.com/ValveSoftware/gamescope#keyboard-shortcuts).

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

Follow [apply a change](install/06-customization.md). If using NH, run
`nh os build`, then `nh os test`. **Stop and verify the changed behavior** before
running `nh os switch` as a separate step.

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
existing account. Signup is always disabled. See the [security guide](07-security-privacy.md)
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
see [snapshot retention](07-security-privacy.md#open-webui-state-and-first-admin-setup).

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
