# daisyui-blueprint-nix

[daisyUI Blueprint](https://daisyui.com/blueprint/) MCP server packaged for
Nix. The upstream product is commercial and distributed only as an obfuscated
bundle on the npm registry (no source repository), so this repo packages the
official npm tarball with a [bun](https://bun.sh) wrapper — no `npx`/`bunx`
resolution at runtime.

Since 1.6.1 the bundle no longer vendors its npm dependencies: it imports
`@modelcontextprotocol/server` and `zod` as external modules at runtime.
Those are vendored into the package's `node_modules` at build time with
[bun2nix](https://github.com/nix-community/bun2nix) — `deps/bun.lock` pins
the tarball's runtime dependency set, `deps/bun.nix` is generated from it,
and the build's `bun install` runs fully offline. (Without this, bun
auto-installs the SDK into its global cache at runtime, where the SDK's
self-referencing `@modelcontextprotocol/server/_shims` import races during
the server's parallel chunk loading and crashes the server at startup.)

The packaging follows the
[natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)
conventions (`pkgs/official/*` style, `nix-update-script` passthru) so the
expression could be upstreamed largely verbatim.

## Updates

A scheduled GitHub Actions workflow checks the npm registry daily, bumps
`package.nix` via `nix-update`, refreshes `deps/` (see below), verifies the
package builds, and commits to `main`. Downstream consumers get new releases
with a plain `nix flake update` — no manual version bookkeeping.

### Refreshing deps/ after a version bump

`deps/` mirrors the tarball's runtime `dependencies` as a locked, nix-fetchable
tree. After bumping `version` in `package.nix`:

```sh
# 1. Point deps/package.json at the new tarball's runtime dependency set
#    (name/version must match the tarball's package.json; runtime deps only,
#    devDependencies are intentionally excluded).
npm view daisyui-blueprint@<version> dependencies --json   # inspect

# 2. Regenerate the lockfile and the nix dependency expression
cd deps && bun install && cd ..
nix run github:nix-community/bun2nix -- -l deps/bun.lock -o deps/bun.nix

# 3. Verify
nix build .#daisyui-blueprint
```

If a future release bundles its dependencies again (as ≤1.5.x did), emptying
`deps/package.json`'s `dependencies` and re-running the steps above restores
a dependency-free package.

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
