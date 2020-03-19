FROM einonsy/alpine-dind:latest
MAINTAINER jasonEinon

ARG USER=jenkins
ARG GROUP=jenkins
ARG UID=10000
ARG GID=10000
ARG HOME=/user/${USER}
ARG AGENT_WORKDIR=${HOME}/agent

ARG JAVA_VERSION=11.0.5_p10-r0
ARG SUPPORTED_PYTHON_VERSION=2.7.17-r0
ARG ANSIBLE_VERSION=2.5.1
ARG JENKINS_REMOTING_VERSION=3.26

ENV JENKINS_AGENT_WORKDIR=${AGENT_WORKDIR}

RUN set -x \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community shadow \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community openjdk11-jre=${JAVA_VERSION} \
    && apk add --no-cache \
        git \
        zip \
        unzip \
        py-pip \
        make

RUN set -x \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        python=${SUPPORTED_PYTHON_VERSION} \
        python-dev==${SUPPORTED_PYTHON_VERSION} \
        gcc \
        linux-headers \
        musl-dev \
        libffi-dev \
        openssl-dev

RUN set -eux \
    && mkdir -p ${HOME} \
    && addgroup -g ${GID} ${GROUP} \
    && adduser -D -h ${HOME} -u ${UID} -G ${GROUP} ${USER} \
    && usermod -u ${UID} -a -G dockremap ${USER} \
    && chown -R ${USER}:${GROUP} ${HOME}

#RUN pip install --no-cache --upgrade \
#    && pip install boto boto3 pyYAML awscli ansible==${ANSIBLE_VERSION}  g requests google-auth netaddr

RUN set -eux \
    && curl --create-dir -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${JENKINS_REMOTING_VERSION}/remoting-${JENKINS_REMOTING_VERSION}.jar \
    && chmod 755 /usr/share/jenkins \
    && chmod 644 /usr/share/jenkins/slave.jar

RUN set -eux \
    && mkdir -p ${HOME}/.jenkins \
    && mkdir -p ${AGENT_WORKDIR} \
    && chown -R ${USER}:${GROUP} ${HOME/.jenkins} \
    && chown -R ${USER}:${GROUP} ${AGENT_WORKDIR}

VOLUME ${HOME}/.jenkins
VOLUME ${AGENT_WORKDIR}

WORKDIR ${HOME}

ENV AGENT_WORKDIR=${AGENT_WORKDIR}
ENV HOME=/user/${USER}

COPY jenkins-slave.sh /usr/local/bin/jenkins-slave.sh
COPY supervisor.jenkins-slave.conf /etc/supervisor/conf.d/jenkins-slave.conf

# we need somewhere to mount the Ansible rules
RUN mkdir -p /var/lib/epaas2

# maven install and configure

ARG DOTNET_SDK_VERSION=2.1.500-1
ARG MAVEN_VERSION=3.6.3
ARG USER_HOME_DIR="/root"
ARG SHA=c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries


RUN mkdir -p /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

# Configure Kestrel web server to bind to port 80 when present
ENV ASPNETCORE_URLS=http://+:80 \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"


RUN set -eux \
    && chmod +x /usr/local/bin/jenkins-slave.sh \
    && mkdir -p /var/lib/epaas2

####### Hardening steps ##########

# Remove all but a handful of admin commands.
#RUN find /sbin /usr/sbin \
#  ! -type d -a ! -name apk -a ! -name ln \
#  -delete

  # Remove interactive login shell for everybody
# RUN sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd
