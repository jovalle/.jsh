# jsh testing container
# Minimal environment with bash and zsh for testing shell initialization
FROM debian:bookworm-slim

# Install essential packages and configure locale
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    zsh \
    git \
    curl \
    ca-certificates \
    locales \
    sudo \
    make \
    coreutils \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create a non-root user for testing (matching typical dev setup)
ARG USER=testuser
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} ${USER} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/zsh ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USER}
WORKDIR /home/${USER}

# Default shell (overridable via JSH_TEST_SHELL env var)
ENV JSH_TEST_SHELL=zsh

# Entry point script
COPY --chown=${USER}:${USER} docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
