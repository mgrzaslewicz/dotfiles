FROM debian:13.4

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_DATA_DIR=/opt/mise
ENV MISE_CONFIG_DIR=/opt/mise
ENV MISE_CACHE_DIR=/opt/mise/cache
ENV PATH="/opt/mise/shims:/opt/mise/bin:${PATH}"

# Install base dependencies
RUN apt-get update \
    && apt install -y \
        curl \
        less \
        libatomic1 \
        tini \
        # command line tools claude might use \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Install mise, then install and activate latest Node.js
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
RUN curl https://mise.run | sh
RUN mise use --global node@26.1.0
RUN mise use --global npm@11.12.1
RUN mise use --global aqua:colbymchenry/codegraph
RUN mise use --global claude@latest
RUN mise install
RUN node --version
RUN npm --version
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

# Create controlled workspace and config/cache dirs
RUN mkdir -p /workspace /home/claude-user/.config /home/claude-user/.cache \
    && chown -R claude-user:claude-user /workspace /home/claude-user /opt/mise

USER claude-user
WORKDIR /workspace


# Keep credentials/config outside the image; mount them at runtime if needed.
ENV HOME=/home/claude-user
ENV XDG_CONFIG_HOME=/home/claude-user/.config
ENV XDG_CACHE_HOME=/home/claude-user/.cache

RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
ENV PATH="$HOME/.local/bin:$PATH"
RUN command -v rtk

ADD --chown=claude-user:claude-user --chmod=500 setup-and-run-claude.sh /home/claude-user/setup-and-run-claude.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD /home/claude-user/setup-and-run-claude.sh
