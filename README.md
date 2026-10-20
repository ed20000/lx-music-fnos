# LX Music for fnOS

把 [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop)（洛雪音乐）打包成飞牛 fnOS（飞牛私有云 NAS）可直接安装的 `.fpk` 应用。装好后在应用中心点开图标，浏览器里就能搜索歌曲、管理歌单、播放音乐。

## 方案

lx-music-desktop 是 Electron 桌面程序，必须有图形环境；NAS 没有显示器。所以容器里跑一套完整的桌面栈：

```
浏览器 ──HTTP/WebSocket──> nginx + noVNC ──VNC──> TigerVNC/X 服务 ──> LX Music (Electron)
                                                    └──> PulseAudio ──> 浏览器 Web Audio 播放
```

容器基于 [jlesage/baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)，它已经自带了 TigerVNC、noVNC、Openbox、PulseAudio 与音频回传，我们只往里装 LX Music。

对飞牛来说这是一个 Docker 应用：`config/resource` 里声明 `docker-project`，容器启停由应用中心通过 compose 执行。

## 目录结构

```
lx-music-fnos/
├── fpk/                        # fnpack 打包目录
│   ├── manifest                # 应用元数据
│   ├── ICON.PNG / ICON_256.PNG # 应用中心图标（64 / 256）
│   ├── app/
│   │   ├── docker/docker-compose.yaml
│   │   └── ui/config           # 桌面入口
│   ├── cmd/                    # 生命周期脚本
│   ├── config/                 # privilege / resource
│   └── wizard/                 # 安装 / 设置向导
├── docker/                     # 容器镜像构建上下文
│   ├── Dockerfile
│   ├── startapp.sh             # 容器主进程
│   └── rootfs/etc/cont-init.d/ # 容器初始化脚本
├── scripts/build-fpk.sh        # 打包辅助脚本
└── .github/workflows/release.yml
```

## 构建

镜像要先推到自己的仓库，再打包 fpk —— compose 里的镜像地址是占位符。

### 方式一：GitHub Actions（推荐）

仓库推到 GitHub 后，Actions 会自动构建 x86 / arm64 镜像并推到 `ghcr.io/<owner>/<repo>`，同时产出两个架构的 fpk。打 tag 会创建 Release。

```bash
git tag v2.12.6 && git push origin v2.12.6
```

GHCR 里的包默认是私有的：装之前请在仓库设置里把包改成 public，否则飞牛拉不到镜像。

### 方式二：本地

```bash
# 1. 构建并推镜像
docker build --build-arg LX_VERSION=2.12.6 -t ghcr.io/<你的账号>/lx-music-fnos:2.12.6 docker/
docker push ghcr.io/<你的账号>/lx-music-fnos:2.12.6

# 2. 打包 fpk
./scripts/build-fpk.sh \
    --image ghcr.io/<你的账号>/lx-music-fnos \
    --version 2.12.6 \
    --arch x86            # 或 arm
```

产物在 `dist/lxmusic_<版本>_<架构>.fpk`。`fnpack` 需要先装好，下载地址见 <https://developer.fnnas.com/docs/cli/fnpack/>。

## 安装

1. 飞牛桌面 → 应用中心 → 手动安装，选择 `.fpk`
2. 安装向导里设置访问密码（可不设），确认下载目录
3. 装完点开图标即可

音乐默认下载到应用共享目录 `LXMusic`，飞牛文件管理器里可以直接看到和整理。

## 可配置项

| 项目 | 位置 | 说明 |
|---|---|---|
| 访问密码 | 安装向导 / 应用设置 | VNC 协议限制，最多 8 位，只支持 ASCII |
| 下载目录 | 安装向导 / 应用设置 | 绝对路径，默认 `/var/apps/lxmusic/shares/LXMusic` |
| 画面尺寸 | `docker-compose.yaml` | 默认 1220×780，与 LX Music 主窗口宽高比一致 |

改完设置需要重启应用才生效。

## 已知限制

- **声音走浏览器**：音频由容器回传到浏览器播放，关掉页面就没声音。这是 noVNC 方案的固有特性，不是配置问题。
- **密码最多 8 位**：RFB 协议限制，超出部分会被截断。
- **资源占用**：Electron + X 桌面栈常驻约 400–600 MB 内存，建议 x86 机型使用。
- **不能直接接音响**：容器里的音频只走浏览器。想让 NAS 本身出声需要额外的 PulseAudio/ALSA 方案，本包没有做。
- **两个架构分别构建**：Electron 二进制不通用，x86 和 arm 要各打一个 fpk。

## 许可证

- 本项目：MIT
- lx-music-desktop：Apache-2.0
- noVNC：MPL-2.0
- jlesage/docker-baseimage-gui：见上游仓库
