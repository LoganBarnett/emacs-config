{
  description = "Logan's Emacs configuration";

  inputs = {
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/25.11";
  };

  outputs = { self, emacs-overlay, nixpkgs }:
    let
      # Systems supported by this flake.
      supportedSystems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];

      # Helper function to generate an attribute set for all systems.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for each system.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ emacs-overlay.overlays.default ];
        }
      );
    in
    {
      # Export the main Emacs configuration as a module that can be imported by
      # hosts.  We apply the emacs-overlay here.
      nixosModules.default = { ... }: {
        imports = [ ./emacs.nix ];
        nixpkgs.overlays = [ emacs-overlay.overlays.default ];
      };
      darwinModules.default = { ... }: {
        imports = [ ./emacs.nix ];
        nixpkgs.overlays = [ emacs-overlay.overlays.default ];
      };

      # Export the SSH config module for Emacs.
      nixosModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;
      darwinModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;
      homeModules.ssh-config-emacs = import ./nix/home-configs/ssh-config-emacs.nix;

      # Provide emacs-overlay as a passthrough for convenience.
      overlays.default = emacs-overlay.overlays.default;

      # Package the Emacs configuration for each system (useful for testing).
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.callPackage ./emacs.nix {
            flake-inputs = { inherit emacs-overlay; };
          };
        }
      );
    };
}
