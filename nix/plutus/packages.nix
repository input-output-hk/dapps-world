{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs terranix cells;
  inherit (cells.automation.packages) sync-ssh-keys;
  inherit (terranix.lib) terranixConfiguration;
  inherit (nixpkgs) runCommand;
in {
  tf-benchmark = terranixConfiguration {
    inherit (inputs.nixpkgs) system;
    modules = [cell.terraModules.benchmark];
  };
}
