# AI backend verification

Guide 32 · [All guides](../README.md).

Complete [local AI setup](../18-local-ai-development.md) first. Run these measurements
on the laptop; a successful build does not establish speed or GPU offload.

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
