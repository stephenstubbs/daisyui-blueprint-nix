# daisyUI Blueprint MCP server, packaged from the official npm registry
# tarball. Follows the natsukium/mcp-servers-nix packaging conventions
# (pkgs/official/*) so this expression can be lifted into that repo largely
# verbatim if it ever grows a home for commercial servers.
#
# daisyui-blueprint is a commercial product distributed ONLY as an obfuscated
# npm bundle — there is no source repository to build from. Its declared npm
# dependencies (@modelcontextprotocol/sdk, zod) are bundled into the
# obfuscated build: server.js runs with no node_modules present (verified
# against 1.4.2), so the package is simply the tarball contents plus a bun
# wrapper. A LICENSE/EMAIL env pair is required at runtime (not at build).
{
  lib,
  stdenvNoCC,
  fetchurl,
  bun,
  makeBinaryWrapper,
  nix-update-script,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "daisyui-blueprint";
  version = "1.5.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/daisyui-blueprint/-/daisyui-blueprint-${finalAttrs.version}.tgz";
    hash = "sha256-7qp4jwJxWaxTTfjhFN+fC5IhWjOpi6EiPryAsQs7srQ=";
  };

  dontBuild = true;

  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/daisyui-blueprint
    cp -r . $out/lib/daisyui-blueprint/

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
