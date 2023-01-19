{
  inputs,
  cell,
}: let
  inherit (inputs) std nixpkgs cells;
  inherit (cells) automation;
  inherit (automation.packages) sync-ssh-keys;
  inherit (nixpkgs) openssh shadow cacert findutils bashInteractive;
in {
  sshd-github = std.lib.ops.mkOperable {
    package = openssh;
    runtimeInputs = [shadow cacert findutils];
    runtimeShell = bashInteractive;
    runtimeScript = ''
      #########################
      # ENVIRONMENT VARIABLES #
      #########################
      # SSHD_CONFIG (required): path to an sshd config file
      # GITHUB_TOKEN (required): token of user to query info about teams
      # GITHUB_TEAMS (required): space separated list of github teams to authorize
      # HOST_KEYS_DIR (default="/"): ssh host keys will be stored in $HOST_KEYS_DIR/etc/ssh
      #                              should be a persistant directory

      [ -z "''${SSHD_CONFIG:-}" ] && echo "SSHD_CONFIG env var must be set -- aborting" && exit 1
      [ -z "''${GITHUB_TOKEN:-}" ] && echo "GITHUB_TOKEN env var must be set -- aborting" && exit 1
      [ -z "''${GITHUB_TEAMS:-}" ] && echo "GITHUB_TEAMS env var must be set -- aborting" && exit 1
      HOST_KEYS_DIR=''${HOST_KEYS_DIR:-"/"}

      # shellcheck source=/dev/null
      source ${cacert}/nix-support/setup-hook

      # rewrite /bin/debug to /bin/debug-shell as a proper shell
      sed 's|exec /nix/store/.*bash|& "$@"|' /bin/debug > /bin/debug-shell

      # Setup Users
      mkdir -p /var/empty /root /home/dev

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

      mkdir -p /etc/ssh/
      for TEAM in $GITHUB_TEAMS; do
          ${sync-ssh-keys}/bin/sync-ssh-keys \
            --github-token="$GITHUB_TOKEN" \
            --github-org=input-output-hk \
            --github-team="$TEAM" \
            >> /etc/ssh/authorized_keys
      done

      # Generate host keys if they don't exist
      mkdir -p "$HOST_KEYS_DIR/etc/ssh/"
      ${openssh}/bin/ssh-keygen -A -f "$HOST_KEYS_DIR"
      HOST_KEYS_ARG=$(find "$HOST_KEYS_DIR/etc/ssh/" -mindepth 1 -type f -name "*_key" -printf "-h %h/%f ")

      # shellcheck disable=SC2086
      ${openssh}/bin/sshd \
        -D -f "$SSHD_CONFIG" \
        $HOST_KEYS_ARG \
        -o "AuthorizedKeysFile /etc/ssh/authorized_keys" \
        -o "LogLevel DEBUG" \
        -o "UsePAM no"

    '';
  };
}
