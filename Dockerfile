# Environnement de développement infra-home avec Nix
# Pour les utilisateurs qui ne souhaitent pas installer Nix localement

FROM nixos/nix:latest

# Métadonnées
LABEL maintainer="infra-home"
LABEL description="Environnement de développement pour infra-home avec Nix et tous les outils"
LABEL version="1.0"

# Installation des dépendances système de base
RUN apk add --no-cache \
    bash \
    git \
    openssh-client \
    curl \
    wget \
    ca-certificates \
    tzdata

# Configuration de Nix pour permettre les flakes et les features expérimentales
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Création d'un utilisateur non-root pour la sécurité
RUN adduser -D -s /bin/bash nixuser && \
    mkdir -p /home/nixuser/.ssh && \
    chown -R nixuser:nixuser /home/nixuser

# Basculer vers l'utilisateur non-root
USER nixuser
WORKDIR /home/nixuser

# Pré-installation des outils via Nix pour accélérer le premier lancement
# Cela évite d'attendre le téléchargement lors du premier `nix develop`
RUN nix profile install \
    nixpkgs#kubectl \
    nixpkgs#helm \
    nixpkgs#fluxcd \
    nixpkgs#kustomize \
    nixpkgs#sops \
    nixpkgs#age \
    nixpkgs#yamllint \
    nixpkgs#shellcheck \
    nixpkgs#pre-commit

# Configuration Git de base (sera surchargée par l'utilisateur)
RUN git config --global user.name "infra-home-user" && \
    git config --global user.email "user@infra-home.local" && \
    git config --global init.defaultBranch main

# Configuration SSH pour éviter les vérifications d'hôte strictes en dev
RUN echo "Host *" > /home/nixuser/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> /home/nixuser/.ssh/config && \
    echo "    UserKnownHostsFile /dev/null" >> /home/nixuser/.ssh/config && \
    chmod 600 /home/nixuser/.ssh/config

# Point de montage pour le code source
VOLUME ["/workspace"]
WORKDIR /workspace

# Script d'entrée pour configurer l'environnement
COPY --chown=nixuser:nixuser docker-entrypoint.sh /home/nixuser/
RUN chmod +x /home/nixuser/docker-entrypoint.sh

# Variables d'environnement utiles
ENV TERM=xterm-256color
ENV EDITOR=nano

# Exposition du port pour les services de développement
EXPOSE 8080 3000

# Point d'entrée
ENTRYPOINT ["/home/nixuser/docker-entrypoint.sh"]
CMD ["/bin/bash"]