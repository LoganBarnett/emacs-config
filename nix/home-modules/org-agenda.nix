################################################################################
# Declares the org-agenda file list that lisp/nix-org-agenda-config.el reads.
#
# The declaration is written to ~/.config/emacs/nix-org-agenda.json and
# replaces `org-agenda-files` at startup.  Producers of generated agenda
# files, such as ../darwin-modules/org-agenda-ics-calendars.nix, append to
# `files` rather than touching the file themselves.
################################################################################
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkIf
    mkOption
    types
    ;
  cfg = config.programs.emacs.org-agenda;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.emacs.org-agenda = {
    directories = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example =
        literalExpression ''[ "/Users/me/notes" "/Users/me/work-notes" ]'';
      description = ''
        Absolute directories Emacs walks recursively at startup.  Every `.org`
        file under them joins `org-agenda-files`, minus `excludes`.
      '';
    };
    excludes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''[ "_archive\\.org\\'" "journal/" ]'';
      description = ''
        Emacs regexps.  A file found under `directories` whose absolute path
        matches any of them is left out.
      '';
    };
    files = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example =
        literalExpression ''[ "/Users/me/notes/agenda/generated/work.org" ]'';
      description = ''
        Absolute paths added to `org-agenda-files` as they are, such as
        generated files.  Emacs skips any that do not exist yet, with a
        warning.
      '';
    };
  };

  config = mkIf (cfg.files != [ ] || cfg.directories != [ ]) {
    home.file.".config/emacs/nix-org-agenda.json".source =
      jsonFormat.generate "nix-org-agenda.json" {
        org-agenda-directories = cfg.directories;
        org-agenda-excludes = cfg.excludes;
        org-agenda-files = cfg.files;
      };
  };
}
