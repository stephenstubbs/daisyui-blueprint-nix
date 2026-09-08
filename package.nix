# daisyUI Blueprint MCP server, packaged from the official npm registry
# tarball. Follows the natsukium/mcp-servers-nix packaging conventions
# (pkgs/official/*) so this expression can be lifted into that repo largely
# verbatim if it ever grows a home for commercial servers.
#
# daisyui-blueprint is a commercial product distributed ONLY as an obfuscated
# npm bundle — there is no source repository to build from. A LICENSE/EMAIL
# env pair is required at runtime (not at build).
#
# Since 1.6.1 the obfuscated build no longer bundles its npm dependencies:
# the chunks import `@modelcontextprotocol/server` (+ `/stdio`) and `zod` as
# EXTERNAL modules. Without a node_modules tree beside server.js, bun falls
# back to auto-installing into the global cache (~/.bun/install/cache) at
# runtime, where resolving the SDK's self-referencing
# `@modelcontextprotocol/server/_shims` import races under the server's
# parallel chunk loading and fails ~always (single-shot imports race ~50%).
# The dependency tree is therefore vendored at build time via bun2nix:
# deps/bun.lock pins the tarball's runtime deps, deps/bun.nix is generated
# from it (`bun2nix -l deps/bun.lock -o deps/bun.nix`), fetchBunDeps turns it
# into per-package derivations, and the build's `bun install` runs fully
# offline. On a version bump, refresh deps/ to match the new tarball's
# package.json dependencies (see README).
#
# The plain setup hook is used rather than bun2nix.mkDerivation: the latter
# constructs the derivation with bun2nix's OWN nixpkgs (no allowUnfree), so
# this package's unfree license would be rejected there. Building under this
# flake's pkgs keeps the license metadata intact and honoured.
{
  lib,
  stdenv,
  fetchurl,
  bun,
  makeBinaryWrapper,
  nix-update-script,
  jq,
  bun2nix,
}:

let
  # Per-package derivations assembled as a bun global-cache tree
  # (share/bun-cache) from the committed deps/bun.nix.
  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./deps/bun.nix;
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "daisyui-blueprint";
  version = "1.6.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/daisyui-blueprint/-/daisyui-blueprint-${finalAttrs.version}.tgz";
    hash = "sha256-c43nbBgXovcslsU2Gst4ZIY3qZBHKcEKAQa3s+NKph4=";
  };

  inherit bunDeps;

  nativeBuildInputs = [
    bun2nix.hook
    makeBinaryWrapper
    jq
  ];

  # The tarball ships no lockfile; supply the committed one and drop the
  # devDependencies it doesn't cover so the offline install resolves.
  postPatch = ''
    cp ${./deps/bun.lock} bun.lock
    jq 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  # `--linker=hoisted` produces a flat, self-contained node_modules of real
  # files (no isolated-store symlink farm) that copies cleanly into $out.
  bunInstallFlags = [
    "--linker=hoisted"
    "--no-progress"
    "--frozen-lockfile"
  ];

  # The bun2nix hook seeds `$BUN_INSTALL_CACHE_DIR` with `cp -r` from the Nix
  # store, which keeps each cache entry as a symlink INTO the read-only
  # store; bun's cache-to-node_modules copy can then fail with
  # `PermissionDenied` (bun2nix#73). Rebuild the cache as a real writable
  # tree so the install phase materialises every package on every arch.
  postBunSetInstallCacheDirPhase = ''
    cache_tmp="$BUN_INSTALL_CACHE_DIR"
    BUN_INSTALL_CACHE_DIR=$(mktemp -d)
    export BUN_INSTALL_CACHE_DIR
    cp -rL "$cache_tmp"/. "$BUN_INSTALL_CACHE_DIR"
    chmod -R u+rwx "$BUN_INSTALL_CACHE_DIR"
  '';

  # No lifecycle scripts (none in the tarball), no `bun build`/`bun test` —
  # the obfuscated bundle ships prebuilt. The hook's bunInstallPhase would
  # install a compiled binary that doesn't exist; install manually below.
  dontRunLifecycleScripts = true;
  dontUseBunBuild = true;
  dontUseBunCheck = true;
  dontUseBunInstall = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/daisyui-blueprint
    cp -r server.js chunks package.json README.md LICENSE.md $out/lib/daisyui-blueprint/
    # -L: dereference any remaining symlink (e.g. node_modules/.bin) so the
    # shipped tree carries real files.
    cp -rL node_modules $out/lib/daisyui-blueprint/node_modules

    makeBinaryWrapper ${lib.getExe bun} $out/bin/daisyui-blueprint \
      --add-flags "$out/lib/daisyui-blueprint/server.js"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "MCP server for daisyUI component snippets, conversion prompts, and Figma integration";
    homepage = "https://daisyui.com/blueprint/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    mainProgram = "daisyui-blueprint";
    platforms = lib.platforms.all;
  };
})
