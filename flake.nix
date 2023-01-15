{
  description = "Bitte World";
  inputs = {
    std.url = "github:divnix/std";
    n2c.follows = "std/n2c";
    data-merge.follows = "std/dmerge";
    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte";
    bitte-cells.url = "github:input-output-hk/bitte-cells";
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
    # --------------------------------------------------------------
    cardano-world.url = "github:input-output-hk/cardano-world";
    tullia.url = "github:input-output-hk/tullia";
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
        (data "nomadTasks")
        (data "constants")
        (data "alerts")
        (data "dashboards")
        (nixago "nixago")
        (runnables "entrypoints")
        (runnables "operables")
        (functions "bitteProfile")
        (functions "oci-images")
        (functions "library")
        (installables "packages")
        (functions "hydrationProfile")
        (functions "hydrationProfiles")
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
      infra = bitte.lib.mkNomadJobs "infra" nomadEnvs;
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
