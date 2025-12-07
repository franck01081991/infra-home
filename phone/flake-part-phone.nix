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
        set -euo pipefail

        K3S_URL="''${K3S_URL:-https://10.10.0.10:6443}"
        NODE_IP="''${NODE_IP:-${device.ip}}"
        NODE_NAME="''${NODE_NAME:-${device.name}}"
        IFACE="''${IFACE:-wlan0}"

        # K3S_TOKEN must be injected at runtime from a secret file/env var decrypted outside the Nix store
        # (e.g. SOPS+age -> /run/secrets/k3s/token). See phone/README.md for delivery details.
        TOKEN_FILE="''${K3S_TOKEN_FILE:-/run/secrets/k3s/token}"
        if [ -z "''${K3S_TOKEN:-}" ] && [ -f "$TOKEN_FILE" ]; then
          K3S_TOKEN="$(cat "$TOKEN_FILE")"
        fi

        if [ -z "''${K3S_TOKEN:-}" ]; then
          echo "[start-k3s-agent] Missing K3S_TOKEN (set env or point K3S_TOKEN_FILE to a secret decrypted outside the Nix store)" >&2
          exit 1
        fi

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
    inherit (d) name;
    value = mkPhoneBundle d;
  }) devices)
