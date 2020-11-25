
FROM teracy/ubuntu:18.04-dind-latest

# Extra deps for GHA Runner
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y \
    curl \
    dnsutils \
    jq \
    sudo \
    openssh-client \
    unzip \
    wget \
    zip \
    git \
    && rm -rf /var/lib/apt/list/*


# Add and config runner user as sudo
RUN adduser --disabled-password --gecos "" --uid 1000 runner \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers


# Build args
ARG TARGETPLATFORM=amd64
ARG RUNNER_VERSION=2.274.2
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=19.03.13
ARG DEBUG=false
WORKDIR /runner


# Runner download supports amd64 as x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && curl -Ls -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && rm -rf /var/lib/apt/lists/*

# Dumb Init
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && curl -Ls  -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

#AWS client
RUN curl -Ls "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm -rf awscliv2.zip

COPY startup.sh /usr/local/bin/

# Add patched scripts from GHA runner (svc.sh and RunnerService.js)
COPY --chown=runner:runner patched/ ./patched/

RUN chmod +x ./patched/runsvc.sh /usr/local/bin/startup.sh

USER runner
# Volume to let docker pull all images (with aufs)
# https://github.com/moby/moby/issues/13742
VOLUME /var/lib/docker
ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["startup.sh"]
