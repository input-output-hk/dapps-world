{
  inputs,
  cell,
}: let
in rec {
  # Metadata
  # -----------------------------------------------------------------------
  baseDomain = "dapps.aws.iohkdev.io";

  # App Component Import Parameterization
  # -----------------------------------------------------------------------
  namespaces = {
    infra = {
      namespace = "infra";
      domain = "${baseDomain}";
      nodeClass = "infra";
      datacenters = ["us-east-1" "eu-central-1"];
    };
  };

  patroni = let
    inherit (namespaces.infra) namespace;
  in rec {
    # App constants
    WALG_S3_PREFIX = "s3://iohk-dapps-world/backups/${namespace}/walg";

    # Job mod constants
    patroniMods.scaling = 3;
    patroniMods.resources.cpu = 2000;
    patroniMods.resources.memory = 2 * 1024;
  };

  tempo = let
    inherit (namespaces.tempo) namespace;
  in rec {
    # Job mod constants
    tempoMods.scaling = 1;
    tempoMods.resources.cpu = 2000;
    tempoMods.resources.memory = 2 * 1024;
    tempoMods.storageS3Bucket = "iohk-dapps-world-tempo";
    tempoMods.storageS3Endpoint = "s3.eu-central-1.amazonaws.com";
  };
}
