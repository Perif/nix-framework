# Apply a configuration change

Guide 06 · [All guides](../README.md).

Use this procedure on the installed laptop. Work in `/etc/nixos`; it is a
writable snapshot without Git history. Never run Disko or `installer format`
for configuration changes.

## 1. Back up and edit

```bash
sudo cp -a /etc/nixos "/etc/nixos.backup-$(date +%Y%m%d-%H%M%S)"
sudoedit /etc/nixos/settings.nix
```

Edit existing fields, preserving the rest of each block. For changes outside
`settings.nix`, use `sudoedit` on the owning source file below. Do not edit
Nix-managed links under `~/.config` or `~/.continue`.

| Change | Source under `/etc/nixos` | Instructions |
| --- | --- | --- |
| Timezone, software groups, power, Wi-Fi, audio/display selections | `settings.nix` | [Applications](../12-workstation-apps.md), [performance](../21-performance.md), [networking](../08-networking.md), [audio](../10-audio.md), [display](../09-display.md) |
| Continue providers and model entries | `home/modules/continue-config.nix` | [Local AI](../18-local-ai-development.md) |
| Context/output defaults and REA model | `settings.nix`: `ai.*`, `rea.ollamaModel` | [Local AI](../18-local-ai-development.md), [REA](../19-rea.md) |
| VSCodium extensions and editor preferences | `home/modules/vscodium.nix` | [Editors](../13-editors.md) |
| Vim/Neovim, Sublime or shell preferences | `home/modules/vim.nix`, `sublime.nix`, `zsh.nix` | [Editors](../13-editors.md) |
| Browser policies | `home/modules/firefox.nix`, `modules/nixos/browsers.nix` | [Firefox](../15-firefox.md), [Chromium](../16-chromium-browsers.md) |
| Add a configured application or system service | Its Home Manager or NixOS module | [Ownership rules](../29-modularity.md) |

Keep secrets outside the source and Nix store. For dependency updates, first
follow [update pinned inputs](../27-updates.md).

## 2. Evaluate and build

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
nix flake check --no-build --all-systems
sudo nixos-rebuild build --flake ".#${INSTALL_HOST}"
)
```

**Expected:** both commands succeed. Evaluation checks configuration; `build`
produces the system without activating it. `dry-build` only reports what would
be built and is not a substitute for this step.

For kernel, initrd, storage or bootloader changes, skip temporary activation
and use [the reboot procedure](#boot-related-changes). For other changes, continue.

## 3. Activate temporarily

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild test --flake ".#${INSTALL_HOST}"
)
```

This changes the running system; the previous boot default remains available.
It does not roll back mutable application data or replace the running kernel.

## 4. Stop and verify

```bash
systemctl --failed
```

Read the output: this command can exit successfully while listing failures.
Then check DNS, open a new terminal, and test the application or setting you
changed. Start on-demand AI services explicitly if testing them. Apply any
logout/login requirement in the feature guide before checking desktop behavior.

**Do not continue until the expected behavior works.** On failure, keep the
previous boot default, restore the backed-up source, and diagnose the logs.
Reboot to the previous default if temporary activation leaves the session broken.

## 5. Make the verified configuration permanent

Do not edit source or update the lock between verification and this command:

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
)
```

**Expected:** activation succeeds and the verified generation becomes the boot
default. Keep the source backup until you have also completed a successful reboot.

## Boot-related changes

1. Complete steps 1–2. Check free space with `df -h /boot`; retain a working boot
   entry and room for another kernel/initrd or signed image.
2. Complete any prerequisite migration first. Older Ollama storage requires
   [this migration](25-ollama-migration.md); Secure Boot uses [its own sequence](23-secure-boot.md).
3. Install the next boot generation:

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild boot --flake ".#${INSTALL_HOST}"
)
```

4. After the command succeeds, save work and reboot. Complete the
   [first-boot checks](05-first-boot.md) and the feature-specific verification.
5. If boot fails, select the previous generation from the systemd-boot menu.
   Restore the previous source before the next rebuild. A generation rollback
   does not undo disk-layout changes or application data migrations.

## Optional Zsh / NH shortcuts

`nix-check`, `nix-test`, `nix-boot` and `nix-switch` provide the corresponding
operations above. `nix-dry` previews builds only. NH uses `/etc/nixos` by default:
`nh os build`, `nh os test` and `nh os switch` have the same verification pause
between test and switch. Neither tool replaces the checks in step 4.
