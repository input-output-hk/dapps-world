{
  inputs,
  cell,
}: let
  inherit (inputs) bitte-cells cardano-world cells;
  inherit (cells) marlowe;
  inherit (cardano-world) cardano;
in {
  # Bitte Hydrate Module
  # -----------------------------------------------------------------------

  default = {
    lib,
    bittelib,
    config,
    ...
  }: {
    imports = [
      (bitte-cells.patroni.hydrationProfiles.hydrate-cluster ["infra"])
      (bitte-cells.tempo.hydrationProfiles.hydrate-cluster ["infra"])
      cardano.hydrationProfiles.workload-policies-cardano
      cardano.hydrationProfiles.workload-policies-db-sync
      marlowe.hydrationProfiles.workload-policies-marlowe-runtime
    ];

    # NixOS-level hydration
    # --------------

    cluster = {
      name = "dapps-world";

      adminNames = ["parthiv.seetharaman"];
      adminGithubTeamNames = lib.mkForce ["devops" "plutus-devops"];
      developerGithubTeamNames = ["marlowe" "plutus-core" "plutus-tools"];
      domain = "dapps.aws.iohkdev.io";
      kms = "arn:aws:kms:us-east-1:677160962006:key/e8ccc1e3-c590-42f9-bda3-f7a55dcd787c";
      s3Bucket = "iohk-dapps-world";
      s3Tempo = "iohk-dapps-world-tempo";
    };

    services = {
      nomad.namespaces = {
        infra = {description = "Common services";};
        marlowe = {description = "marlowe services";};
        plutus = {description = "plutus services";};
      };
    };

    # cluster level (terraform)
    # --------------
    tf.hydrate-cluster.configuration = {
      locals.policies = {
        vault = let
          c = "create";
          r = "read";
          u = "update";
          d = "delete";
          l = "list";
          s = "sudo";
          caps = lib.mapAttrs (n: v: {capabilities = v;});
        in {
          developer.path = {
            "kv/data/test/*".capabilities = [c r u d l];
            "kv/metadata/*".capabilities = [l];
          };

          admin.path = caps {
            "secret/*" = [c r u d l];
            "auth/github-terraform/map/users/*" = [c r u d l s];
            "auth/github-employees/map/users/*" = [c r u d l s];
          };

          terraform.path = caps {
            "secret/data/vbk/*" = [c r u d l];
            "secret/metadata/vbk/*" = [d];
          };

          vit-terraform.path = caps {
            "secret/data/vbk/vit-testnet/*" = [c r u d l];
            "secret/metadata/vbk/vit-testnet/*" = [c r u d l];
          };
          sshd-github.path = caps {
            "kv/data/sshd-github/*" = [r l];
          };
        };

        consul = {
          developer = {
            service_prefix."*" = {
              policy = "write";
            };
            key_prefix."test" = {
              policy = "write";
            };
          };
        };

        nomad = {
          admin = {
            description = "Admin policies";
            namespace."*" = {
              policy = "write";
              capabilities = [
                "alloc-exec"
                "alloc-lifecycle"
                "alloc-node-exec"
                "csi-list-volume"
                "csi-mount-volume"
                "csi-read-volume"
                "csi-register-plugin"
                "csi-write-volume"
                "dispatch-job"
                "list-jobs"
                "list-scaling-policies"
                "read-fs"
                "read-job"
                "read-job-scaling"
                "read-logs"
                "read-scaling-policy"
                "scale-job"
                "submit-job"
              ];
            };
          };

          developer = {
            description = "Dev policies";
            namespace."*".policy = "deny";
            agent.policy = "read";
            quota.policy = "read";
            node.policy = "read";
            host_volume."*".policy = "write";
            namespace."marlowe" = {
              policy = "write";
              capabilities = [
                "submit-job"
                "dispatch-job"
                "read-logs"
                "alloc-exec"
                "alloc-node-exec"
                "alloc-lifecycle"
              ];
            };
          };
        };
      };
    };

    # Observability State
    # --------------
    tf.hydrate-monitoring.configuration = {
      resource =
        inputs.bitte-cells._utils.library.mkMonitoring
        # Alert attrset
        {
          # Organelle local declared dashboards
          # inherit
          #   (cell.alerts)
          # ;

          # Upstream alerts not having downstream deps can be directly imported here
          inherit
            (inputs.bitte-cells.bitte.alerts)
            bitte-consul
            bitte-deadmanssnitch
            bitte-loki
            bitte-system
            bitte-vault
            bitte-vm-health
            bitte-vm-standalone
            bitte-vmagent
            ;

          inherit
            (inputs.bitte-cells.patroni.alerts)
            bitte-cells-patroni
            ;

          inherit
            (inputs.bitte-cells.tempo.alerts)
            bitte-cells-tempo
            ;
        }
        # Dashboard attrset
        {
          # Organelle local declared dashboards
          # inherit
          #   (cell.dashboards)
          #   ;

          # Upstream dashboards not having downstream deps can be directly imported here
          inherit
            (inputs.bitte-cells.bitte.dashboards)
            bitte-consul
            bitte-log
            bitte-loki
            bitte-nomad
            bitte-system
            bitte-traefik
            bitte-vault
            bitte-vmagent
            bitte-vmalert
            bitte-vm
            bitte-vulnix
            ;

          inherit
            (inputs.bitte-cells.patroni.dashboards)
            bitte-cells-patroni
            ;

          inherit
            (inputs.bitte-cells.tempo.dashboards)
            bitte-cells-tempo-operational
            bitte-cells-tempo-reads
            bitte-cells-tempo-writes
            ;
        };
    };

    # application state (terraform)
    tf.hydrate-app.configuration = let
      vault' = {
        dir = ./. + "/kv/vault";
        prefix = "kv";
      };
      # consul' = {
      #   dir = ./. + "/kv/consul";
      #   prefix = "config";
      # };
      vault = bittelib.mkVaultResources {inherit (vault') dir prefix;};
      # consul = bittelib.mkConsulResources {inherit (consul') dir prefix;};
    in {
      data = {inherit (vault) sops_file;};
      resource = {
        inherit (vault) vault_generic_secret;
        # inherit (consul) consul_keys;
      };
    };
  };
}
