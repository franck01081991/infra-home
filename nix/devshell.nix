{ pkgs }:
pkgs.mkShell {
  name = "infra-home";
  packages = with pkgs; [
    nixfmt-rfc-style
    kubectl
    fluxcd
    helm
    age
    trufflehog
    yamllint
    shellcheck
    kubeconform
    kustomize
  ];
}
