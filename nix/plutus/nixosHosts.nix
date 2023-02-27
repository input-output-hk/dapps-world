{
  inputs,
  cell,
}: {
  inherit inputs;
  benchmark = inputs.nixos.lib.nixosSystem {
    modules = [
      cell.nixosProfiles.benchmark
    ];
  };
}
