# VSCodium and local AI development

For REA reverse-engineering tools backed by Ollama, including optional Ollaya
MCP integration, follow [REA setup](REA.md).

VSCodium is the open-source-binary build of VS Code. This configuration keeps
the editor, its extensions, and the Continue model configuration declarative.
It is intended for light, on-demand assistance through the loopback-only
Ollama service or a manually started llama.cpp server.

For standalone local chat, Open WebUI is installed on demand at
`http://127.0.0.1:3000`. See [startup and account setup](WORKSTATION-APPS.md#open-webui).
It shares Ollama with Continue; it does not start another model runtime.

## Installed components

- VSCodium with update, experiment, crash-report, and telemetry checks disabled;
- Continue configured with only `127.0.0.1` model endpoints and agent-capable
  Chat/Edit/Apply roles;
- Nix IDE with `nixd` and `nixfmt`;
- Python, Debugpy, BasedPyright, and Ruff extensions plus their pinned CLI
  tools;
- Go with the official Go extension, `gopls`, Delve, and GolangCI-Lint;
- Rust with rust-analyzer, CodeLLDB, rustfmt, and Clippy;
- YAML, TOML, and EditorConfig extensions;
- workspace trust enabled for unknown repositories;
- format-on-save for Nix, Python, Go, and Rust, with generated dependency/build
  trees excluded from file watching and search;
- tab completion, next-edit prediction, and automatic codebase indexing paused
  by default to avoid continuous GPU, CPU, and battery use.

The extension directory is immutable. Add or remove extensions in
`home/modules/vscodium.nix`, update `flake.lock` deliberately, and rebuild.
This prevents a marketplace update from silently changing the reviewed
extension set between Nix generations.

Continue is the only agent extension. Adding Cline, Roo Code, or another agent
beside it would duplicate broad repository/terminal privileges, background
indexing, settings, and model connections. Add a second agent only after a
specific missing workflow justifies that extra attack and resource surface.

## Verify after the rebuild

```bash
command -v codium
command -v ollama
command -v llama-server
command -v nixd
command -v nixfmt
command -v basedpyright
command -v ruff
command -v go
command -v gopls
command -v dlv
command -v golangci-lint
command -v rustc
command -v cargo
command -v rust-analyzer
codium --list-extensions
systemctl show ollama.service -p ActiveState
```

The extension list should contain these twelve IDs and no marketplace-only
surprises:

```text
charliermarsh.ruff
Continue.continue
detachhead.basedpyright
editorconfig.editorconfig
golang.Go
jnoortheen.nix-ide
ms-python.debugpy
ms-python.python
redhat.vscode-yaml
rust-lang.rust-analyzer
tamasfe.even-better-toml
vadimcn.vscode-lldb
```

Verify the language toolchain itself:

```bash
python --version
basedpyright --version
ruff --version
go version
gopls version
dlv version
golangci-lint version
rustc --version
cargo --version
rust-analyzer --version
rustfmt --version
```

Language servers start only when a matching file is opened. BasedPyright checks
open files by default, while Go static analysis and Rust Clippy remain enabled
for meaningful project feedback. Large generated `.direnv`, `.venv`,
`node_modules`, `result`, and `target` trees are not recursively watched.

## Customize project formatting

The global profile provides safe defaults; repository-owned `.editorconfig`,
`pyproject.toml`, `go.mod`, and `rustfmt.toml` files remain authoritative. A
minimal cross-editor `.editorconfig` is:

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

[*.go]
indent_style = tab

[*.rs]
indent_style = space
indent_size = 4
```

Store project policy in the repository rather than changing global preferences
for one codebase. VSCodium and Sublime consume EditorConfig directly; Vim and
Neovim use the pinned EditorConfig plug-in.

The first boot-time check should report `ActiveState=inactive`: the service is
installed but has no boot target. There should be no idle Ollama process or
listener. Start it only when needed, then verify the loopback API:

```bash
ollama-on
systemctl is-active ollama.service
curl --fail http://127.0.0.1:11434/api/tags
```

The final two commands should report `active` and return JSON. Ollama remains
bound only to `127.0.0.1:11434`; do not expose it to the LAN merely to use
VSCodium. The aliases expand to `sudo systemctl start ollama.service` and
`sudo systemctl stop ollama.service`, so sudo still requires the account
password. Use `ollama-status` for logs and current state.

The service keeps its DynamicUser sandbox. Its state, including models, lives
on the dedicated `/ollama` Btrfs subvolume mounted at
`/var/lib/private/ollama`; `/var/lib/ollama` is systemd's symlink to it. Root
snapshots exclude that subvolume, so back up irreplaceable models separately.
Existing installations must follow the
[one-time migration](INSTALL.md#one-time-model-storage-migration-for-an-existing-installation)
before activating this layout. Fresh Disko installations need no migration.

## Set up an Ollama model

No model is downloaded by a Nix rebuild. Model files are large, model support
changes faster than this configuration, and the appropriate quantization is a
user choice. List existing models and then deliberately pull a current,
tool-capable coding model that fits the laptop:

```bash
ollama-on
ollama list
ollama pull REPLACE_WITH_TOOL_CAPABLE_MODEL
ollama run REPLACE_WITH_TOOL_CAPABLE_MODEL
```

For this 32 GiB laptop, begin with a quantized 7B-to-14B-class model and the
configured 8,192-token context. Larger models or contexts can be substantially
slower and consume enough memory to pressure the desktop. Confirm that the
selected model supports tool/function calling before relying on Agent mode.

Launch `codium`, open the Continue panel, choose **Ollama local models**, and
select the model returned by `ollama list`. Chat, Edit, Apply, and Agent mode
are available on demand. Autocomplete remains off; enable it only after
measuring latency, power use, and whether a dedicated smaller completion model
is worthwhile.

## Use a GGUF model with llama.cpp

Place a deliberately obtained GGUF model outside this repository, then start a
loopback server. Replace the filename with the actual path:

```bash
mkdir -p "$HOME/Models"
llama-server \
  --host 127.0.0.1 \
  --port 8080 \
  --model "$HOME/Models/REPLACE_WITH_MODEL.gguf" \
  --ctx-size 8192 \
  --n-gpu-layers 99
```

In a second terminal, verify the endpoint:

```bash
curl --fail http://127.0.0.1:8080/health
```

Select **llama.cpp local server** in Continue. The configured model identifier
is the neutral value `local`; the running server owns the actual GGUF model.
Ollama is the better first choice for Agent mode because it can advertise
model capabilities directly. llama.cpp depends on the selected model's chat
template and tool-call support.

Run one large local model runtime at a time unless measurements show that both
fit comfortably. Stop the manual llama.cpp server with `Ctrl-C`. Ollama unloads
idle models, and a specific model can be released immediately with:

```bash
ollama stop REPLACE_WITH_MODEL
```

When all Ollama work is finished, stop the daemon as well and confirm that the
loopback endpoint has closed:

```bash
ollama-off
systemctl show ollama.service -p ActiveState
```

The final command should report `ActiveState=inactive`. Starting a Continue
request does not automatically start the service; run `ollama-on` before
selecting the Ollama provider.

## Change the local resource limit

Edit the `ai` block in `settings.nix`. Its default context is 8,192 tokens,
with at most 2,048 generated tokens in Continue; both editor providers use
these values. Ollama also receives the context default, a single loaded-model
limit, one parallel request, and a five-minute idle timeout. These are defaults,
not a hard memory quota: model metadata and API requests can override context
and keep-alive, and a single model can still exhaust memory. A manually started
llama.cpp server must use the matching `--ctx-size`.

```nix
ai = {
  contextLength = 8192;
  maxOutputTokens = 2048;
  maxLoadedModels = 1;
  parallelRequests = 1;
  keepAlive = "5m";
  kvCacheType = "f16";
  ollaya.enable = true;
};
```

Flash Attention remains on Ollama's support-detected default. `q8_0` is an
optional KV-cache setting that saves memory when Flash Attention is active;
compare quality and logs before adopting it. `q4_0` trades more precision for
memory and is not the recommended default. Cloud inference and web search in
Ollama are explicitly disabled through `OLLAMA_NO_CLOUD=1`; model pulls still
require network access.

Apply the change safely:

```bash
cd /etc/nixos
sudo nixos-rebuild test --flake .#framework-pro
sudo nixos-rebuild switch --flake .#framework-pro
```

Larger values increase time-to-first-token and memory use; they do not improve
every task.

## Intel acceleration and measured tuning

Ollama and the standalone llama.cpp package use Vulkan through Mesa's Intel
driver. `OLLAMA_IGPU_ENABLE=1` explicitly admits the integrated Intel GPU:
Ollama 0.32.3 otherwise drops integrated Vulkan devices during discovery, even
with the Vulkan package installed. The Framework hardware module already supplies Intel graphics and
compute runtimes. Installing OpenCL, oneAPI or OpenVINO does not change these
applications' inference backend. The NPU is not used by either configured
runtime. There is no measured basis here to replace Vulkan with SYCL or to
claim this is the fastest possible stack for every model.

Check on the laptop while a model is loaded:

```bash
vulkaninfo --summary
llama-server --list-devices
ollama ps
journalctl -b -u ollama.service --no-pager
sudo intel_gpu_top
free -h
```

Look for the Intel device, model offload in the logs and GPU activity during
inference. `ollama ps` reports CPU/GPU placement. Software Vulkan rendering or
CPU fallback is not proof of GPU acceleration. Intel's integrated GPU shares
RAM and power with the CPU, so leave room for Plasma and other applications.

For a GGUF already on disk, compare the same prompt/generation sizes under the
same power profile. Repeat each run and record prompt-processing and decoding
rates separately; do not compare different quantizations as a backend test:

```bash
llama-bench -m "$HOME/Models/REPLACE_WITH_MODEL.gguf" -ngl 0 -p 512 -n 128 -r 5
llama-bench -m "$HOME/Models/REPLACE_WITH_MODEL.gguf" -ngl 99 -p 512 -n 128 -r 5
```

For CPU measurements, also sweep `-t 4`, `-t 8` and the physical-core count from
`lscpu`. These are comparison points, not prescribed thread counts for this
hybrid CPU. Compare cold load time separately from warm requests, then check
sustained speed, temperature and desktop responsiveness. Test AC `balanced`
against `performance`: CPU and integrated-GPU power competition can make a
larger CPU budget slower for some GPU workloads.

## Ollaya: Jev-style decision models

`ai.ollaya.enable = true` installs Ollaya 0.7.5 and an on-demand user service.
It has its own API on loopback port 11435, separate from Ollama's 11434.
Ollaya handles typed decisions; it is not a Continue chat provider. The closed
Jev weights are not included. Open alternatives include `jevk5` and
`winnow:e4b`; `laya:en` is a smaller encoder starting point for CPU use.
Consult the model's license and evaluate its decisions on your actual task.

This package pins the official Linux CPU archive and patches its ELF loader
and library paths for NixOS. It preserves Ollaya's matching llama.cpp libraries
because their ABI is checked by the application. It does not substitute the
separately installed llama.cpp or install a CUDA pack. **Intel GPU/NPU
acceleration is not supported by this Ollaya configuration.** ONNX graph
optimizations are enabled upstream; CPU thread selection remains upstream's.
In 0.7.5 the GGUF backend uses half the logical CPU count by default and the
daemon exposes no supported thread-count setting. That heuristic needs
benchmarking on this hybrid Intel CPU before calling it optimized.

After rebuilding, log out/in to refresh the user environment, then:

```bash
ollaya-on
curl --fail http://127.0.0.1:11435/api/version
ollaya llama-devices
ollaya pull laya:en
ollaya list
```

A minimal decision request:

```bash
curl --fail-with-body http://127.0.0.1:11435/api/decide \
  -H 'Content-Type: application/json' \
  -d '{"model":"laya:en","state":"Please reset my login password.","questions":{"team":{"type":"choice","instructions":"Select the responsible team.","criteria":{"billing":"Payments and invoices","account":"Login and password access"}}}}'
```

To compare a Jev-style GGUF model, deliberately download `ollaya pull jevk5`
and change the request's model to `jevk5`. Alternatively try `winnow:e4b`.
CPU latency will differ substantially from upstream GPU benchmarks. Warm the
model first, repeat a fixed request and compare `eval_duration`,
`total_duration`, memory use and correctness. Use `ollaya ps` and
`journalctl --user -u ollaya.service` to inspect the runner.

The service permits one resident model, a queue of 16 requests and a
five-minute idle timeout. Its models live in `~/.ollaya/models` on the existing
home subvolume, outside root snapshots; back them up separately if needed.
No models are downloaded during rebuild. Stop it with `ollaya-off`.

The upstream CLI can auto-start a background daemon if the service is stopped.
Prefer `ollaya-on` first, so systemd owns its lifecycle and logs. If you already
started one through the CLI, run `ollaya stop` before `ollaya-on`; `ollaya-off`
only stops the managed unit. Unlike Ollama's system service, this user service
runs with your user identity and is not a filesystem isolation boundary.
Setting `ai.ollaya.enable = false` removes the integration after rebuilding;
it does not delete downloaded models.

For an existing TypeSafe SDK client, point `TYPESAFE_BASE_URL` at
`http://127.0.0.1:11435`, provide the SDK's required nonempty local API-key
placeholder, and select an installed open model. No remote TypeSafe service
or genuine Jev model is configured. See the upstream compatibility reference.

On the target laptop, build the package with `nix build .#ollaya` before
activation. Its install checks exercise CLI startup and CPU backend discovery
without downloading a model. Evaluation on macOS does not run those checks
or establish successful inference; perform the decision request above too.

## Privacy and agent safety boundary

VSCodium removes Microsoft's product endpoints, but extensions are independent
programs. Continue's anonymous telemetry is disabled in both editor settings
and its shared configuration, and no cloud provider, API key, remote MCP
server, or remote configuration URL is declared. Local prompts and code are
sent to the selected loopback model server.

The Python, Go, Rust, debugger, and language-server extensions can execute
project tooling. Workspace Trust and disabled automatic tasks reduce surprise
execution but cannot make a trusted malicious repository safe. Keep an unknown
repository restricted until its tasks, build scripts, and extension requests
have been reviewed.

This does not make an agent harmless. An approved tool call can read project
files, execute commands, or modify a repository. Open untrusted repositories in
restricted mode, inspect the proposed command, review `git diff`, and keep the
existing credential/PII hooks enabled. Do not paste secrets into prompts merely
because inference is local; model session data and terminal output remain on
the laptop.

## Primary references

- [VSCodium](https://vscodium.com/)
- [BasedPyright](https://docs.basedpyright.com/)
- [VS Code Go extension](https://github.com/golang/vscode-go)
- [rust-analyzer](https://rust-analyzer.github.io/)
- [Continue with Ollama](https://docs.continue.dev/customize/model-providers/top-level/ollama)
- [Continue with llama.cpp](https://docs.continue.dev/customize/model-providers/more/llamacpp)
- [Continue offline configuration](https://docs.continue.dev/guides/running-continue-without-internet)
- [Ollama Linux documentation](https://docs.ollama.com/linux)
- [llama.cpp server](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)
- [Ollama GPU support](https://docs.ollama.com/gpu)
- [Ollama memory and Flash Attention settings](https://docs.ollama.com/faq)
- [Ollaya 0.7.5 release](https://github.com/ollaya-dev/ollaya/releases/tag/v0.7.5)
- [Ollaya API and environment](https://github.com/ollaya-dev/ollaya/blob/v0.7.5/docs/api.md)
- [Ollaya CPU inference implementation](https://github.com/ollaya-dev/ollaya/tree/v0.7.5/crates/ollaya-runner/src)
- [Ollaya TypeSafe compatibility](https://ollaya.dev/docs/typesafe-compatibility)

- [Pinned Ollama integrated-GPU admission](https://github.com/ollama/ollama/blob/v0.32.3/discover/runner.go)
