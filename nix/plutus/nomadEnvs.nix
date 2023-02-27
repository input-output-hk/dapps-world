{
  inputs,
  cell,
}: let
  inherit (inputs.cells.cloud) constants nomadTasks;
  inherit (inputs.data-merge) append merge update;
  inherit (inputs.cardano-world) cardano;
in {
  plutus = {
    core-sshd-github.job.sshd-github = {
      id = "sshd-github";
      namespace = "plutus";
      datacenters = ["us-east-1" "eu-central-1" "eu-west-1"];
      type = "service";
      priority = 50;

      constraint = [
        {
          attribute = "\${node.class}";
          operator = "=";
          value = "plutus-benchmark";
        }
      ];
      group.sshd-github = {
        volume.plutus-persist-ssh = {
          type = "host";
          source = "plutus-persist-ssh";
        };
        count = 1;
        network.port.ssh.to = 22;
        task.sshd-github = merge nomadTasks.sshd-github {
          resources = {
            cpu = 15000;
            memory = 60000;
          };
          meta = {
            github_teams = "plutus-core plutus-tools";
            entrypoint = "ssh-plutus";
          };
        };
      };
    };
    djed-node.job.djed-node = let
      namespace = "plutus";
      datacenters = ["us-east-1" "eu-central-1" "eu-west-1"];
      scaling = 1;
      domain = "djed-node.${constants.baseDomain}";

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
      inherit namespace datacenters;
      id = "djed-node";
      type = "service";
      priority = 50;

      constraint = [
        {
          attribute = "\${node.class}";
          operator = "=";
          value = "plutus-djed";
        }
      ];
      group.djed-node = merge node {
        count = 1;
        network.port.ssh.to = 22;
        task = {
          node = {
            env = {
              ENVIRONMENT = "preprod";
              DATA_DIR = "/persist/plutus-djed-node";
              LOCAL_ROOTS_SRV_DNS = "_plutus-djed-preprod-node._tcp.service.consul";
              PUBLIC_ROOTS_SRV_DNS = "_preprod-node._tcp.service.consul";
            };
          };
          sshd-github = merge nomadTasks.sshd-github {
            meta = {
              github_teams = "djed-plutus";
              entrypoint = "ssh-djed-plutus";
            };
          };
        };
      };
    };
  };
}
