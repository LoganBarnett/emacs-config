{
  description = "Logan's Emacs configuration";

  inputs = {
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/25.11";
    hyuqueue = {
      url = "git+ssh://git@gitea.proton:2222/logan/hyuqueue";
    };
    org-dnd = {
      url = "git+ssh://git@gitea.proton:2222/logan/org-dnd";
      flake = false;
    };
    # Personal fork of org-mode carrying a fix to org-lint that avoids
    # side-effecting includes via find-file-noselect.  Override in
    # nix-config-private to point at the gitea mirror for local deploys.
    # When the fix lands upstream, drop this input and the overrideAttrs
    # in emacs-package.nix.
    org-mode-fork = {
      url = "github:LoganBarnett/org-mode/fix/org-lint-include-no-side-effects";
      flake = false;
    };
    # tramp-rpc: a Rust + JSON-RPC Tramp backend that services remote file ops
    # over a small server binary instead of Tramp's shell-parse protocol.  Its
    # overlay adds epkgs.tramp-rpc.  It requires Tramp >= 2.8.1.4 but does NOT
    # pin one itself -- that requirement is met by the devel-Tramp overrideScope
    # in emacs-package.nix.
    emacs-tramp-rpc = {
      url = "github:ArthurHeymans/emacs-tramp-rpc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Only name inputs here that we explicitly use in the code below.  Everything
  # else is expected to be bundled up and offered via `emacs-flake-inputs`,
  # which will enter the dependency injection for modules.
  # The `emacs-flake-inputs` naming is to avoid collisions when consumed via
  # other flakes (after all, there's only one dependency injection layer).
  outputs = emacs-flake-inputs@{ self, emacs-overlay, emacs-tramp-rpc, nixpkgs, ... }:
    let
      # Systems supported by this flake.
      supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];

      # Helper function to generate an attribute set for all systems.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for each system with the emacs-overlay applied.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ emacs-overlay.overlays.default emacs-tramp-rpc.overlays.default ];
        }
      );
    in
    {
      # Export the main Emacs configuration as a module that can be imported by
      # hosts.  We apply the emacs-overlay here.
      nixosModules.default = { ... }: {
        imports = [ ./emacs.nix ];
        nixpkgs.overlays = [ emacs-overlay.overlays.default emacs-tramp-rpc.overlays.default ];
        _module.args.emacs-flake-inputs = emacs-flake-inputs;
      };
      darwinModules.default = { ... }: {
        imports = [ ./emacs.nix ];
        nixpkgs.overlays = [ emacs-overlay.overlays.default emacs-tramp-rpc.overlays.default ];
        _module.args.emacs-flake-inputs = emacs-flake-inputs;
      };

      # Export the SSH config module for Emacs.
      nixosModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;
      darwinModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;
      homeModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;

      # Provide emacs-overlay as a passthrough for convenience.
      overlays.default = emacs-overlay.overlays.default;

      # Build the Emacs derivation directly.  Used for `nix build .#default`
      # and by `just build` in CI / iteration loops.
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          configuredEmacs = pkgs.callPackage ./emacs-package.nix {
            inherit emacs-flake-inputs;
          };
        in
        {
          default = configuredEmacs;
          emacs-app = pkgs.callPackage ./nix/derivations/emacs-app.nix {
            emacs = configuredEmacs;
          };
          # The tramp-rpc server binary, exposed so nix-config can install it
          # declaratively on hosts (its darwin.nix / linux-host.nix), rather
          # than the client pushing it over Tramp at runtime.  Pinned to the
          # same emacs-tramp-rpc rev as the client Emacs, so client and server
          # versions stay in lockstep.  Native (non-static) build -- fine for a
          # nix-store-resident binary on the host.
          tramp-rpc-server = pkgs.emacs-tramp-rpc-server;
        }
      );

      # Development shell with the tooling needed to work on this repo.
      # Enter with `nix develop` (or direnv if .envrc is configured).
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          configuredEmacs = pkgs.callPackage ./emacs-package.nix {
            inherit emacs-flake-inputs;
          };
          darwinPackages = if pkgs.stdenv.isDarwin then [
            (pkgs.callPackage ./nix/derivations/emacs-app.nix {
              emacs = configuredEmacs;
            })
          ] else [];
        in
        {
          default = pkgs.mkShell {
            name = "emacs-config-dev";
            packages = [
              pkgs.just
              # Base Emacs for running the lightweight startup / structure tests
              # without requiring the full Nix build.
              pkgs.emacs
            ] ++ darwinPackages;
          };
        }
      );
    };
}
