# Architecture and ownership

The configuration has one composition path:

```text
settings.nix + flake.lock
          │
       flake.nix
          ├── hosts/framework-pro/default.nix
          │         ├── disk.nix                 storage contract
          │         └── modules/nixos/*.nix     system services and hardware
          └── home/user/default.nix
                    └── home/modules/*.nix    applications and user settings
```

## Where a change belongs

| Concern | Owner | Rule |
| --- | --- | --- |
| Machine values, feature switches and bounded tuning | `settings.nix` | Preserve existing blocks; no secrets |
| Input revisions and shared package set | `flake.nix`, `flake.lock` | Update deliberately; keep NixOS and Home Manager packages aligned |
| Hardware composition and disk layout | `hosts/framework-pro/` | Keep host-specific topology here |
| Boot, networking, PAM, privileged services and hardware | `modules/nixos/` | System behavior stays outside Home Manager |
| Configured user applications and session policy | `home/modules/` | One module per meaningful configuration boundary |
| Small unconfigured tools | `dev-tools.nix`, `music-tools.nix` | Group related packages; avoid one file per binary |
| Project-specific versions and dependencies | Project `devShell` | Use the [project template](../templates/project/README.md) |
| Custom upstream builds and wrappers | `pkgs/` | Pin sources/hashes; keep wrapper dependencies explicit |
| Helper behavior and feature combinations | `tests/` and flake checks | Test production helpers and disabled profiles |

`home/user/default.nix` composes optional application groups. Their matching
NixOS service setup uses the same settings. Disabling a feature should remove
its packages, integration and commands together; it does not delete user data.

## AI model and service architecture

| Component | Role / endpoint | Source |
| --- | --- | --- |
| Ollama | On-demand system service; Intel Vulkan; `127.0.0.1:11434` | `modules/nixos/ai.nix` |
| Ollama CLI | Same package as the system service | `home/modules/ai.nix` |
| llama.cpp | Manually started Vulkan GGUF server; `127.0.0.1:8080` | `home/modules/ai.nix` |
| Continue | Editor client, model entries and optional MCP tools | `home/modules/continue-config.nix` |
| VSCodium | Immutable extensions and editor preferences | `home/modules/vscodium.nix` |
| Open WebUI | On-demand web client sharing Ollama; `127.0.0.1:3000` | `modules/nixos/ai.nix`, `pkgs/webui-bootstrap.nix` |
| Ollaya | Optional CPU decision-model user service; `127.0.0.1:11435` | `home/modules/ai.nix`, `ollaya-environment.nix`, `pkgs/ollaya.nix` |
| REA/Ghidra | Analysis tools; Continue calls REA over stdio MCP | `home/modules/rea.nix`, `pkgs/rea.nix` |

`features.localAI` gates the local runtimes and services. Continue also requires
`features.extraEditors`; REA tools require `features.rea`. REA's CLI works
without local AI or the editor. `rea.ollayaMcp` requires the optional Ollaya
integration. No rebuild downloads model weights.

Model settings have distinct owners:

- `settings.nix`: context/output limits, Ollama concurrency and retention,
  feature switches, and `rea.ollamaModel`.
- `home/modules/continue-config.nix`: providers, model entries and MCP wiring.
- User model stores: downloaded weights; never edit generated Continue YAML.

Ollama state has its own `/ollama` Btrfs subvolume; Ollaya models live under
`~/.ollaya/models`. Neither is included in root snapshots. The NPU is unused;
Ollaya does not inherit Ollama's Vulkan backend. See [local AI setup](LOCAL-AI-DEVELOPMENT.md).

## Installer boundary

`scripts/installer/` owns stages; `pkgs/installer.nix` supplies their runtime.
Storage expectations come from evaluated Disko, not a second hand-maintained
partition map. Each stage snapshots the reviewed Git source independently.

```text
preflight → plan → format → mounts → install → account
                     recovery: recover → mounts → install → account
```

`format` is destructive and requires exact disk confirmation. `recover` only
opens and mounts a complete compatible layout. The disk/layout/source record
prevents accidental cross-target continuation. The installed `/etc/nixos` is a
writable source snapshot without Git history; keep a separate trusted checkout.

## Add or change a feature

1. Choose the owner in the first table; reuse the existing package set.
2. If optional, gate system services, user packages, aliases and generated
   configuration consistently. Keep personal GUI preferences user-owned unless
   the documented policy intentionally manages them.
3. Add meaningful checks for new behavior and enabled/disabled combinations.
4. Document one short procedure: prerequisite → edit → common rebuild workflow
   → expected result. Keep destructive recovery and advanced reference separate.
5. Run [repository validation](install/validation.md), then verify the affected
   behavior on the laptop.

Entry points: [installation](INSTALL.md), [changes](install/customization.md),
[recovery](install/recovery.md). Feature guides link to these procedures rather
than maintaining their own activation sequences.
