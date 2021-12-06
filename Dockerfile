FROM openjdk:17-jdk-bullseye as builder

SHELL ["/bin/bash", "-xe", "-o", "pipefail", "-c"]

ENV MAVEN_VERSION 3.8.4
ENV MAVEN_SHA512 a9b2d825eacf2e771ed5d6b0e01398589ac1bfa4171f36154d1b5787879605507802f699da6f7cfc80732a5282fd31b28e4cd6052338cbef0fa1358b48a5e3c8

RUN mkdir -p /opt/maven
ADD https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    /opt/maven.tar.gz
RUN echo "${MAVEN_SHA512}  /opt/maven.tar.gz" | shasum -a 512 -c
RUN tar -x --strip-components=1 -C /opt/maven -f /opt/maven.tar.gz
ENV PATH /opt/maven/bin:${PATH}

WORKDIR /cloudwatch_exporter
COPY . /cloudwatch_exporter

# As of Java 13, the default is POSIX_SPAWN, which doesn't seem to work on
# ARM64: https://github.com/openzipkin/docker-java/issues/34#issuecomment-721673618
ENV MAVEN_OPTS "-Djdk.lang.Process.launchMechanism=vfork"

RUN mvn package
RUN mv target/cloudwatch_exporter-*-with-dependencies.jar /cloudwatch_exporter.jar

RUN jlink \
        --add-modules java.base,java.desktop,java.logging,java.management,java.naming,jdk.unsupported \
        --strip-debug \
        --no-man-pages \
        --no-header-files \
        --compress=2 \
        --output /javaruntime


FROM debian:bullseye-slim as runner
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
EXPOSE 9106

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=${JAVA_HOME}/bin:${PATH}

WORKDIR /
RUN mkdir /config
COPY --from=builder /cloudwatch_exporter.jar /cloudwatch_exporter.jar
COPY --from=builder /javaruntime $JAVA_HOME
ENTRYPOINT [ "java", "-jar", "/cloudwatch_exporter.jar", "9106"]
CMD ["/config/config.yml"]
