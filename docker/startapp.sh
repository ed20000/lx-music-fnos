#!/bin/sh
# 由 jlesage 的 app 服务调用，作为容器主进程。
#
# 处理三件事：
#   1. 首次启动写入默认设置（下载目录等），之后以应用内修改为准。
#   2. 关掉托盘：开启托盘后关窗口只是隐藏，容器里没有可见托盘，
#      用户会以为应用关不掉。
#   3. 用容器友好的参数拉起 Electron。

set -u

APP_BIN=/opt/lx-music-desktop/lx-music-desktop

# Electron 的 userData 跟随 XDG_CONFIG_HOME，jlesage 把它指到 /config/xdg/config。
# 设置文件在 <userData>/LxDatas/config_v2.json，结构为 {"setting": {...}}。
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME:-/config}/.config}"
CONFIG_FILE="${CONFIG_HOME}/lx-music-desktop/LxDatas/config_v2.json"
DOWNLOAD_DIR="${LX_DOWNLOAD_DIR:-/downloads}"
# 窗口大小档位：5 = oversized(1385x896)，配 1600x900 画布留出边距。
WINDOW_SIZE_ID="${LX_WINDOW_SIZE_ID:-5}"

mkdir -p "$(dirname "${CONFIG_FILE}")"

if [ ! -f "${CONFIG_FILE}" ]; then
    cat > "${CONFIG_FILE}" <<EOF
{
	"setting": {
		"version": "2.1.0",
		"download.enable": true,
		"download.savePath": "${DOWNLOAD_DIR}",
		"tray.enable": false,
		"desktopLyric.enable": false,
		"common.windowSizeId": ${WINDOW_SIZE_ID}
	}
}
EOF
fi

# 已有配置：只补一次窗口档位，之后以用户在界面里的选择为准。
# 单独用一个标记文件记录，避免每次启动都把用户改过的值覆盖掉。
SEED_MARKER="${CONFIG_HOME}/lx-music-desktop/.window-size-seeded"
if [ ! -f "${SEED_MARKER}" ]; then
    if grep -q '"common.windowSizeId"' "${CONFIG_FILE}"; then
        sed -i "s/\"common.windowSizeId\"[[:space:]]*:[[:space:]]*[0-9]*/\"common.windowSizeId\": ${WINDOW_SIZE_ID}/" \
            "${CONFIG_FILE}"
    else
        sed -i "s/\"setting\"[[:space:]]*:[[:space:]]*{/\"setting\": {\n\t\t\"common.windowSizeId\": ${WINDOW_SIZE_ID},/" \
            "${CONFIG_FILE}"
    fi
    : > "${SEED_MARKER}"
fi

# 确保 PulseAudio 有可用的默认输出设备。
# 基础镜像用 module-null-sink 起服务但没指定名字，某些版本下应用找不到
# 默认设备，表现为"在播放但没声音"。这里显式建一个并设默认。
# startapp.sh 由 app 服务调用，此时 pulseaudio 服务已启动（依赖顺序保证）。
setup_audio_sink() {
    command -v pactl >/dev/null 2>&1 || return 0

    export PULSE_SERVER="${PULSE_SERVER:-unix:/tmp/pulseaudio.sock}"

    i=0
    while [ ! -S /tmp/pulseaudio.sock ] && [ "$i" -lt 20 ]; do
        i=$((i + 1)); sleep 0.5
    done
    [ -S /tmp/pulseaudio.sock ] || return 0

    if pactl list short sinks 2>/dev/null | grep -q lxmusic_sink; then
        pactl set-default-sink lxmusic_sink >/dev/null 2>&1 || true
        return 0
    fi
    pactl load-module module-null-sink sink_name=lxmusic_sink \
        sink_properties="device.description=LX Music Audio" >/dev/null 2>&1 || true
    pactl set-default-sink lxmusic_sink >/dev/null 2>&1 || true
}
setup_audio_sink

# --no-sandbox               容器内没有可用沙箱环境，否则 Electron 直接退出。
# --dt                       关闭透明窗口：VNC 后端不做 ARGB 合成，透明窗口会变黑块。
# --dha                      让 LX Music 自己调用 disableHardwareAcceleration()。
#                            它在 Linux 上会硬编码 --use-gl=desktop，容器里没有
#                            桌面 GL 实现，Chromium 初始化失败会以 SIGTRAP 退出。
# --disable-gpu              只留软件渲染路径，避免再去碰 GL。
# --disable-dev-shm-usage    容器 /dev/shm 偏小时避免渲染进程崩溃。
# --disable-gpu-sandbox      双保险：GPU 进程也不启用沙箱。
exec "${APP_BIN}" \
    --no-sandbox \
    --dt \
    --dha \
    --disable-gpu \
    --disable-gpu-sandbox \
    --disable-dev-shm-usage \
    "$@"
