{ pkgs, devices }:

let
  mkPhoneBundle = device:
    pkgs.stdenv.mkDerivation {
      pname = "k3s-agent-${device.name}";
      version = "0.1.0";
      src = ./.;

      buildInputs = [ pkgs.k3s pkgs.kubectl ];

      installPhase = ''
        mkdir -p $out/bin
        ln -s ${pkgs.k3s}/bin/k3s $out/bin/k3s
        ln -s ${pkgs.kubectl}/bin/kubectl $out/bin/kubectl

        cat > $out/bin/start-k3s-agent << EOF
        #!/usr/bin/env sh
        set -e

        K3S_URL="''${K3S_URL:-https://10.10.0.10:6443}"
        K3S_TOKEN="''${K3S_TOKEN:-CHANGER_MOI}"
        NODE_IP="''${NODE_IP:-${device.ip}}"
        NODE_NAME="''${NODE_NAME:-${device.name}}"
        IFACE="''${IFACE:-wlan0}"

        exec k3s agent \
          --server "$K3S_URL" \
          --token "$K3S_TOKEN" \
          --node-name "$NODE_NAME" \
          --node-ip "$NODE_IP" \
          --flannel-iface "$IFACE"
        EOF

        chmod +x $out/bin/start-k3s-agent
      '';
    };
in
  builtins.listToAttrs (map (d: {
    name = d.name;
    value = mkPhoneBundle d;
  }) devices)
