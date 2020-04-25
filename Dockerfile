ARG NEXUS_VERSION

FROM maven:3-jdk-8 as gitlabauth
ARG NEXUS_VERSION
ARG NEXUS_VERSION_BUILD

RUN git clone --branch 1.2.4 https://gitlab.med.stanford.edu/irt-public/nexus3-gitlabauth-plugin.git /tmp/build \
    && \
    cd /tmp/build \
    && \
    sed -i pom.xml -e '/<artifactId>nexus-plugins<\/artifactId>/!b;n;c\\t<version>'${NEXUS_VERSION}'-'${NEXUS_VERSION_BUILD}'<\/version>' \
   && \
   mvn -Dmaven.repo.local=/tmp/build/.m2/repository -q clean package


FROM maven:3-jdk-8 as composer
ARG NEXUS_VERSION
ARG NEXUS_VERSION_BUILD

RUN git clone --branch composer-parent-0.0.4 https://github.com/sonatype-nexus-community/nexus-repository-composer.git /tmp/build \
    && \
    cd /tmp/build \
    && \
    sed -i pom.xml -e '/<artifactId>nexus-plugins<\/artifactId>/!b;n;c\\t<version>'${NEXUS_VERSION}'-'${NEXUS_VERSION_BUILD}'<\/version>' \
    && \
    mvn -PbuildKar -Dmaven.repo.local=/tmp/build/.m2/repository -q clean package


FROM sonatype/nexus3:${NEXUS_VERSION} as nexus
ARG NEXUS_VERSION
ARG NEXUS_VERSION_BUILD
ARG GL_APP_TOKEN

USER root

COPY --from=gitlabauth /tmp/build/target/nexus3-gitlabauth-plugin-1.2.0-SNAPSHOT.jar /opt/sonatype/nexus/system/fr/auchan/nexus3-gitlabauth-plugin/1.2.0-SNAPSHOT/
COPY --from=gitlabauth /tmp/build/target/feature/feature.xml /opt/sonatype/nexus/system/fr/auchan/nexus3-gitlabauth-plugin/1.2.0-SNAPSHOT/nexus3-gitlabauth-plugin-1.2.0-SNAPSHOT-features.xml
COPY --from=gitlabauth /tmp/build/pom.xml /opt/sonatype/nexus/system/fr/auchan/nexus3-gitlabauth-plugin/1.2.0-SNAPSHOT/nexus3-gitlabauth-plugin-1.2.0-SNAPSHOT.pom
COPY --from=composer /tmp/build/nexus-repository-composer/target/nexus-repository-composer-0.0.4.jar /opt/sonatype/nexus/system/org/sonatype/nexus/plugins/nexus-repository-composer/0.0.4/nexus-repository-composer-0.0.4.jar
# COPY --from=composer /tmp/build/nexus-repository-composer/target/nexus-repository-composer-*-bundle.kar ${DEPLOY_DIR}

RUN echo "mvn\:fr.auchan/nexus3-gitlabauth-plugin/1.2.0-SNAPSHOT = 200" >> /opt/sonatype/nexus/etc/karaf/startup.properties \
    && \
    echo -e "gitlab.api.url=https://gitlab.parity.digital\ngitlab.api.key=${GL_APP_TOKEN} \ngitlab.principal.cache.ttl=PT1M" >> /opt/sonatype/nexus/etc/gitlabauth.properties \
    && \
    sed -i -e '/<feature version="'${NEXUS_VERSION}'-'${NEXUS_VERSION_BUILD}'">nexus-onboarding-plugin<\/feature>/a \\t<feature prerequisite="false" dependency="false">nexus-repository-composer<\/feature>' \
    /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}-${NEXUS_VERSION_BUILD}/nexus-core-feature-${NEXUS_VERSION}-${NEXUS_VERSION_BUILD}-features.xml \
    && \
    sed -i -e '/<\/features>/i \\t<feature name="nexus-repository-composer" description="org.sonatype.nexus.plugins:nexus-repository-composer" version="0.0.4"> \n \t<details>org.sonatype.nexus.plugins:nexus-repository-composer<\/details>\n \t<bundle>mvn:org.sonatype.nexus.plugins/nexus-repository-composer/0.0.4</bundle>\n \t<\/feature>' \
    /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}-${NEXUS_VERSION_BUILD}/nexus-core-feature-${NEXUS_VERSION}-${NEXUS_VERSION_BUILD}-features.xml 


FROM sonatype/nexus3:${NEXUS_VERSION}
ARG NX_USER
ARG NX_UID
ARG NX_GID

USER root
COPY --from=nexus /opt/sonatype /opt/sonatype

RUN if [[ ! -z ${NX_USER} ]]; then \
      useradd -d /opt/sonatype/nexus -s /bin/false ${NX_USER} \
      $(test ! -z ${NX_UID} && echo -u ${NX_UID} || true) \
      $(test ! -z ${NX_GID} && groupadd -g ${NX_GID} ${NX_USER} && echo -g ${NX_GID} || true); \
      chown -hR ${NX_USER}:${NX_USER} /nexus-data /opt/sonatype; \
      else NX_USER=nexus; \
    fi

USER ${NX_USER}
