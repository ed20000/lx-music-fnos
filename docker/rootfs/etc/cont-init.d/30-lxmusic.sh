#!/bin/sh
# 容器初始化：在应用拉起之前执行，此时仍是 root。
#
#   1. 指定 Openbox 的"主窗口"规则，避免 LX Music 的歌词窗/弹窗被当成主窗口。
#   2. 把下载目录交给应用用户：绑定挂载来自 NAS，可能是 root 建的，不处理会写不进去。
#   3. 预建 userData 目录，避免首次写入时父目录不存在。

set -eu

# LX Music 的 BrowserWindow 没有设置标题，窗口 class 取自可执行文件名。
# 只匹配普通窗口 + 该 class，歌词窗（另一个窗口）不会被最大化。
mkdir -p /etc/openbox
cat > /etc/openbox/main-window-selection.xml <<'EOF'
<Type>normal</Type>
<Class>lx-music-desktop</Class>
EOF

DOWNLOAD_DIR="${LX_DOWNLOAD_DIR:-/downloads}"
if [ -d "${DOWNLOAD_DIR}" ]; then
    chown "${USER_ID:-1000}:${GROUP_ID:-1000}" "${DOWNLOAD_DIR}" 2>/dev/null || true
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-/config/.config}"
mkdir -p "${CONFIG_HOME}/lx-music-desktop/LxDatas"
chown -R "${USER_ID:-1000}:${GROUP_ID:-1000}" "${CONFIG_HOME}/lx-music-desktop" 2>/dev/null || true
