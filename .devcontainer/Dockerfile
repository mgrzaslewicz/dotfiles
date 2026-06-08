FROM ubuntu:26.04

ARG USERNAME=user1
ARG USER_UID=1000
ARG USER_GID=1000

# Install basic development tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    ca-certificates \
    curl \
    git \
    zsh \
    tmux \
    vim \
    rsync \
    libnotify-bin \
    sudo \
    fzf \
    file \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user with zsh shell, make sure it doesn't collide with existing one
RUN if getent group ${USER_GID} ; then groupdel $(getent group ${USER_GID} | cut -d: -f1) || true; fi \
    && if getent passwd ${USER_UID} ; then userdel -f $(getent passwd ${USER_UID} | cut -d: -f1) || true; fi \
    && groupadd -g ${USER_GID} ${USERNAME} || true \
    && useradd -l -u ${USER_UID} -g ${USER_GID} -m -s /bin/zsh ${USERNAME}

RUN sh -c "$(curl --retry 10 -fsLS https://get.chezmoi.io)" -- -b /usr/local/bin

USER ${USERNAME}

RUN sh -c "$(curl --retry 10 -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended
RUN sh -c "git config --global --add safe.directory /workspaces/dotfiles"
