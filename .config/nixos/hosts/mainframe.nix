{ config, pkgs, ... }:

# mainframe — Ryzen 5 3600X / NVIDIA RTX 2060 SUPER desktop + home server.
# Siblings: Caddyfile, cloudflare-ddns.sh.
# Secret (not in repo): /etc/caddy/cf-token.env -> CF_API_TOKEN=<scoped token>

{
  imports = [ ../common.nix ];

  boot.loader.systemd-boot.configurationLimit = 10;

  # /home is the existing XFS volume on the LVM array — NEVER reformat.
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/228bacf5-dc6b-4364-9dba-1cec2f4737a4";
    fsType = "xfs";
  };
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/c2b9ec8f-4519-46b4-a3f4-d166e5b4a670";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  zramSwap.enable = true;

  networking.hostName = "mainframe";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.openssh.settings.PasswordAuthentication = false;

  # NVIDIA RTX 2060 SUPER (Turing), open kernel module
  hardware.graphics.enable32Bit = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Docker compose stacks live in ~/src/{jellyfin,odysseus}
  virtualisation.docker.enable = true;
  # hardware.nvidia-container-toolkit.enable = true;  # if a container needs the GPU

  services.syncthing = {
    enable = true;
    user = "grish";
    group = "users";
    configDir = "/home/grish/.local/state/syncthing";
  };

  # Reverse proxy + Cloudflare DNS-01 certs. hash must match the plugin build
  # (a mismatch fails the rebuild and prints the correct sha256).
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
    };
    environmentFile = "/etc/caddy/cf-token.env";
    configFile = ./Caddyfile;
  };

  # fossil repo server on 127.0.0.1:8111 (behind Caddy fossil.grish.haus)
  systemd.services.fossil = {
    description = "Fossil repo server (~/src/fossils)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "grish";
      Group = "users";
      ExecStart = "${pkgs.fossil}/bin/fossil server --localhost --port 8111 --repolist /home/grish/src/fossils";
      Restart = "on-failure";
    };
  };

  # DDNS: keep Cloudflare A records on the current (dynamic) public IP
  systemd.services.cloudflare-ddns = {
    description = "Update Cloudflare A records to current public IP";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/caddy/cf-token.env";
      ExecStart = "${pkgs.bash}/bin/bash ${./cloudflare-ddns.sh}";
    };
  };
  systemd.timers.cloudflare-ddns = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "1min"; OnUnitActiveSec = "5min"; Persistent = true; };
  };

  # Nightly /home -> /mnt/backup mirror
  systemd.services.home-backup = {
    description = "rsync /home to /mnt/backup";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.util-linux}/bin/mountpoint -q -- /mnt/backup && \
        ${pkgs.rsync}/bin/rsync -av --delete --delete-excluded --exclude=.cache /home /mnt/backup
    '';
  };
  systemd.timers.home-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:00:00"; Persistent = true; };
  };

  users.users.grish.shell = pkgs.zsh;
  users.users.grish.extraGroups = [ "networkmanager" "docker" ];

  environment.systemPackages = with pkgs; [ docker-compose xcompmgr rtorrent curl ];

  system.stateVersion = "25.05";
}
