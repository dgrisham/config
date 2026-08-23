{ config, pkgs, ... }:

# mainframe — AMD Ryzen 5 3600X / NVIDIA RTX 2060 SUPER desktop + home server.
# Standalone host config (a common.nix refactor shared with grishpad is a later
# cleanup). Reflects the Arch->NixOS migration done live in Aug 2026:
#   - Caddy + Cloudflare DNS-01 certs (replaced nginx/acme.sh)
#   - fossil server on :8111, jellyfin/docker stacks, cloudflare DDNS
#   - btrfs root (subvols), key-only SSH, NVIDIA, no bluetooth.
#
# Supporting files expected next to this one (copy into /etc/nixos/ at install):
#   Caddyfile, cloudflare-ddns.sh
# Secret (NOT in repo): /etc/caddy/cf-token.env  ->  CF_API_TOKEN=<scoped token>

{
  imports = [
    /etc/nixos/hardware-configuration.nix  # generated at install: btrfs subvols (@,@nix,@varlib), ESP, LVM/XFS /home
  ];

  # --- Bootloader --- fresh 1GiB ESP (Windows removed), roomy so generation pruning isn't tight.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Filesystems ---
  # root / /nix / /var/lib are btrfs subvolumes from hardware-configuration.nix.
  #   NOTE after generate-config: add `compress=zstd` to those subvol options, and
  #   `nodatacow` to any heavy-write DB/docker path if fragmentation shows up.
  # /home is the existing XFS logical volume on the LVM array (NEVER reformatted).
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/228bacf5-dc6b-4364-9dba-1cec2f4737a4";
    fsType = "xfs";
  };
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/c2b9ec8f-4519-46b4-a3f4-d166e5b4a670";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  zramSwap.enable = true;   # 64G RAM, no swap partition, no hibernate.

  # --- Networking ---
  networking.hostName = "mainframe";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # --- Time / locale ---
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Audio: PipeWire ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;

  # --- SSH: key-only (stops the brute-force that tripped faillock). ---
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # --- Graphics: NVIDIA RTX 2060 SUPER (Turing), open kernel module ---
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  nixpkgs.config.allowUnfree = true;

  # --- X, no display manager: startx into dwm via ~/.config/x11/xinitrc ---
  services.xserver.enable = true;
  services.xserver.displayManager.startx.enable = true;
  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  location.latitude = 39.74;
  location.longitude = -104.99;
  services.redshift = {
    enable = true;
    temperature.day = 5500;
    temperature.night = 3700;
  };

  # --- Docker: compose stacks live in ~/src/{jellyfin,odysseus} ---
  virtualisation.docker.enable = true;
  # hardware.nvidia-container-toolkit.enable = true;  # if a container needs the GPU

  # --- Syncthing ---
  services.syncthing = {
    enable = true;
    user = "grish";
    group = "users";
    configDir = "/home/grish/.local/state/syncthing";   # VERIFY before first switch
  };

  # --- Caddy: reverse proxy + Cloudflare DNS-01 certs (replaces nginx/acme.sh) ---
  # Custom build with the cloudflare DNS plugin. The `hash` below must match the
  # plugin build: on first `nixos-rebuild` it will fail and print the correct
  # sha256 — paste it in and rebuild. (lib.fakeHash placeholder to force that.)
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
    };
    environmentFile = "/etc/caddy/cf-token.env";   # CF_API_TOKEN=...
    configFile = ./Caddyfile;
  };
  # Static site content served by the grish.haus vhost; relocate off the old
  # /usr/share/nginx into a real path and point the Caddyfile `root` at it.
  # (restore from premigration backup during install.)

  # --- fossil repo server on 127.0.0.1:8111 (behind Caddy fossil.grish.haus) ---
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

  # --- Cloudflare DDNS: keep A records on the current public IP (dynamic IP) ---
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

  # --- Nightly /home -> external HDD backup (ports the old root crontab rsync) ---
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

  fonts.packages = with pkgs; [ freefont_ttf inconsolata nerd-fonts.inconsolata ];

  users.users.grish = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "networkmanager" "docker" ];
    shell = pkgs.zsh;               # zsh here (laptop uses nushell)
    initialPassword = "changeme";   # run `passwd` on first login
  };

  programs.nix-ld.enable = true;
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [ urlview ];
  };
  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    interactiveShellInit = ''
      source ${pkgs.zsh-history-substring-search}/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    '';
  };

  environment.systemPackages = with pkgs; [
    parted git sxhkd fzf perl xrdb setxkbmap xmodmap herbe w3m jq yt-dlp
    pulseaudio pavucontrol rsync scrot go go-task gcc silver-searcher unzip
    xclip xdotool zathura zbar lazygit lf tmux feh flameshot gimp fossil openssh
    (pass.withExtensions (exts: [ exts.pass-otp ])) exfatprogs dosfstools
    brave vscode jellyfin-mpv-shim inetutils unclutter-xfixes xev
    claude-code nushell http-nu mpv zsh-history-substring-search diceware
    curl                                # used by cloudflare-ddns
    (kakoune-unwrapped.overrideAttrs (old: {
      src = builtins.fetchGit { url = "https://github.com/mawww/kakoune.git"; ref = "master"; };
    }))
    # autoPatchelfHook bakes the runtime rpath (X11/Xft/fontconfig) into these
    # custom suckless builds — their config.mk hardcodes /usr/local/lib, so without
    # this the binaries link but can't find libX11.so.6 at runtime.
    (dwm.overrideAttrs   (old: { src = /home/grish/src/dwm;   nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
    (st.overrideAttrs    (old: { src = /home/grish/src/st;    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
    (dmenu.overrideAttrs (old: { src = /home/grish/src/dmenu; nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ autoPatchelfHook ]; buildInputs = (old.buildInputs or []) ++ [ fontconfig ]; }))
    docker-compose transmission_4 xcompmgr
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";
}
