{ pkgs }:

pkgs.mkShell {
  name = "infra-home";
  packages = with pkgs; [
    age
    fluxcd
    kustomize
    helm
    kubeconform
    kubectl
    nixfmt-rfc-style
    shellcheck
    trufflehog
    yamllint
  ];
}
