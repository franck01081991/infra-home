{ lib, config, ... }:
let cfg = config.networking.wireless;
in {
  options.networking.wireless.secretsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = ''
      Path to an environment file consumed by wpa_supplicant. This keeps Wi-Fi
      credentials out of the Nix store while still allowing runtime injection
      through systemd.
    '';
  };

  config = lib.mkIf (cfg.secretsFile != null) {
    assertions = [{
      assertion = cfg.enable;
      message =
        "networking.wireless.secretsFile requires networking.wireless.enable = true";
    }];

    systemd.services.wpa_supplicant = {
      serviceConfig.EnvironmentFile = lib.mkBefore [ cfg.secretsFile ];
    };
  };
}
