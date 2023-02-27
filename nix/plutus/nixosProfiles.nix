{
  inputs,
  cell,
}: rec {
  benchmark = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [
      "${inputs.nixos}/nixos/modules/virtualisation/amazon-image.nix"
      github-runner
    ];
    nixpkgs.system = "x86_64-linux";
    users.users.plutus = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };
    security.sudo.wheelNeedsPassword = false;
    environment.etc."ssh/authorized_keys.d/plutus" = {
      mode = "0444";
      source = ./developer-auth-ssh-keys;
    };
    networking.hostName = "plutus-benchmark";
    environment.systemPackages = with pkgs; [
      vim
      direnv
      emacs
      binutils
      coreutils
      curl
      direnv
      dnsutils
      dosfstools
      fd
      git
      gotop
      gptfdisk
      iputils
      jq
      manix
      moreutils
      nix-index
      nmap
      ripgrep
      skim
      tealdeer
      usbutils
      utillinux
      whois
    ];
    nix = {
      gc.automatic = true;
      optimise.automatic = true;

      settings = {
        system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        extra-sandbox-paths = ["/bin/sh=${pkgs.bash}/bin/sh"];
        auto-optimise-store = true;
        sandbox = true;
        extra-experimental-features = "flakes nix-command";
        allow-import-from-derivation = true;
        trusted-users = ["root" "@wheel"];
        builders-use-substitutes = true;
        min-free = 536870912;
        keep-outputs = true;
        keep-derivations = true;
        fallback = true;
      };
    };
  };

  github-runner = {
    config,
    pkgs,
    lib,
    ...
  }: {
    services.github-runner = {
      enable = true;
      url = "https://github.com/input-output-hk/plutus";
      extraLabels = [config.services.github-runner.name];
      tokenFile = "/secrets/runner-token";
      extraPackages = with pkgs; [curl];
    };
  };
}
