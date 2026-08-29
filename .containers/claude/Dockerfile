FROM debian:13.4

ENV DEBIAN_FRONTEND=noninteractive

# Bake-time mise data dir: node/python/claude/codegraph install here, not at
# the runtime path (/opt/mise) that the "extra tools" volume mounts over
# later — same bake-vs-volume split as Claude's own config (see below).
ENV MISE_DATA_DIR_BAKE=/opt/mise-baked
ENV MISE_CONFIG_DIR=/opt/mise-config
ENV MISE_DATA_DIR=${MISE_DATA_DIR_BAKE}
ENV MISE_CACHE_DIR=${MISE_DATA_DIR_BAKE}/cache
ENV PATH="${MISE_DATA_DIR_BAKE}/shims:${MISE_DATA_DIR_BAKE}/bin:${PATH}"

# Install base dependencies
RUN apt-get update \
    && apt install -y \
        curl \
        less \
        libatomic1 \
        sudo \
        tini \
        # command line tools claude might use \
        git \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Nested rootless podman, for building/running/testing containers from
# within the toolbox. fuse-overlayfs backs storage (no native
# overlay-on-overlay support for a rootless container inside a rootless
# container); slirp4netns gives the nested containers networking; uidmap
# supplies newuidmap/newgidmap for the nested user namespace.
RUN apt-get update \
    && apt install -y \
        podman \
        podman-compose \
        fuse-overlayfs \
        slirp4netns \
        uidmap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install mise, then install and activate latest Node.js
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
RUN curl https://mise.run | sh
RUN mise use --global node@latest
RUN mise use --global npm@latest
RUN mise use --global python@latest
RUN mise use --global aqua:colbymchenry/codegraph
RUN mise use --global claude@latest
RUN mise install
RUN node --version
RUN npm --version
RUN python3 --version
RUN mise reshim \
    && command -v claude \
    && claude --version \
    && command -v codegraph
RUN rm -rf /tmp/* /var/tmp/* "${MISE_CACHE_DIR}"

# Create a non-root claude-user user
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN if getent group ${GROUP_ID} ; then groupdel $(getent group ${GROUP_ID} | cut -d: -f1) || true; fi \
    && if getent passwd ${USER_ID} ; then userdel -f $(getent passwd ${USER_ID} | cut -d: -f1) || true; fi \
    && groupadd -g ${GROUP_ID} claude-user || true \
    && useradd -l -u ${USER_ID} -g ${GROUP_ID} -m -s /bin/bash claude-user

# Subordinate UID/GID range for claude-user, required for nested rootless
# podman to build its own user namespace inside the container.
RUN usermod --add-subuids 100000-165535 --add-subgids 100000-165535 claude-user

# Passwordless sudo, scoped to apt-get install/update only — lets an agent
# install project-specific system deps (e.g. `playwright install --with-deps`,
# which shells out to `sudo apt-get` itself) without granting broader root.
# Package maintainer/post-install scripts still run as root regardless of
# this scoping; that risk is inherent to apt and not closed by it.
RUN echo 'claude-user ALL=(root) NOPASSWD: /usr/bin/apt-get install *, /usr/bin/apt-get update' > /etc/sudoers.d/claude-user \
    && chmod 0440 /etc/sudoers.d/claude-user \
    && visudo -c -f /etc/sudoers.d/claude-user

# Create controlled workspace and config/cache dirs. /opt/mise is the
# runtime-only mount point for the "extra tools" volume — created empty here
# so a fresh volume starts clean; the entrypoint seeds it from
# /opt/mise-baked on first run. ~/.ssh is a mount anchor for the read-only
# config/known_hosts bind mounts added at container launch (see
# dot_local/bin/executable_claude / claude-toolbox()) — created here with the
# permissions ssh expects so those mounts don't land root-owned.
RUN mkdir -p /workspace /home/claude-user/.config /home/claude-user/.cache /home/claude-user/.ssh /opt/claude-config-baked /opt/mise \
    && chmod 700 /home/claude-user/.ssh \
    && chown -R claude-user:claude-user /workspace /home/claude-user /opt/mise-baked /opt/mise-config /opt/mise /opt/claude-config-baked

# Rootless-in-rootless podman config: fuse-overlayfs backs storage, and
# cgroupfs is the only manager available since there's no systemd/session
# manager inside this image. Applies to claude-user's rootless podman too —
# rootless falls back to this system file when no user-level override exists.
RUN mkdir -p /etc/containers \
    && printf '[storage]\ndriver = "overlay"\n\n[storage.options.overlay]\nmount_program = "/usr/bin/fuse-overlayfs"\n' > /etc/containers/storage.conf \
    && printf '[engine]\ncgroup_manager = "cgroupfs"\n' > /etc/containers/containers.conf

USER claude-user
WORKDIR /workspace


# Keep credentials/config outside the image; mount them at runtime if needed.
ENV HOME=/home/claude-user
ENV XDG_CONFIG_HOME=/home/claude-user/.config
ENV XDG_CACHE_HOME=/home/claude-user/.cache

ADD --chown=claude-user:claude-user --chmod=644 CONTAINER.md /home/claude-user/.claude/CONTAINER.md
ADD --chown=claude-user:claude-user --chmod=644 CLAUDE.md /home/claude-user/.claude/CLAUDE.md

RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
ENV PATH="$HOME/.local/bin:$PATH"
RUN command -v rtk

# Bake plugins/skills into a build-only path outside $HOME, so a runtime
# volume mounted over ~/.claude never shadows them.
ENV CLAUDE_CONFIG_DIR_BAKE=/opt/claude-config-baked
RUN CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin marketplace add mattpocock/skills \
    && CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin install mattpocock-skills@mattpocock

RUN CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin marketplace add JuliusBrussee/caveman \
    && CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_BAKE} claude plugin install caveman@caveman

# Container-only default: lite. Env var, not a repo-committed .caveman.json —
# a repo file would apply on the host too wherever this repo is checked out.
ENV CAVEMAN_DEFAULT_MODE=lite

# Claude Code reads marketplace/plugin-cache state straight from this seed dir
# on every startup (read-only, additive) — no runtime merge script needed for it.
ENV CLAUDE_CODE_PLUGIN_SEED_DIR=${CLAUDE_CONFIG_DIR_BAKE}/plugins

# Switch to the runtime mise data dir: volume-backed (see claude-toolbox() in
# executable_claude.zsh), so tools installed here (e.g. `mise use java@21`
# for one project) persist across containers and across image rebuilds.
# MISE_CONFIG_DIR keeps pointing at the baked, never-mounted /opt/mise-config,
# so the pinned node/npm/python/claude/codegraph versions are never shadowed.
ENV MISE_DATA_DIR=/opt/mise
ENV MISE_CACHE_DIR=/opt/mise/cache
ENV PATH="/opt/mise/shims:/opt/mise/bin:${PATH}"

ADD --chown=claude-user:claude-user --chmod=500 setup-and-run-claude.sh /home/claude-user/setup-and-run-claude.sh
ADD --chown=claude-user:claude-user --chmod=500 claude-statusline.sh /home/claude-user/.local/bin/claude-statusline.sh

# newuidmap/newgidmap privilege (setuid or file-capability) is meaningless if
# granted at build time: it's checked against the uid that owns the running
# container's OWN user namespace (its ns-uid 0), and --userns=keep-id (see
# executable_claude) deliberately makes that NOT match the identity the image
# was built under — the kernel's rootid/kuid check on both mechanisms then
# fails "Operation not permitted", no matter which mechanism is used. Fixing
# it at build time was the bug in the last two commits; the actual fix is to
# re-grant it fresh at container *start*, as that specific container's own
# real root, which is self-consistent by construction. Requires the container
# to still start as root — see fix-nested-podman-and-run.sh.
ADD --chown=root:root --chmod=500 fix-nested-podman-and-run.sh /usr/local/bin/fix-nested-podman-and-run.sh
USER root

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD /usr/local/bin/fix-nested-podman-and-run.sh
