{
  description = "daisyUI Blueprint MCP server packaged for Nix (npm-only commercial distribution)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            # daisyui-blueprint is a commercial (unfree) distribution.
            config.allowUnfree = true;
          };
        in
        rec {
          daisyui-blueprint = pkgs.callPackage ./package.nix { };
          default = daisyui-blueprint;
        }
      );

      overlays.default = final: _: {
        daisyui-blueprint = final.callPackage ./package.nix { };
      };
    };
}
