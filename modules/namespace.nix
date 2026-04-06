# modules/namespace.nix — create and export the garden namespace
{ inputs, den, ... }:
{
  imports = [ (inputs.den.namespace "garden" true) ];
  _module.args.__findFile = den.lib.__findFile;
}
