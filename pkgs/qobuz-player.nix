{ qobuz-player, fetchFromGitHub }:

# The old repository is now only a relocation notice. Keep the release and
# source hash from locked Nixpkgs, fetching the same tree from its new home.
qobuz-player.overrideAttrs (old: {
  src = fetchFromGitHub {
    owner = "SofusA";
    repo = "qobine";
    tag = "v${old.version}";
    hash = old.src.outputHash;
  };

  meta = old.meta // {
    homepage = "https://github.com/SofusA/qobine";
    changelog = "https://github.com/SofusA/qobine/releases/tag/v${old.version}";
  };
})
