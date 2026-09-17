# envrc -- built from a PINNED git revision rather than the overlay's MELPA
# snapshot.
#
# The pinned emacs-overlay ships envrc 20260209.1350, which predates
# `envrc-async' (added August 2026).  Without it every direnv run blocks
# Emacs, so a `use flake' project whose flake changed stalls the editor for a
# full nix-direnv re-evaluation; lisp/envrc-config.el relies on the timeout
# that variable provides.  The rev is one commit past the 0.14 tag: the
# follow-up that forces nested envrc-mode invocations async so a blocking wait
# cannot deadlock.  Drop this file once the overlay's snapshot is at or past
# that rev.
{
  fetchFromGitHub,
  trivialBuild,
  inheritenv,
}:
trivialBuild {
  pname = "envrc";
  version = "0.14-unstable-2026-09-05";
  src = fetchFromGitHub {
    owner = "purcell";
    repo = "envrc";
    rev = "55a69ae6325c06fdde9a94b55c8f3dbc901686ff";
    hash = "sha256-EnUNJZ8ywm4xqSCMTadsLKCSBEf7GDvhAz4AZ2iKfDs=";
  };
  # envrc requires inheritenv at load time; the overlay's copy is current.
  packageRequires = [ inheritenv ];
}
