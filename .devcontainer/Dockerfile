FROM ubuntu:26.04

# Install basic development tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    git \
    zsh \
    tmux \
    vim \
    rsync \
    libnotify-bin \
    sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user if it does not already exist
RUN useradd -m -s /usr/bin/zsh user1 \
    && echo "user1 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user1 \
    && chmod 0440 /etc/sudoers.d/user1

# Install chezmoi
RUN sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b /usr/local/bin

# Set the default shell to zsh for the user1 user
RUN chsh -s /usr/bin/zsh user1

# Install oh-my-zsh for the user1 user
RUN su user1 -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended

# Ensure the workspace is safe for git
RUN su user1 -c "git config --global --add safe.directory /workspaces/dotfiles"

USER user1
