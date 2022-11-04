{
  description = "Bitte World";
  inputs = {
    std.url = "github:divnix/std";
    n2c.follows = "std/n2c";
    data-merge.follows = "std/dmerge";
    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte/equinix";
    # bitte.url = "path:/home/jlotoski/work/iohk/bitte-wt/equinix";
    bitte-cells.url = "github:input-output-hk/bitte-cells/token-alert-update";
    # bitte-cells.url = "path:/home/jlotoski/work/iohk/bitte-cells-wt/token-alert-update";
    # --------------------------------------------------------------
    # --- Auxiliary Nixpkgs ----------------------------------------
    # nixpkgs.follows = "bitte/nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs";
    capsules = {
      # Until nixago is implemented, as HEAD currently removes fmt hooks
      url = "github:input-output-hk/devshell-capsules/8dcf0e917848abbe58c58fc5d49069c32cd2f585";

      # To obtain latest available bitte-cli
      inputs.bitte.follows = "bitte";
    };
    nix-inclusive.url = "github:input-output-hk/nix-inclusive";
    nixpkgs-vector.url = "github:NixOS/nixpkgs/30d3d79b7d3607d56546dd2a6b49e156ba0ec634";
    tullia.url = "github:input-output-hk/tullia";
    deploy-rs.url = "github:serokell/deploy-rs";
    # --------------------------------------------------------------
    openziti.url = "github:johnalotoski/openziti-bins";
    # openziti.url = "path:/home/jlotoski/work/johnalotoski/openziti-bins-wt/openziti-bins";
  };

  outputs = inputs: let
    inherit (inputs) bitte;
    inherit (inputs.self.x86_64-linux.cloud) nomadEnvs;
  in
    inputs.std.growOn
    {
      inherit inputs;
      cellsFrom = ./nix;
      # debug = ["cells" "cloud" "nomadEnvs"];
      cellBlocks = with inputs.std.blockTypes; [
        (data "nomadEnvs")
        (data "constants")
        (data "alerts")
        (data "dashboards")
        (nixago "nixago")
        (runnables "entrypoints")
        (functions "bitteProfile")
        (functions "oci-images")
        (functions "library")
        (installables "packages")
        (functions "hydrationProfile")
        (runnables "jobs")
        (devshells "devshells")

        # Tullia
        (inputs.tullia.tasks "pipelines")
        (functions "actions")
      ];
    }
    # soil (TODO: eat up soil)
    (
      let
        system = "x86_64-linux";
        # overlays = [(import ./overlay.nix inputs)];
      in
        bitte.lib.mkBitteStack {
          inherit inputs;
          inherit (inputs) self;
          # inherit overlays;
          domain = "dapps.aws.iohkdev.io";
          bitteProfile = inputs.self.${system}.metal.bitteProfile.default;
          hydrationProfile = inputs.self.${system}.cloud.hydrationProfile.default;
          deploySshKey = "./secrets/ssh-dapps-world";
        }
    )
    {
      patroni = bitte.lib.mkNomadJobs "patroni" nomadEnvs;
      tempo = bitte.lib.mkNomadJobs "tempo" nomadEnvs;
    }
    (inputs.tullia.fromStd {
      actions = inputs.std.harvest inputs.self ["cloud" "actions"];
      tasks = inputs.std.harvest inputs.self ["automation" "pipelines"];
    });
  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = ["https://cache.iog.io"];
    extra-trusted-public-keys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    # post-build-hook = "./upload-to-cache.sh";
    allow-import-from-derivation = "true";
  };
  # --------------------------------------------------------------
}
