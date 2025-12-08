{
  vlans = [
    {
      name = "infra";
      id = 10;
      subnet = "10.10.0.0/24";
      routerAddresses = [
        {
          address = "10.10.0.1";
          prefixLength = 24;
        }
        {
          address = "10.10.0.10";
          prefixLength = 24;
        }
      ];
      defaultGatewayIndex = 0;
      dhcpRange = "set:infra,10.10.0.100,10.10.0.200,12h";
      ingressTcpPorts = [ 22 6443 ];
      forwardRules = [{
        target = "wan";
        allowAll = true;
        tcpPorts = [ ];
        udpPorts = [ ];
      }];
    }
    {
      name = "pro";
      id = 20;
      subnet = "10.20.0.0/24";
      routerAddresses = [{
        address = "10.20.0.1";
        prefixLength = 24;
      }];
      defaultGatewayIndex = 0;
      dhcpRange = "set:pro,10.20.0.100,10.20.0.200,12h";
      ingressTcpPorts = [ ];
      forwardRules = [
        {
          target = "wan";
          allowAll = true;
          tcpPorts = [ ];
          udpPorts = [ ];
        }
        {
          target = "infra";
          tcpPorts = [ 80 443 8443 ];
          udpPorts = [ ];
          allowAll = false;
        }
      ];
    }
    {
      name = "perso";
      id = 30;
      subnet = "10.30.0.0/24";
      routerAddresses = [{
        address = "10.30.0.1";
        prefixLength = 24;
      }];
      defaultGatewayIndex = 0;
      dhcpRange = "set:perso,10.30.0.100,10.30.0.200,12h";
      ingressTcpPorts = [ ];
      forwardRules = [
        {
          target = "wan";
          allowAll = true;
          tcpPorts = [ ];
          udpPorts = [ ];
        }
        {
          target = "infra";
          tcpPorts = [ 443 ];
          udpPorts = [ ];
          allowAll = false;
        }
      ];
    }
    {
      name = "iot";
      id = 40;
      subnet = "10.40.0.0/24";
      routerAddresses = [{
        address = "10.40.0.1";
        prefixLength = 24;
      }];
      defaultGatewayIndex = 0;
      dhcpRange = "set:iot,10.40.0.100,10.40.0.200,12h";
      ingressTcpPorts = [ ];
      forwardRules = [
        {
          target = "wan";
          allowAll = true;
          tcpPorts = [ ];
          udpPorts = [ ];
        }
        {
          target = "infra";
          tcpPorts = [ 443 8123 1883 ];
          udpPorts = [ ];
          allowAll = false;
        }
      ];
    }
  ];

  k3s = {
    apiAddress = "10.10.0.10";
    serverAddr = "https://10.10.0.10:6443";
  };

  hosts = {
    rpi4-1 = {
      router = true;
      addresses = { infra = "10.10.0.10"; };
      k3s = {
        role = "master-worker";
        clusterInit = true;
        nodeLabels = [ "role=infra" ];
      };
    };

    rpi4-2 = {
      router = false;
      addresses = { infra = "10.10.0.11"; };
      k3s = {
        role = "master-worker";
        clusterInit = false;
        nodeLabels = [ "role=infra" ];
      };
    };

    rpi3a-ctl = {
      router = false;
      addresses = { infra = "10.10.0.12"; };
      k3s = {
        role = "control-plane-only";
        clusterInit = false;
        nodeLabels = [ ];
        nodeTaints =
          [ "node-role.kubernetes.io/control-plane=true:NoSchedule" ];
      };
    };
  };
}
