# modules/devshell.nix — development shell
{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }:
    let
      rustPkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          (rustPkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
          })
          nixpkgs-fmt
          just
          cargo-watch
          mdbook
        ];

        shellHook = ''
          export GARDEN_THEMES_BIN="$PWD/target/debug/garden-themes"
        '';
      };
    };
}
