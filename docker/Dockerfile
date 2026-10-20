# LX Music (lx-music-desktop) for fnOS — 容器镜像
#
# 基于 jlesage/baseimage-gui：它已经提供 TigerVNC / noVNC / Openbox /
# PulseAudio（含浏览器音频回传）/ 中文字体安装，我们只需要装 LX Music。
#
# 选 Debian 12 而不是 Alpine：lx-music-desktop 官方只发布 glibc 构建，
# Alpine 的 musl 跑不起来。

ARG BASE_TAG=debian-12-v4
FROM jlesage/baseimage-gui:${BASE_TAG}

ARG LX_VERSION=2.12.6
ARG LX_ARCH=amd64

# Electron 运行时依赖，取自 deb 包 control 文件；另外补中文字体与图标主题。
RUN add-pkg \
        libgtk-3-0 \
        libnotify4 \
        libnss3 \
        libxss1 \
        libxtst6 \
        libatspi2.0-0 \
        libuuid1 \
        libsecret-1-0 \
        libstdc++6 \
        xdg-utils \
        fonts-wqy-zenhei \
        hicolor-icon-theme \
        curl

# 下载并解包官方 deb。ARM 机型构建时传 --build-arg LX_ARCH=arm64。
RUN set -eux; \
    cd /tmp; \
    curl -fsSL -o lx.deb \
        "https://github.com/lyswhut/lx-music-desktop/releases/download/v${LX_VERSION}/lx-music-desktop_${LX_VERSION}_${LX_ARCH}.deb"; \
    dpkg-deb -x lx.deb /; \
    rm -f lx.deb; \
    chmod +x /opt/lx-music-desktop/lx-music-desktop \
             /opt/lx-music-desktop/chrome_crashpad_handler

# 启动脚本：写首次运行的默认设置，并以容器友好的参数拉起 Electron
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# 初始化脚本：Openbox 主窗口选择规则、下载目录与数据目录准备
COPY rootfs/ /
RUN chmod +x /etc/cont-init.d/30-lxmusic.sh

# 应用身份，noVNC 页面标题会显示
RUN set-cont-env APP_NAME "LX Music" && \
    set-cont-env APP_VERSION "${LX_VERSION}"

EXPOSE 5800
