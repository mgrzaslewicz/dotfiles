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
        # Without tini: `error during container init: exec: "/usr/bin/tini": stat /usr/bin/tini: no such file or directory`
        #tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Install mise, then install and activate latest Node.js
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
RUN curl https://mise.run | sh
RUN mise use --global node@26.1.0
RUN mise use --global npm@11.12.1
RUN mise install
RUN node --version
RUN npm --version
RUN npm install -g @google/gemini-cli \
    && mise reshim \
    && command -v gemini \
    && gemini --version
RUN rm -rf /tmp/* /var/tmp/* "${MISE_CACHE_DIR}"

# Create a non-root gemini-user user
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN if getent group ${GROUP_ID} ; then groupdel $(getent group ${GROUP_ID} | cut -d: -f1) || true; fi \
    && if getent passwd ${USER_ID} ; then userdel -f $(getent passwd ${USER_ID} | cut -d: -f1) || true; fi \
    && groupadd -g ${GROUP_ID} gemini-user || true \
    && useradd -l -u ${USER_ID} -g ${GROUP_ID} -m -s /bin/bash gemini-user

# Create controlled workspace and config/cache dirs
RUN mkdir -p /workspace /home/gemini-user/.config /home/gemini-user/.cache \
    && chown -R gemini-user:gemini-user /workspace /home/gemini-user /opt/mise

USER gemini-user
WORKDIR /workspace

# Keep credentials/config outside the image; mount them at runtime if needed.
ENV HOME=/home/gemini-user
ENV XDG_CONFIG_HOME=/home/gemini-user/.config
ENV XDG_CACHE_HOME=/home/gemini-user/.cache

ENTRYPOINT ["/bin/bash"]
