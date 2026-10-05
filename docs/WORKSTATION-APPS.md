# Workstation applications

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

Open WebUI is installed through the NixOS module and starts only on demand:

```bash
webui-on
webui-status
```

Open <http://127.0.0.1:3000>. Starting it also starts the existing Ollama service.
Create the first administrator account, then set `ai.webui.allowSignup = false`,
rebuild and restart the service. Authentication remains enabled. Nix owns the
managed environment settings, so corresponding Admin UI changes do not persist.

The service binds only to localhost, opens no firewall port, and uses the local
Ollama endpoint. Port 8080 remains available for llama.cpp. Its session key is
generated locally and retained in its private state directory; no password or
session secret is committed. Chats/accounts live under `/var/lib/open-webui`
(backed by systemd's private state directory); include that data in future backups.

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
