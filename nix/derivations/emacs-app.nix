{ lib, writeShellScriptBin }:

# Wrapper that opens the GUI Emacs.app on macOS via `open -a Emacs`.
# Any file/URL arguments are forwarded to the open command.
(writeShellScriptBin "emacs-app" ''
  exec /usr/bin/open -a Emacs "$@"
'').overrideAttrs (_: {
  meta = {
    description = "Open Emacs.app (GUI Emacs) on macOS via the open command";
    platforms = lib.platforms.darwin;
  };
})
