FROM ghcr.io/m1k1o/neko/xfce:latest

USER root

RUN dpkg --add-architecture i386 \
    && printf 'deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware\n' \
        > /etc/apt/sources.list.d/debian-nonfree.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
        | gpg --dearmor --yes --output /etc/apt/keyrings/winehq-archive.key \
    && chmod 0644 /etc/apt/keyrings/winehq-archive.key \
    && printf 'Types: deb\nURIs: https://dl.winehq.org/wine-builds/debian/\nSuites: trixie\nComponents: main\nSigned-By: /etc/apt/keyrings/winehq-archive.key\n' \
        > /etc/apt/sources.list.d/winehq.sources \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        winehq-stable \
        intel-media-va-driver-non-free \
        gstreamer1.0-plugins-bad \
        libgl1:amd64 \
        libgl1:i386 \
        libgl1-mesa-dri:amd64 \
        libgl1-mesa-dri:i386 \
        libglx-mesa0:amd64 \
        libglx-mesa0:i386 \
        mesa-utils \
        vainfo \
        locales \
        fonts-noto-cjk \
        fonts-ipafont \
        winbind \
        cabextract \
        unzip \
    && usermod -aG render neko \
    && printf 'ja_JP.UTF-8 UTF-8\n' > /etc/locale.gen \
    && locale-gen ja_JP.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

COPY docker/xorg-intel.conf /etc/neko/xorg.conf

ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    WINEARCH=win64
