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

if [ ! -f "${CONFIG_FILE}" ]; then
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cat > "${CONFIG_FILE}" <<EOF
{
	"setting": {
		"version": "2.1.0",
		"download.enable": true,
		"download.savePath": "${DOWNLOAD_DIR}",
		"tray.enable": false,
		"desktopLyric.enable": false
	}
}
EOF
fi

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
