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

# Electron 运行时依赖。
#
# 前半部分是 deb 包 control 文件声明的；后半部分是 Debain 认为"桌面环境
# 会提供"、因而没写进 deb 依赖的库 —— 容器里没有桌面环境，必须自己装。
# 这些 soname 是直接读 Electron 主程序 .dynstr 得到的，不是猜的：
#   libgbm.so.1        GPU 缓冲管理（缺它会直接 error while loading shared libraries）
#   libxkbcommon.so.0  键盘映射
#   libXrandr/Xfixes/Xdamage/Xcomposite  X 扩展
#   libcups.so.2       打印子系统（Electron 硬依赖）
#   libasound.so.2     ALSA，配合容器内 PulseAudio
#   libudev.so.1       设备枚举
#
# curl 用于拉取 deb，ca-certificates 是 TLS 校验的前提：本镜像在构建阶段
# 证书目录是空的（运行时才由 /etc/cont-init.d/10-certs.sh 生成），必须自己补。
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
        libgbm1 \
        libxkbcommon0 \
        libxrandr2 \
        libxfixes3 \
        libxdamage1 \
        libxcomposite1 \
        libcups2 \
        libasound2 \
        libudev1 \
        libgl1 \
        libglx-mesa0 \
        libegl1 \
        libegl-mesa0 \
        fonts-wqy-zenhei \
        hicolor-icon-theme \
        curl \
        ca-certificates

# 下载并解包官方 deb。ARM 机型构建时传 --build-arg LX_ARCH=arm64。
#
# 解包后立刻用 ldd 校验动态库：Electron 的缺失库往往要到运行时才暴露
# （libgbm 就是这么漏掉的），在这里失败比装到 NAS 上再排查便宜得多。
RUN set -eux; \
    cd /tmp; \
    curl -fsSL -o lx.deb \
        "https://github.com/lyswhut/lx-music-desktop/releases/download/v${LX_VERSION}/lx-music-desktop_${LX_VERSION}_${LX_ARCH}.deb"; \
    dpkg-deb -x lx.deb /; \
    rm -f lx.deb; \
    chmod +x /opt/lx-music-desktop/lx-music-desktop \
             /opt/lx-music-desktop/chrome_crashpad_handler; \
    missing="$(ldd /opt/lx-music-desktop/lx-music-desktop | awk '/not found/ {print $1}' | sort -u)"; \
    if [ -n "${missing}" ]; then \
        echo "缺少动态库:" >&2; echo "${missing}" >&2; exit 1; \
    fi

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
