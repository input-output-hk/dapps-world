{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) buildGoModule fetchFromGitHub nodejs-12_x;
  inherit (nixpkgs.lib) fakeHash;
in {
  inherit (nixpkgs) docker;
  sync-ssh-keys = buildGoModule {
    pname = "sync-ssh-keys";
    version = "v0.5.0";
    src = fetchFromGitHub {
      owner = "samber";
      repo = "sync-ssh-keys";
      rev = "v0.5.0";
      sha256 = "sha256-hr1/Jpl+ThRlE86o8NSReW/0ik4DgkH19fmQqkwA26A=";
    };

    vendorHash = "sha256-QBlURV8mOZ7tIyq/c5qNuZG9O/e7DNiuDgZV4B7OAKs=";
  };
  github-runner = nixpkgs.github-runner.overrideAttrs (catters: {
    postInstall = ''
      # Add node12 support for backwards compatibility
      mkdir -p $out/externals
      ln -s ${nodejs-12_x} $out/externals/node12
    '';
  });
}
