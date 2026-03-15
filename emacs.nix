# The ultimate editor.
# NixOS / nix-darwin module.  The Emacs derivation itself lives in
# emacs-package.nix so it can also be built directly via `nix build .#default`.
{ lib, pkgs, ... }: {
  environment.systemPackages = [
    # For ob-dsq support.
    pkgs.dsq
    (pkgs.callPackage ./emacs-package.nix {})
  ] ++ [(
    if pkgs.stdenv.isDarwin
    then pkgs.pinentry_mac
    else pkgs.pinentry
  )];
}
