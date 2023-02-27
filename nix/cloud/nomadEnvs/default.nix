{
  inputs,
  cell,
}: let
  inherit (inputs.data-merge) append merge update;
  inherit (inputs.bitte-cells) patroni tempo vector;
  inherit (inputs.cardano-world) cardano;
  inherit (cell) constants nomadTasks;

  mkDbSyncJob = environment: let
    jobname = "db-sync-${environment}";
  in
    merge (cardano.nomadCharts.cardano-db-sync (
      constants.namespaces.infra
      // {
        datacenters = ["us-east-1" "eu-central-1"];
        inherit jobname;
        scaling = 1;
      }
    )) {
      job.${jobname}.group.db-sync.task = {
        node = {
          # env.ENVIRONMENT = "testnet";
          # env.DEBUG_SLEEP = 6000;
          env = {
            DATA_DIR = "/persist/${jobname}";
            ENVIRONMENT = environment;
            EDGE_NODE = "1";
            USE_SNAPSHOT =
              if environment == "mainnet"
              then "1"
              else "";
          };
        };
        db-sync = {
          # env.ENVIRONMENT = "testnet";
          # env.DEBUG_SLEEP = 6000;
          env = {
            DB_NAME = "${environment}_dbsync";
            USE_SNAPSHOT =
              if environment == "mainnet"
              then "1"
              else "";
            ENVIRONMENT = environment;
            DATA_DIR = "/persist/${jobname}";
            VAULT_KV_PATH = "kv/data/db-sync/${environment}";
            MASTER_REPLICA_SRV_DNS = "_infra-database._master.service.us-east-1.consul";
          };
        };
      };
    };
in {
  infra = {
    database = let
      inherit
        (constants.patroni)
        # App constants
        
        WALG_S3_PREFIX
        # Job mod constants
        
        patroniMods
        ;
    in
      merge (patroni.nomadCharts.default (constants.namespaces.infra // {inherit (patroniMods) scaling;})) {
        job.database.constraint = append [
          {
            operator = "distinct_property";
            attribute = "\${attr.platform.aws.placement.availability-zone}";
          }
        ];
        job.database.group.database.task.patroni.resources = {inherit (patroniMods.resources) cpu memory;};
        job.database.group.database.task.patroni.env = {inherit WALG_S3_PREFIX;};
        job.database.group.database.task.backup-walg.env = {inherit WALG_S3_PREFIX;};
      };

    db-sync-preprod = mkDbSyncJob "preprod";

    db-sync-preview = mkDbSyncJob "preview";

    db-sync-mainnet = merge (mkDbSyncJob "mainnet") {
      job.db-sync-mainnet.group.db-sync.task.node = {
        resources.memory = 8192;
      };
    };

    tempo = let
      inherit
        (constants.tempo)
        # App constants
        
        WALG_S3_PREFIX
        # Job mod constants
        
        tempoMods
        ;
    in
      merge (tempo.nomadCharts.default (constants.namespaces.tempo
        // {
          inherit (tempoMods) scaling;
          extraTempo = {
            services.tempo = {
              inherit (tempoMods) storageS3Bucket storageS3Endpoint;
            };
          };
        })) {
        job.tempo.group.tempo.task.tempo = {
          env = {
            # DEBUG_SLEEP = 3600;
            # LOG_LEVEL = "debug";
          };
          # To use slightly less resources than the tempo default:
          resources = {inherit (tempoMods.resources) cpu memory;};
        };
      };
  };

  marlowe = {
    sshd-github.job.sshd-github = {
      id = "sshd-github";
      namespace = "marlowe";
      datacenters = ["us-east-1" "eu-central-1" "eu-west-1"];
      type = "service";
      priority = 50;

      group.sshd-github = {
        network.port.ssh.to = 22;
        task.sshd-github = merge nomadTasks.sshd-github {
          meta = {
            github_teams = "marlowe marlowe-admin";
            entrypoint = "ssh-marlowe";
          };
          template = append [
            {
              destination = "/local/network.env";
              change_mode = "noop";
              data = ''
                #!/bin/bash
                {{- range services }}
                {{- if .Name | contains "marlowe-runtime" }}
                {{- range service .Name }}
                {{-
                  $environment := .Name
                                  | regexReplaceAll "marlowe-runtime-(.*)-marlowe-runtime-(.*)" "$1"
                                  | toUpper
                -}}
                {{-
                  $portname := .Name
                               | regexReplaceAll "marlowe-runtime-(.*)-marlowe-runtime-(.*)" "$2"
                               | replaceAll "-" "_"
                               | toUpper
                -}}
                {{ $environment }}_{{$portname}}_IP={{ .Address }}
                {{ $environment }}_{{$portname}}_PORT={{ .Port }}
                {{ end -}}
                {{ end -}}
                {{ end -}}
              '';
            }
          ];
        };
      };
    };
  };

  }
