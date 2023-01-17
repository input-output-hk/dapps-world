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
      HOST_KEYS_DIR = "/";
    };
    template = [
      {
        change_mode = "restart";
        data = ''
          {{- with secret "kv/data/sshd-github/github_token" }}
          GITHUB_TEAMS={{ env "NOMAD_META_sshd_github_teams" }}
          GITHUB_TOKEN={{ .Data.data.token }}
          {{ end -}}
        '';
        destination = "/secrets/github-token.env";
        env = true;
      }
      {
        data = ''
          Banner none
          AddressFamily any
          Port 22

          X11Forwarding no

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
      name = "\${NOMAD_JOB_NAME}-sshd-github";
      tags = [
        "ingress"
        "traefik.enable=true"
        "traefik.tcp.routers.\${NOMAD_JOB_NAME}-sshd-github.entrypoints=\${NOMAD_META_entrypoint}"
        "traefik.tcp.routers.\${NOMAD_JOB_NAME}-sshd-github.rule=HostSNI(`*`)"
      ];
      port = "ssh";
    };
    user = "0:0";
    driver = "docker";
    kill_signal = "SIGINT";
    kill_timeout = "30s";
    resources.cpu = 2000;
    resources.memory = 2048;
    vault = {
      change_mode = "noop";
      env = true;
      policies = ["sshd-github"];
    };
  };
}
