{ pkgs, osConfig, ... }:

{
  home.packages = [
    # llama.cpp is the lower-level local runtime for explicit GGUF,
    # context, quantization and backend control. nixpkgs' plain llama-cpp
    # is CPU-only; the -vulkan variant matches the Ollama service and is
    # served from the binary cache.
    pkgs.llama-cpp-vulkan

    # The Ollama daemon is a NixOS service. Reuse its exact package for the
    # user CLI so the closure does not also carry a second, CPU-only
    # ollama build.
    osConfig.services.ollama.package
  ];
}
