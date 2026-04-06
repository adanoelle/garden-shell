# modules/dendritic.nix — den bootstrap (namespace provider, no hosts)
{ inputs, ... }:
{
  imports = [
    (inputs.den.flakeModule or inputs.den.flakeModules.den)
  ];
}
