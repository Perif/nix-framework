# REA with local models

1. Keep `features.rea`, `features.localAI` and `features.extraEditors` enabled.
2. Apply any change using [the common workflow](install/customization.md).
3. Follow [Start with Ollama](#start-with-ollama), then verify one small binary.

`features.rea = true` installs [Reverse Engineer Anything (REA)](https://github.com/morluto/rea)
6.4.0, its supported Ghidra 12.1.4 backend, and Java 21. REA supplies analysis
commands and MCP tools. Continue runs the conversation using the existing
Intel Vulkan Ollama service; REA itself does not load a language model.

The npm release, exact upstream dependency lock, npm dependency cache, and
official Ghidra archive are hash-pinned. No `npm install`, `npx`, provider
installer, or model download runs during activation. Java/Ghidra paths are
scoped to the REA wrapper, leaving other Java development environments alone.
The same Ghidra build is also available as `ghidra` and
`ghidra-analyzeHeadless`, with a desktop launcher. REA uses its headless backend;
you do not need to open the Ghidra GUI first.

## Start with Ollama

Keep `features.rea`, `features.localAI`, and `features.extraEditors` enabled,
then rebuild. Start Ollama and explicitly download the selected model once:

```bash
ollama-on
ollama pull qwen3:8b
rea doctor --provider ghidra --format json
```

The default `rea.ollamaModel = "qwen3:8b"` selects a
[tool-capable model](https://ollama.com/library/qwen3:8b). Change it to another
installed **tool-capable** Ollama model in `settings.nix` and rebuild if desired.
This selection declares tool support to Continue; it cannot give that ability
to a model that lacks it. The general **Ollama local models** autodetection and
**llama.cpp local server** entries remain available.

Open VSCodium's Continue panel, select **REA via Ollama**, and switch to
**Agent** mode. The declarative MCP server invokes the exact installed `rea mcp`
through stdio. No MCP network listener or API key is needed. If the editor was
already open during the rebuild, restart it to reload its configuration.
REA tool requests allow up to five minutes for Ghidra startup and analysis.

**Before the first request, choose a small tool set.** REA 6.4 advertises a
large catalog (170 tools in the initial local check). In Continue's tools menu,
exclude unneeded tools and retain **Ask First** for the ones you use. A useful
native-analysis starting set is `open_binary`, `binary_session`,
`search_procedures`, `procedure_pseudo_code`, and `close_binary`. Tools for
other workflows can be enabled when needed. The wrapper uses compact schemas,
but this does not make the entire catalog fit the default 8,192-token context.
Continue keeps these [tool policies](https://docs.continue.dev/ide-extensions/agent/how-to-customize)
in its user state.

For a first analysis, give the absolute path to a small program you built and
ask: “Open this executable with REA's Ghidra provider, find main, show its
pseudocode, then close the binary.” Accept the corresponding tool requests.
This exercises the model, client, and analysis backend together.

The CLI works independently of the editor and local models:

```bash
rea --help
rea analyze /absolute/path/to/program --provider ghidra --format json
```

Do not run `rea setup` to configure this managed client: Home Manager already
owns `~/.continue/config.yaml`. Other REA providers, such as Hopper, IDA, JEB,
browser automation, or Android tooling, have separate prerequisites and are
not installed by this feature. An unscoped `rea doctor` may report their absence;
the scoped Ghidra check above tests the backend supplied here.

## Optional Ollaya decision tools

Ollaya 0.7.5 supports [stdio MCP](https://github.com/ollaya-dev/ollaya/blob/v0.7.5/site/docs/agents.md).
To add its decision tools alongside REA:

```nix
features.rea = true;
features.localAI = true;
features.extraEditors = true;
ai.ollaya.enable = true;
rea.ollayaMcp = true; # Default: false.
```

Rebuild and restart VSCodium. **Ollaya decisions** appears as a second MCP
server. Its environment shares the same loopback address (`127.0.0.1:11435`),
CPU backend, private model directory, one-loaded-model limit, and five-minute
keep-alive as the existing Ollaya CLI and user service. Prefer `ollaya-on`
before using it so the managed service owns the daemon.

Ollama still runs the language model. The agent can pass text or analysis
results to Ollaya's `decide` tool for typed classifications or scores. Ollaya
does not provide the chat API that Continue's Ollama provider expects, so do
not substitute port 11435 into the model entry.

Ollaya's MCP can start its daemon, and `decide` can pull a missing model on
first use; it also exposes `pull_model`. Keep these tools on **Ask First** and
exclude `pull_model` if downloads should stay manual. For offline work,
explicitly pull the chosen model beforehand using the
[Ollaya setup guide](LOCAL-AI-DEVELOPMENT.md#optional-ollaya-decision-models).
Disabling `rea.ollayaMcp` removes the client connection while preserving the
separately selected Ollaya CLI/service.

## Selection, performance, and validation

- `features.rea = false` removes REA/Ghidra and its model/MCP registration.
- Disabling local AI or extra editors leaves REA usable from the terminal.
  The optional Ollaya MCP switch requires both, and evaluation rejects an
  incompatible combination.
- `ai.contextLength` and `ai.maxOutputTokens` also apply to **REA via Ollama**.
  Ghidra analysis, model inference, and Nix builds share RAM. Begin with small
  binaries and focused tool results; measure memory before raising context or
  running several analyses. The [performance guide](PERFORMANCE.md) describes
  build limits and Intel runtime measurements.
- `nix build .#checks.x86_64-linux.rea-configuration .#checks.x86_64-linux.rea`
  checks feature selection, real MCP discovery, Ghidra analysis of a compiled
  fixture, and optional Ollaya discovery without pulling models. The full
  system build includes the default REA package.

These checks do not establish model reasoning quality, editor interaction, or
Intel GPU throughput on the laptop. Verify the first Agent-mode analysis and
`ollama ps` there after installation.
