# daisyui-blueprint-nix

[daisyUI Blueprint](https://daisyui.com/blueprint/) MCP server packaged for
Nix. The upstream product is commercial and distributed only as an obfuscated
bundle on the npm registry (no source repository), so this repo packages the
official npm tarball with a [bun](https://bun.sh) wrapper — no `npx`/`bunx`
resolution at runtime, no node_modules (the bundle vendors its dependencies).

The packaging follows the
[natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)
conventions (`pkgs/official/*` style, `nix-update-script` passthru) so the
expression could be upstreamed largely verbatim.

## Updates

A scheduled GitHub Actions workflow checks the npm registry daily, bumps
`package.nix` via `nix-update`, verifies the package builds, and commits to
`main`. Downstream consumers get new releases with a plain `nix flake update`
— no manual version bookkeeping.

## Usage

```nix
{
  inputs.daisyui-blueprint = {
    url = "github:stephenstubbs/daisyui-blueprint-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then reference `daisyui-blueprint.packages.${system}.default` (or apply
`overlays.default`). The server needs `LICENSE` and `EMAIL` environment
variables at runtime (see the [Blueprint docs](https://daisyui.com/blueprint/));
`FIGMA` is optional.

Note: the server burns ~24s of CPU decoding its obfuscated bundle at startup
before answering `initialize`. If you launch MCP servers per client session,
consider keeping one instance alive behind
[mcp-proxy](https://github.com/sparfenyuk/mcp-proxy) and connecting to it as a
remote (streamable-HTTP) server.

## Licensing

This repository contains packaging expressions only. The daisyUI Blueprint
artifacts are fetched from the official npm registry at build time and remain
subject to their commercial license (`meta.license = unfree`). A valid
license key is required to use the server.
