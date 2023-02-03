{
  inputs,
  cell,
}: let
  inherit (inputs) std nixpkgs cells;
  inherit (cells) automation;
  inherit (automation.packages) sync-ssh-keys;
  inherit
    (nixpkgs)
    openssh
    shadow
    cacert
    findutils
    bashInteractive
    gnused
    github-runner
    git
    vim
    emacs
    nix
    ;
in {
  sshd-github = std.lib.ops.mkOperable {
    package = openssh;
    runtimeInputs = [shadow cacert findutils gnused];
    debugInputs = [git vim emacs nix];
    runtimeShell = bashInteractive;
    runtimeScript = ''
      #########################
      # ENVIRONMENT VARIABLES #
      #########################
      # SSHD_CONFIG (required): path to an sshd config file
      # GITHUB_TOKEN (required): token of user to query info about teams
      # GITHUB_TEAMS (required): space separated list of github teams to authorize
      # HOST_KEYS (required): path to host keys to pass to the ssh daemon

      [ -z "''${SSHD_CONFIG:-}" ] && echo "SSHD_CONFIG env var must be set -- aborting" && exit 1
      [ -z "''${GITHUB_TOKEN:-}" ] && echo "GITHUB_TOKEN env var must be set -- aborting" && exit 1
      [ -z "''${GITHUB_TEAMS:-}" ] && echo "GITHUB_TEAMS env var must be set -- aborting" && exit 1
      [ -z "''${HOST_KEYS:-}" ] && echo "HOST_KEYS env var must be set -- aborting" && exit 1

      # Setup openssl support for git, nix, etc
      # shellcheck source=/dev/null
      source ${cacert}/nix-support/setup-hook
      mkdir -p /etc/ssl/certs/
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

      # Setup /tmp
      mkdir -p /tmp && chmod 777 /tmp

      # Setup nix flakes support
      mkdir -p /etc/nix
      cat > /etc/nix/nix.conf <<- EOF
        extra-experimental-features = flakes nix-command
        allow-import-from-derivation = true
        substituters = https://cache.nixos.org/
        trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
        store = /local/nix
      EOF

      # rewrite /bin/debug to /bin/debug-shell as a proper shell
      sed 's|exec /nix/store/.*bash|& "$@"|' /bin/debug > /bin/debug-shell
      chmod 755 /bin/debug-shell

      # Setup Users
      cat > /etc/passwd <<- EOF
        root:x:0:0:System administrator:/root:/bin/runtime
        dev:x:1000:0:Developer login:/home/dev:/bin/debug-shell
        sshd:x:992:990:SSH privilege separation user:/var/empty:${shadow}/bin/nologin
      EOF
      cat > /etc/shadow <<- EOF
        root:!:1::::::
        dev:*:1::::::
        sshd:!:1::::::
      EOF

      mkdir -p /var/empty /root /home/dev
      chown dev:0 /home/dev
      chmod 750 /home/dev


      mkdir -p /etc/ssh/
      for TEAM in $GITHUB_TEAMS; do
          ${sync-ssh-keys}/bin/sync-ssh-keys \
            --github-token="$GITHUB_TOKEN" \
            --github-org=input-output-hk \
            --github-team="$TEAM" \
            >> /etc/ssh/authorized_keys
      done

      HOST_KEYS_ARG=$(IFS=' '; for KEY in $HOST_KEYS; do echo -n "-o HostKey=$KEY "; done)

      # shellcheck disable=SC2086
      ${openssh}/bin/sshd \
        -D -f "$SSHD_CONFIG" \
        -o LogLevel=INFO \
        -o UsePAM=no \
        $HOST_KEYS_ARG \
        -o AuthorizedKeysFile=/etc/ssh/authorized_keys

    '';
  };
}
