{ pkgs }:
pkgs.mkShell {
  name = "infra-home";
  packages = with pkgs; [
    age
    fluxcd
    helm
    kubeconform
    kubectl
    kustomize
    nixfmt-rfc-style
    nixpkgs-lint
    shellcheck
    trufflehog
    yamllint
  ];
}
