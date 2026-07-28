# Tramp -- built from a PINNED git revision rather than the dated GNU-devel
# ELPA tarball.
#
# tramp-rpc requires Tramp >= 2.8.1.4, but Emacs 30.2 bundles 2.7.3 and stable
# ELPA is still 2.8.0.x, so we must track the development line.
#
# Why not the devel tarball: its URL (elpa.gnu.org/devel/tramp-<dated>.tar) is
# garbage-collected upstream within weeks.  Once the store copy is GC'd the pin
# 404s and *any* rebuild fails.  A pinned git rev is reproducible and immune to
# that rotation.  Source is the emacsmirror GitHub mirror (savannah is
# frequently unreachable).
#
# Tramp is an autotools project: `configure' fills trampver.el from
# trampver.el.in and `make autoloads' generates tramp-loaddefs.el -- neither is
# committed -- so we generate them before byte-compiling.  `trivialBuild' is
# threaded in from the overrideScope in emacs-package.nix so the package is
# compiled against this config's Emacs.
{
  stdenv,
  fetchFromGitHub,
  autoconf,
  automake,
  texinfo,
  emacs,
  trivialBuild,
}:
let
  rev = "1c54f870e03cf47aed7cf75b7573623606e9e5ff"; # emacsmirror master
  version = "2.8.3-pre-unstable-2026-07-25";
  # Stage 1: generate trampver.el (via configure) and tramp-loaddefs.el (via
  # `make autoloads') from Tramp's own autotools build.
  generated = stdenv.mkDerivation {
    pname = "tramp-generated-lisp";
    inherit version;
    src = fetchFromGitHub {
      owner = "emacsmirror";
      repo = "tramp";
      inherit rev;
      hash = "sha256-HI0Ohvc4XghGu31KHW690cje1UG7JXEPvO83t8/iUQM=";
    };
    nativeBuildInputs = [
      autoconf
      automake
      texinfo
      emacs
    ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      autoreconf -fi
      ./configure EMACS=${emacs}/bin/emacs
      make -C lisp autoloads
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp lisp/*.el $out/
      runHook postInstall
    '';
  };
in
# Stage 2: byte-compile + package the generated lisp tree as an Emacs package.
trivialBuild {
  pname = "tramp";
  inherit version;
  src = generated;
}
