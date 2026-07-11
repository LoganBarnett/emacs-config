{ ... }: {
  programs.ssh = {

    matchBlocks = {
      # Global defaults for all hosts.
      "*" = {
        # For Emacs.  Reuse a single, warm, *persistent* master connection for
        # all ssh — and for Tramp, which now defers to this config (see
        # tramp-use-ssh-controlmaster-options in org/tramp.org).  Without a
        # controlPath, controlMaster=auto is a silent no-op: there is no socket
        # to multiplex over, so every connection pays a full handshake.
        #
        # %C is a hash of {host,port,user,laddr}, which keeps the socket path
        # short enough for macOS's ~104-char unix-socket limit (a literal
        # %h-%p-%r path can overflow it for longer FQDNs).
        controlMaster = "auto";
        controlPath = "~/.ssh/control-%C";
        controlPersist = "10m";
        # Send keepalive packets to prevent the ssh host or
        # firewall/loadbalancer itself from dropping connections.
        serverAliveInterval = 50;
      };

    };

  };
}
