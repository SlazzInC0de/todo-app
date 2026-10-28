# Jenkins controller for the self-study lab: Jenkins LTS + Docker CLI + Node.js 22.
# Builds run against the HOST's Docker daemon through the mounted socket
# ("Docker outside of Docker"). Fine for a laptop lab; never do this on a
# shared server, because socket access is equivalent to root on the host.
FROM docker:27-cli AS dockercli
FROM node:22-bookworm-slim AS node

FROM jenkins/jenkins:lts-jdk21
USER root

# Docker CLI (talks to the host daemon via /var/run/docker.sock)
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

# Node.js 22 + npm, so the Test stage runs directly on the controller
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Plugins the Jenkinsfile needs (the setup wizard can then skip plugin install)
RUN jenkins-plugin-cli --plugins \
      workflow-aggregator \
      git \
      credentials-binding \
      timestamper \
      ws-cleanup \
      pipeline-stage-view
