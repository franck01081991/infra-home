_:
let topology = import ../infra/topology.nix;
in { _module.args.topology = topology; }
