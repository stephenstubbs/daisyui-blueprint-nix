{
  description = "daisyUI Blueprint MCP server packaged for Nix (npm-only commercial distribution)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # bun2nix — builds the runtime dependency tree (@modelcontextprotocol/server,
    # zod) offline from the committed deps/bun.nix (generated from deps/bun.lock).
    # Since 1.6.1 the obfuscated bundle imports the MCP SDK as an EXTERNAL
    # module; without a vendored node_modules bun falls back to its global
    # auto-install cache at runtime, which races on the SDK's self-referencing
    # `@modelcontextprotocol/server/_shims` import and fails intermittently.
    bun2nix = {
      url = "github:nix-community/bun2nix/0f2a1f0b6f42cebe3b149bf62d38754c5e0e9729";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, bun2nix }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      # Re-bind the flake input's per-system package so call sites read
      # `bun2nix.fetchBunDeps` / `bun2nix.mkDerivation` (its functions ride on
      # the CLI package's passthru).
      bun2nixFor = system: bun2nix.packages.${system}.default;
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
          daisyui-blueprint = pkgs.callPackage ./package.nix {
            bun2nix = bun2nixFor system;
          };
          default = daisyui-blueprint;
        }
      );

      overlays.default = final: _: {
        daisyui-blueprint = final.callPackage ./package.nix {
          bun2nix = bun2nixFor final.stdenv.hostPlatform.system;
        };
      };
    };
}
