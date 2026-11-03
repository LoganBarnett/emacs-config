{
  description = "Logan's Emacs configuration";

  inputs = {
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    hyuqueue = {
      url = "github:LoganBarnett/hyuqueue";
    };
    org-dnd = {
      url = "github:LoganBarnett/org-dnd";
      flake = false;
    };
    # Personal fork of org-mode carrying a fix to org-lint that avoids
    # side-effecting includes via find-file-noselect.  Override in
    # nix-config-private to point at the gitea mirror for local deploys.
    # When the fix lands upstream, drop this input and the overrideAttrs
    # in emacs-package.nix.
    org-mode-fork = {
      url = "github:LoganBarnett/org-mode/org-lint-include-no-side-effects";
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
    # rust-template provides review-cli: an on-demand code review that judges
    # the working tree against this repo's README.org / CONTRIBUTING.org /
    # llms.org conventions via a nested headless `claude` run.  Only its
    # `review-cli` package is consumed, in the devShell.  Both flakes track
    # nixos-25.11, so following nixpkgs is safe and avoids a second nixpkgs.
    rust-template = {
      url = "github:LoganBarnett/rust-template";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Only name inputs here that we explicitly use in the code below.  Everything
  # else is expected to be bundled up and offered via `emacs-flake-inputs`,
  # which will enter the dependency injection for modules.
  # The `emacs-flake-inputs` naming is to avoid collisions when consumed via
  # other flakes (after all, there's only one dependency injection layer).
  outputs = emacs-flake-inputs@{
    self,
    emacs-overlay,
    emacs-tramp-rpc,
    nixpkgs,
    rust-template,
    ...
  }:
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

      # The org-agenda file list, declared per user under
      # programs.emacs.org-agenda and read by lisp/nix-org-agenda-config.el.
      # Importing this module as a value here and by path from the ICS module
      # below would declare its options twice.  So it is exported as the path,
      # not an `import`.
      homeModules.org-agenda = ./nix/home-modules/org-agenda.nix;
      # ICS calendar feeds synced into org files for the agenda.  The host is
      # assumed to run agenix-rekey and home-manager.
      darwinModules.org-agenda-ics-calendars =
        ./nix/darwin-modules/org-agenda-ics-calendars.nix;

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

      # `nix flake check` evaluates the agenda home module against a fixture
      # and compares the JSON it writes.  home-manager is not an input here,
      # so the one home-manager option the module sets is stubbed.
      checks = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          inherit (pkgs) lib;
          homeFileStub = { lib, ... }: {
            options.home.file = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options.source = lib.mkOption { type = lib.types.path; };
              });
              default = { };
            };
          };
          fixture = {
            directories = [ "/home/me/notes" "/home/me/work-notes" ];
            excludes = [ "_archive\\.org\\'" "journal/" ];
            files = [ "/home/me/generated/cal.org" ];
          };
          declaration = (lib.evalModules {
            modules = [
              homeFileStub
              ./nix/home-modules/org-agenda.nix
              {
                _module.args.pkgs = pkgs;
                programs.emacs.org-agenda = fixture;
              }
            ];
          }).config.home.file.".config/emacs/nix-org-agenda.json".source;
          expected = pkgs.writeText "expected-nix-org-agenda.json"
            (builtins.toJSON {
              org-agenda-directories = fixture.directories;
              org-agenda-excludes = fixture.excludes;
              org-agenda-files = fixture.files;
            });
        in
        {
          org-agenda-declaration = pkgs.runCommand "org-agenda-declaration"
            { nativeBuildInputs = [ pkgs.jq ]; } ''
              diff <(jq --sort-keys . ${expected}) \
                <(jq --sort-keys . ${declaration})
              touch "$out"
            '';
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
              # On-demand code review of the working tree.  Run via
              # `just review`; needs `claude` on PATH (it is not added here).
              rust-template.packages.${system}.review-cli
            ] ++ darwinPackages;
          };
        }
      );
    };
}
