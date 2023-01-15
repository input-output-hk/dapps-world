{ inputs, cell }:
let
  inherit (inputs) std;
  inherit (cell) operables;

  mkImage = name: std.lib.ops.mkStandardOCI {
    name = "registry.ci.iog.io/dapps-world-${name}";
    operable = operables.${name};
    debug = true;
  };

in {
  sshd-github = mkImage "sshd-github";
}
