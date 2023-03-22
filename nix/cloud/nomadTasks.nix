{
  inputs,
  cell,
}: let
  inherit (cell) oci-images;

  # OCI-Image Namer
  ociNamer = oci: builtins.unsafeDiscardStringContext "${oci.imageName}:${oci.imageTag}";
in {
  sshd-github = {
    env = {
      SSHD_CONFIG = "/local/sshd_config";
      HOST_KEYS = "/secrets/ssh_host_rsa_key /secrets/ssh_host_ed25519_key";
    };
    meta = {
      # Default Values
      host_keys_dir = "/";
      extra_keys = "";
    };
    template = [
      {
        change_mode = "restart";
        perms = "700";
        data = ''
          {{- with secret "kv/data/sshd-github/github_token" }}
          HOST_KEYS_DIR={{ env "NOMAD_META_host_keys_dir" }}
          GITHUB_TEAMS={{ env "NOMAD_META_github_teams" }}
          GITHUB_TOKEN={{ .Data.data.token }}
          EXTRA_KEYS={{ env "NOMAD_META_extra_keys" }}
          {{ end -}}
        '';
        destination = "/secrets/github-token.env";
        env = true;
      }
      {
        change_mode = "restart";
        perms = "700";
        data = ''
          {{ $keyPath := "kv/data/sshd-github/host_keys" }}
          {{- with secret $keyPath }}{{ .Data.data.rsa }}{{ end -}}
        '';
        destination = "/secrets/ssh_host_rsa_key";
      }
      {
        change_mode = "restart";
        perms = "700";
        data = ''
          {{ $keyPath := "kv/data/sshd-github/host_keys" }}
          {{- with secret $keyPath }}{{ .Data.data.ed25519 }}{{ end -}}
        '';
        destination = "/secrets/ssh_host_ed25519_key";
      }
      {
        data = ''
          Banner none
          AddressFamily any
          Port 22

          X11Forwarding no

          PermitRootLogin no
          GatewayPorts no
          PasswordAuthentication no
          KbdInteractiveAuthentication yes

          PrintMotd no # handled by pam_motd

          KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
          MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

          LogLevel INFO
          UseDNS no
        '';
        destination = "/local/sshd_config";
      }
    ];
    config.image = ociNamer oci-images.sshd-github;
    config.ports = ["ssh"];
    service = {
      name = "\${NOMAD_NAMESPACE}-\${NOMAD_JOB_NAME}";
      tags = [
        "ingress"
        "traefik.enable=true"
        "traefik.tcp.routers.\${NOMAD_NAMESPACE}-\${NOMAD_JOB_NAME}.entrypoints=\${NOMAD_META_entrypoint}"
        "traefik.tcp.routers.\${NOMAD_NAMESPACE}-\${NOMAD_JOB_NAME}.rule=HostSNI(`*`)"
      ];
      port = "ssh";
    };
    user = "0:0";
    driver = "docker";
    kill_signal = "SIGINT";
    kill_timeout = "30s";
    resources.memory = 2048;
    vault = {
      change_mode = "noop";
      env = true;
      policies = ["sshd-github"];
    };
  };
}
