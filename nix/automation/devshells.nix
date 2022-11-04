{
  inputs,
  cell,
}: let
  inherit (inputs) capsules bitte-cells bitte deploy-rs nixpkgs;
  inherit (inputs.std) std;
  inherit (inputs.std.lib) dev;

  # FIXME: this is a work around just to get access
  # to 'awsAutoScalingGroups'
  # TODO: std ize bitte properly to make this interface nicer
  dapps-world' = inputs.bitte.lib.mkBitteStack {
    inherit inputs;
    inherit (inputs) self;
    domain = "dapps.aws.iohkdev.io";
    bitteProfile = inputs.cells.metal.bitteProfile.default;
    hydrationProfile = inputs.cells.cloud.hydrationProfile.default;
    deploySshKey = "not-a-key";
  };

  dappsWorld = {
    extraModulesPath,
    pkgs,
    ...
  }: {
    name = nixpkgs.lib.mkForce "Dapps World";
    imports = [
      std.devshellProfiles.default
      bitte.devshellModule
    ];
    bitte = {
      domain = "dapps.aws.iohkdev.io";
      cluster = "dapps-world";
      namespace = "testnet";
      provider = "AWS";
      cert = null;
      aws_profile = "dapps-world";
      aws_region = "us-east-1";
      aws_autoscaling_groups =
        dapps-world'.clusters.dapps-world._proto.config.cluster.awsAutoScalingGroups;
    };
  };
in {
  dev = dev.mkShell {
    imports = [
      dappsWorld
      capsules.base
      capsules.cloud
    ];
  };
  ops = dev.mkShell {
    imports = [
      dappsWorld
      capsules.base
      capsules.cloud
      capsules.hooks
      capsules.metal
      capsules.integrations
      capsules.tools
      bitte-cells.patroni.devshellProfiles.default
    ];
    commands = let
      withCategory = category: attrset: attrset // {inherit category;};
      dappsWorld = withCategory "dapps-world";
    in
      with nixpkgs; [
        (dappsWorld {package = deploy-rs.defaultPackage;})
        (dappsWorld {package = httpie;})
      ];
  };
}
