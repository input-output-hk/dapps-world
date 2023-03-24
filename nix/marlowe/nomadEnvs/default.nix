{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge cardano-world nixpkgs bitte-cells cells marlowe-cardano;
  inherit (cells) cloud;

  inherit (cardano-world) cardano;
  inherit (bitte-cells) vector;
  inherit (data-merge) merge append;
  inherit (nixpkgs.lib) genAttrs head splitString concatStringsSep toUpper replaceStrings;

  inherit (marlowe-cardano) nomadTasks;
  inherit (cloud.constants) baseDomain;

  # ports to configure for each task
  servicePorts = [
    "chain_indexer_http"
    "marlowe_chain_sync"
    "marlowe_chain_sync_query"
    "marlowe_chain_sync_command"
    "chain_sync_http"
    "indexer_http"
    "marlowe_sync"
    "marlowe_header_sync"
    "marlowe_query"
    "sync_http"
    "tx"
    "tx_http"
    "proxy"
    "proxy_http"
  ];

  # environments to configure the runtime for
  environments = [
    "preprod"
    "preview"
    "mainnet"
  ];

  taskFromPort = p: head (splitString "_" p);
  formatService = replaceStrings ["_"] ["-"];

  # marlowe namespace is created and configured in dapps-world

  mkRuntimeJob = environment: let
    jobname = "marlowe-runtime-${environment}";

    id = jobname;
    namespace = "marlowe";
    domain = "${jobname}.${baseDomain}";
    scaling = 1;

    datacenters = ["us-east-1" "eu-central-1" "eu-west-1"];
    type = "service";
    priority = 50;

    # Pull out cardano-node task to merge in with rest
    node' =
      (cardano.nomadCharts.cardano-node {
        inherit namespace datacenters domain scaling;
        jobname = "node";
        nodeClass = namespace;
      })
      .job
      .node
      .group
      .cardano;
    group = builtins.removeAttrs node' ["task"];
    node = group // {task.node = node'.task.node;};
  in {
    job.${jobname} =
      (import ./scheduling-config.nix)
      // {
        inherit namespace datacenters id type priority;

        group.main =
          merge
          # task.vector ...
          # https://github.com/input-output-hk/bitte-cells/blob/main/cells/vector/nomadTask.nix
          (vector.nomadTask.default {
            inherit namespace;
            endpoints = [];
          })
          (
            merge node
            {
              network.port =
                (genAttrs servicePorts (n: {}))
                // {ssh.to = 22;};
              # Setup a service for each port, so that the sshd task can reference them
              service = append (map (port: {
                  inherit port;
                  name = "\${JOB}-\${TASKGROUP}-${formatService port}";
                  task = taskFromPort port;
                })
                servicePorts);
              meta = {
                inherit environment;
              };
              task = {
                node = {
                  lifecycle.sidecar = true;
                  env = {
                    ENVIRONMENT = environment;
                    DATA_DIR = "/persist/${jobname}";
                    LOCAL_ROOTS_SRV_DNS = "_${jobname}-node._tcp.service.consul";
                    PUBLIC_ROOTS_SRV_DNS = "_${environment}-node._tcp.service.consul";
                  };
                  resources = {
                    cpu = 4000;
                    memory = 8192;
                  };
                };
                inherit
                  (nomadTasks)
                  marlowe-chain-indexer
                  marlowe-chain-sync
                  marlowe-indexer
                  marlowe-sync
                  marlowe-tx
                  marlowe-proxy
                  ;
              };
            }
          );
      };
  };
in {
  marlowe = {
    marlowe-runtime-preprod = mkRuntimeJob "preprod";
    marlowe-runtime-preview = mkRuntimeJob "preview";
    marlowe-runtime-mainnet = mkRuntimeJob "mainnet";
    sshd-github.job.sshd-github = {
      id = "sshd-github";
      namespace = "marlowe";
      datacenters = ["us-east-1" "eu-central-1" "eu-west-1"];
      type = "service";
      priority = 50;

      group.sshd-github = {
        network.port.ssh.to = 22;
        task.sshd-github = merge cloud.nomadTasks.sshd-github {
          meta = {
            github_teams = "marlowe marlowe-admin";
            entrypoint = "ssh-marlowe";
            extra_keys = ''
              # marlowe-cardano Github Actions
              ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKVEWw43E1Uvc8JT89EX8PD5uCQoJfbDn+A6PEmUfaT marlowebuild@iohk.io
            '';
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
                                  | regexReplaceAll "marlowe-runtime-(.*)-main-(.*)" "$1"
                                  | toUpper
                -}}
                {{-
                  $portname := .Name
                               | regexReplaceAll "marlowe-runtime-(.*)-main-(.*)" "$2"
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
