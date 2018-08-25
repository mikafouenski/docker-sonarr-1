FROM mono

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt update && \
    apt install -y git nodejs npm && \
    git clone -b 'v2.0.0.5228' --single-branch --depth 1 https://github.com/Sonarr/Sonarr.git

COPY patch.patch /patch.patch
RUN patch Sonarr/src/NzbDrone.Core/DecisionEngine/DownloadDecisionComparer.cs patch.patch
RUN cd Sonarr && \
    npm install && \
    git submodule update --init

WORKDIR Sonarr
RUN export MONO_IOMAP=case
RUN mono ./tools/nuget/nuget.exe restore ./src/NzbDrone.sln
RUN xbuild ./src/NzbDrone.sln /t:Configuration=Release /t:Build
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y nodejs && \
    nodejs ./node_modules/gulp/bin/gulp.js build
RUN find "_output/" \( \
        -name "ServiceUninstall.*" \
     -o -name "ServiceInstall.*" \
     -o -name "sqlite3.*" \
     -o -name "MediaInfo.*" \
     -o -name "NzbDrone.Windows.*" \
   \) -type f -delete

FROM lsiobase/mono:xenial

# set environment variables
ARG DEBIAN_FRONTEND="noninteractive"
ENV XDG_CONFIG_HOME="/config/xdg"

RUN \
 echo "**** install packages ****" && \
 apt-get update && \
 apt-get install -y \
	libmediainfo-dev sqlite3 && \
 echo "**** cleanup ****" && \
 apt-get clean && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

COPY --from=0 /Sonarr/_output /opt/NzbDrone
RUN find "/opt/NzbDrone" -type d -exec chmod 755 {} \; && \
    find "/opt/NzbDrone" -type f -exec chmod 644 {} \; && \
    find "/opt/NzbDrone" -name \*.exe -type f -exec chmod 755 {} \;

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8989
VOLUME /config /downloads /tv
