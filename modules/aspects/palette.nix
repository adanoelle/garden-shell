# modules/aspects/palette.nix — foundation palette aspect
{ garden, ... }:
{
  garden.palette = {
    homeManager = { config, lib, pkgs, ... }: {
      # Deploy palettes.toml as a mutable copy so `garden-themes apply --name`
      # can write back the updated `active` field.  Only seed if the file
      # does not already exist — this preserves runtime palette selection
      # across `nixos-rebuild switch` / `home-manager switch`.
      #
      # CONTRACT: this path must stay a mutable file, never an HM-managed
      # symlink (e.g. via xdg.configFile). If Home Manager ever manages
      # ~/.config/garden/palettes.toml directly, the `[ ! -f ]` guard below
      # always sees an existing file, the seed becomes a no-op, and runtime
      # palette selection is silently lost on every rebuild. Same contract
      # applies to the settings.json seeding in shell.nix.
      home.activation.gardenPalettes = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "${config.xdg.configHome}/garden/palettes.toml" ]; then
          install -Dm644 ${../../_config/palettes.toml} \
            ${config.xdg.configHome}/garden/palettes.toml
        fi
      '';
    };
  };
}
