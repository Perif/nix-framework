# Project development environment

Run `nix flake lock`, review and commit `flake.nix`, `flake.lock`, `shells.nix`
and `.envrc`, then run `direnv allow`. The default shell includes Git, Just,
ShellCheck and shfmt. Select a language by changing `.envrc` to, for example,
`use flake .#python`, then review and allow the change. Available shells are
`c`, `llvm`, `python`, `go`, `rust`, `guile`, `nodejs` and `nix`; combine packages in `shells.nix`
when a project needs several languages. Without direnv, use `nix develop
.#python` (replace `python` with the desired shell).

Commit dependency locks too: for example `uv.lock`, `Cargo.lock` or
`package-lock.json`. For Python, run `uv sync --python "$(command -v python3)"`
inside the shell to create a project-local virtual environment. Nix provides
the interpreter and tools; the language lock fixes the application dependencies.
Keep virtual environments, build outputs and secrets out of Git.

The `guile` shell supplies Guile 3 and `guild`. Start its Scheme REPL with
`guile`, run a file with `guile hello.scm`, or compile it explicitly with
`guild compile -o hello.go hello.scm`.

Review any `.envrc` before allowing it: direnv executes project code. This
template pins tools once its lock file is created; update that lock deliberately.
There is no global compiler tuning or environment override that would break
binary-cache compatibility.

The `llvm` shell provides Clang, clangd/Clang tools, LLVM, LLD, LLDB, CMake,
Ninja and pkg-config. Select the compiler explicitly for CMake projects:
`CC=clang CXX=clang++ cmake -S . -B build-clang`.
