# Set up local AI

Guide 18 · [All guides](README.md).

Use **Ollama + Continue** for the default editor workflow. Use
[Open WebUI](12-workstation-apps.md#open-webui) for browser chat and
[REA](19-rea.md) for Ghidra analysis. All configured APIs bind to loopback.

## 1. Enable and apply

In `/etc/nixos/settings.nix`, keep `features.localAI = true` and
`features.extraEditors = true`. If you change them, follow
[apply a change](install/06-customization.md), then open a new terminal and restart
VSCodium. Extensions are Nix-managed; do not install them through the marketplace.

## 2. Verify Ollama and download the default coding model

```bash
systemctl is-active ollama.service
curl --fail http://127.0.0.1:11434/api/tags
ollama pull qwen2.5-coder:7b
ollama run qwen2.5-coder:7b
```

**Expected:** the service is `active`, the API returns JSON, the download
completes and the model answers. Exit the interactive prompt with `/bye`. Model
downloads are deliberate and are not part of a Nix rebuild. The service starts
at boot but no model occupies memory until a request loads it.

## 3. Use Continue

1. Run `codium` and open the Continue panel.
2. Select **Qwen2.5-Coder 7B (default)**. If it is missing, reload
   Continue after starting Ollama and completing the download.
3. Send a short chat request. For tools, use the configured **REA via Ollama**
   entry and follow [REA setup](19-rea.md).
4. Keep tool execution on **Ask First** and inspect proposed commands. Leave
   unknown repositories in restricted mode until their tooling is reviewed.

Autocomplete and automatic indexing are disabled by default. No cloud provider
or remote MCP endpoint is configured. Local inference does not isolate tools
from your files or make secrets safe to include in prompts.

## 4. Verify Intel GPU use

While a request runs, inspect:

```bash
ollama ps
journalctl -b -u ollama.service --no-pager
sudo intel_gpu_top
```

**Expected:** the Intel Vulkan device is used, logs show offload, and GPU activity
rises during inference. CPU fallback is not proof of acceleration. Ollama and
llama.cpp use Vulkan; neither uses the NPU. Ollaya uses a separate CPU backend.
Use [backend diagnostics and benchmarks](reference/32-ai-backends.md) if results
are unclear. No maximum-performance claim is made without laptop measurements.

## 5. Optional: unload the model

```bash
ollama stop qwen2.5-coder:7b
ollama ps
```

**Expected:** no model is listed. The service remains active for OpenCode and
other local clients; stopping a model releases its memory immediately.

## Change models or memory defaults

1. Edit existing fields in `/etc/nixos/settings.nix`; preserve the rest of the
   `ai` and `rea` blocks.

| Field | Default / purpose |
| --- | --- |
| `ai.contextLength` | `16384`; Ollama and Continue context default |
| `ai.maxOutputTokens` | `4096`; Continue output default |
| `ai.maxLoadedModels` | `1`; bounds resident Ollama model count |
| `ai.parallelRequests` | `1`; concurrent Ollama requests |
| `ai.keepAlive` | `"10m"`; idle retention |
| `ai.kvCacheType` | `"q8_0"`; halves KV-cache memory with Flash Attention |
| `rea.ollamaModel` | `"qwen3:8b"`; REA's separate tool-capable model |

2. To change provider entries, edit `home/modules/continue-config.nix`.
   To change extensions, edit `home/modules/vscodium.nix`. Never edit generated
   `~/.continue/config.yaml`.
3. Download any newly selected model explicitly with `ollama pull MODEL`. For
   harder, less latency-sensitive work, `qwen3-coder:30b` is available as an
   opt-in model; do not keep it loaded alongside another model.
4. Follow [apply a change](install/06-customization.md); restart VSCodium and verify
   the selected model, response and memory use.

These are defaults, not a memory quota: API requests/model metadata can override
context or retention, and one model can exhaust RAM. Larger context is not
always faster or better. `q8_0` needs active Flash Attention support; compare
it with `f16` if a model's output quality is unexpectedly affected.

## Optional: serve a GGUF with llama.cpp

1. Obtain a compatible GGUF outside this repository. Stop other large model
   workloads, then replace the filename below and start the server:

```bash
llama-server --host 127.0.0.1 --port 8080 \
  --model "$HOME/Models/YOUR_MODEL.gguf" --ctx-size 8192 --n-gpu-layers 99
```

2. In another terminal, run `curl --fail http://127.0.0.1:8080/health`.
3. Select **llama.cpp local server** in Continue. The server owns the actual
   model; tool support depends on its model and chat template.
4. Stop the server with `Ctrl-C`. If you change `ai.contextLength`, also change
   the manual server's `--ctx-size`.

## Optional: Ollaya decision models

Ollaya provides typed decisions, not a Continue chat provider. Its pinned backend
uses the CPU, with matching bundled llama.cpp libraries; Intel GPU/NPU support
is not configured. Closed Jev weights are not included. Open alternatives include
`jevk5` and `winnow:e4b`; evaluate their licenses and results for your task.

1. Set `ai.ollaya.enable = true` with `features.localAI = true`. Apply the change,
   then log out/in to refresh the user environment.
2. Start the managed service and download the smaller encoder starting model:

```bash
ollaya-on
curl --fail http://127.0.0.1:11435/api/version
ollaya pull laya:en
ollaya list
```

3. Run a decision request:

```bash
curl --fail-with-body http://127.0.0.1:11435/api/decide \
  -H 'Content-Type: application/json' \
  -d '{"model":"laya:en","state":"Please reset my login password.","questions":{"team":{"type":"choice","instructions":"Select the responsible team.","criteria":{"billing":"Payments and invoices","account":"Login and password access"}}}}'
```

**Expected:** a typed decision response; inspect whether the selected team fits
the request. To compare `jevk5`, run `ollaya pull jevk5` and change the request's
model. Compare repeated requests, latency, memory and correctness. CPU thread
selection uses upstream defaults and has not been tuned on this laptop.

4. Stop with `ollaya-off`. If you previously let the CLI auto-start a daemon,
   run `ollaya stop` before using `ollaya-on`; `ollaya-off` stops only the managed
   service. The user service is not a filesystem sandbox.
5. For optional Continue decision tools, follow [Ollaya MCP setup](19-rea.md#optional-ollaya-decision-tools).

The service keeps one resident model, a queue of 16 and five-minute idle
retention. Disabling `ai.ollaya.enable` removes integration, not model data.

## Model storage

| Runtime | Location | Backup requirement |
| --- | --- | --- |
| Ollama | `/var/lib/private/ollama`, exposed through `/var/lib/ollama` | Dedicated Btrfs subvolume; excluded from root snapshots |
| Ollaya | `~/.ollaya/models` | Home data; excluded from root snapshots |
| Manual GGUF | Your selected model directory | Back up irreplaceable files separately |

Old installations must complete [Ollama storage migration](install/25-ollama-migration.md)
before activating the separate mount. Fresh installations already have it.

For editor/language configuration, use [Editors](13-editors.md) and the
[project template](../templates/project/README.md). For upstream contracts and
repeatable backend comparisons, use [backend reference](reference/32-ai-backends.md).
