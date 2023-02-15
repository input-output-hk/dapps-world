{
  inputs,
  cell,
}: let
  inherit (inputs.bitte-cells) patroni cardano rabbit;
  inherit (inputs) nixpkgs;
in {
  default = {
    self,
    lib,
    pkgs,
    config,
    terralib,
    bittelib,
    ...
  }: let
    inherit (self.inputs) bitte;
    inherit (config) cluster;
    sr = {
      inherit
        (bittelib.securityGroupRules config)
        internet
        internal
        ssh
        http
        https
        routing
        ;
    };
  in {
    secrets.encryptedRoot = ./encrypted;

    nix = {
      binaryCaches = ["https://hydra.iohk.io"];
      binaryCachePublicKeys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    };
    cluster = {
      s3CachePubKey = lib.fileContents ./encrypted/nix-public-key-file;
      flakePath = "${inputs.self}";
      vbkBackend = "local";

      autoscalingGroups = let
        defaultModules = [(bitte + "/profiles/client.nix")];

        eachRegion = attrs: [
          (attrs // {region = "us-east-1";})
          (attrs // {region = "eu-central-1";})
          (attrs // {region = "eu-west-1";})
        ];
      in
        lib.listToAttrs
        (
          lib.forEach (
            (
              eachRegion
              # Infra Nodes
              {
                instanceType = "t3.2xlarge";
                desiredCapacity = 2;
                volumeSize = 1500;
                modules =
                  defaultModules
                  ++ [
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["infra-persist-cardano-node-local"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["infra-persist-db-sync-local"]
                      (n: "/mnt/gv0/${n}")
                    )
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["infra-database"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                    # for scheduling constraints
                    {services.nomad.client.meta.patroni = "yeah";}
                    {services.nomad.client.meta.cardano = "yeah";}
                  ];
                node_class = "infra";
              }
            )
            ++ (
              eachRegion
              # Marlowe NodeClass -- only one node
              {
                region = "us-east-1";
                instanceType = "t3a.2xlarge";
                # desiredCapacity = 1;
                volumeSize = 500;
                modules =
                  defaultModules
                  ++ [
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["marlowe-persist-cardano-node-local"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["marlowe-persist-ssh"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                  ];
                node_class = "marlowe";
              }
            )
            ++ [
              {
                # Need exactly one plutus benchmarking machine
                region = "us-east-1";
                instanceType = "i4i.4xlarge";
                volumeSize = 250;
                modules =
                  defaultModules
                  ++ [
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["plutus-persist-ssh"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                    {
                      virtualisation.docker.extraOptions = "--storage-opt=dm.basesize=50G";
                    }
                  ];
                node_class = "plutus-benchmark";
              }
              {
                region = "us-east-1";
                instanceType = "t3a.micro";
                volumeSize = 250;
                modules =
                  defaultModules
                  ++ [
                    (
                      bittelib.mkNomadHostVolumesConfig
                      ["plutus-persist-cardano-node-local"]
                      (n: "/var/lib/nomad-volumes/${n}")
                    )
                    {
                      virtualisation.docker.extraOptions = "--storage-opt=dm.basesize=50G";
                    }
                  ];
                node_class = "plutus-djed";
              }
            ]
          )
          (args: let
            attrs =
              {
                desiredCapacity = 1;
                instanceType = "t3a.large";
                associatePublicIP = true;
                maxInstanceLifetime = 0;
                iam.role = cluster.iam.roles.client;
                iam.instanceProfile.role = cluster.iam.roles.client;

                securityGroupRules = {inherit (sr) internet internal ssh;};
              }
              // args;
            asgName = "client-${attrs.region}-${
              builtins.replaceStrings [''.''] [''-''] attrs.instanceType
            }-${args.node_class}";
          in
            lib.nameValuePair asgName attrs)
        );

      instances = {
        core-1 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.0.10";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
            (bitte + /profiles/bootstrapper.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        core-2 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.1.10";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        core-3 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.2.10";
          subnet = cluster.vpc.subnets.core-3;
          volumeSize = 100;

          modules = [
            (bitte + /profiles/core.nix)
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };

        monitoring = {
          instanceType = "t3a.xlarge";
          privateIP = "172.16.0.20";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 300;
          securityGroupRules = {inherit (sr) internet internal ssh http https;};
          modules = [
            (bitte + /profiles/monitoring.nix)
            {
              services.loki.configuration.table_manager = {
                retention_deletes_enabled = true;
                retention_period = "28d";
              };
            }
          ];
        };

        routing = let
          tcpEntrypoints = {
            ssh-marlowe = 4022;
            ssh-plutus = 5022;
            ssh-plutus-djed = 6022;
          };
        in {
          instanceType = "t3a.small";
          privateIP = "172.16.1.20";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 30;
          securityGroupRules =
            {
              inherit (sr) internet internal ssh http https routing;
            }
            // lib.mapAttrs (n: port: {
              inherit port;
              cidrs = ["0.0.0.0/0"];
            })
            tcpEntrypoints;

          route53.domains = [
            cluster.domain
            "*.${cluster.domain}"
            "consul.${cluster.domain}"
            "docker.${cluster.domain}"
            "monitoring.${cluster.domain}"
            "nomad.${cluster.domain}"
            "vault.${cluster.domain}"
          ];

          modules = [
            (bitte + /profiles/routing.nix)
            {
              services.oauth2_proxy.email.domains = ["iohk.io" "atixlabs.com"];
              services.traefik.acmeDnsCertMgr = false;
              services.traefik.useVaultBackend = true;
              services.traefik.staticConfigOptions.entryPoints =
                lib.mapAttrs (_: port: {
                  address = ":${toString port}";
                })
                tcpEntrypoints;
            }
          ];
        };

        runtime-demo = {
          instanceType = "t3a.small";
          privateIP = "172.16.0.30";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 1500;

          modules = [
            (bitte + /profiles/common.nix)
            {
              virtualisation.docker.enable = true;
            }
          ];

          securityGroupRules = {inherit (sr) internet internal ssh;};
        };
      };
    };
  };
}
