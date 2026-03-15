{ lib, writeShellScriptBin, emacs }:

# Wrapper that opens the Nix-built Emacs on macOS.
# Prefers the .app bundle in the derivation (for proper macOS GUI integration)
# and falls back to running the binary directly.
(writeShellScriptBin "emacs-app" ''
  app="${emacs}/Applications/Emacs.app"
  if [ -d "$app" ]; then
    exec /usr/bin/open -n "$app" --args "$@"
  else
    exec ${lib.getExe emacs} "$@"
  fi
'').overrideAttrs (_: {
  meta = {
    description = "Open the Nix-built Emacs (GUI) on macOS";
    platforms = lib.platforms.darwin;
  };
})
