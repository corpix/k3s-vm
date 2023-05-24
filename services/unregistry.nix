{ options, config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.unregistry;
  description = "Local docker registry";
in {
  options.services.unregistry =
    with types;
    {
      enable = mkEnableOption description;

      config = mkOption {
        type = attrs;
        default = {};
      };
    };

  config = mkIf cfg.enable {
    users.users.unregistry = {
      inherit description;

      name = "unregistry";
      group = "unregistry";
      isSystemUser = true;
    };
    users.groups.unregistry = {};

    systemd.tmpfiles.rules = ["d /run/unregistry 0700 unregistry unregistry -"];
    systemd.services.unregistry = let
      configFile = pkgs.writeText "unregistry.yml" (builtins.toJSON cfg.config);
    in {
      inherit description;

      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      reload = with pkgs; ''
        ${unregistry}/bin/unregistry -c ${configFile} config validate
        ${coreutils}/bin/kill -HUP $MAINPID
      '';

      serviceConfig = {
        User = "unregistry";
        Group = "unregistry";

        PIDFile = "/run/unregistry/pid";
        ExecStart = "${pkgs.unregistry}/bin/unregistry --pid-file /run/unregistry/pid -c ${configFile}";
      };
    };
  };
}
