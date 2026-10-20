#!/bin/bash
# 打包辅助脚本：在临时副本里替换镜像地址/版本/架构，然后调用 fnpack。
#
# 用法:
#   scripts/build-fpk.sh --image ghcr.io/<账号>/lx-music-fnos --version 2.12.6 \
#                        [--arch x86|arm] [--fnpack /path/to/fnpack]
#
# 为什么不直接改 fpk/：源目录要保持干净，反复构建时占位符不会被上一次的值污染。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/fpk"

IMAGE=""
VERSION=""
ARCH="x86"
TAG=""
FNPACK="${FNPACK:-fnpack}"

usage() {
    sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --image)   IMAGE="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --arch)    ARCH="$2"; shift 2 ;;
        --tag)     TAG="$2"; shift 2 ;;
        --fnpack)  FNPACK="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "未知参数: $1" >&2; usage ;;
    esac
done

[ -n "${IMAGE}" ] && [ -n "${VERSION}" ] || usage

case "${ARCH}" in
    x86)       PLATFORM="x86" ;;
    arm|arm64) PLATFORM="arm" ;;
    *) echo "架构只能是 x86 或 arm" >&2; exit 1 ;;
esac

command -v "${FNPACK}" >/dev/null 2>&1 || { echo "找不到 fnpack: ${FNPACK}" >&2; exit 1; }

# Docker 仓库名与标签必须是小写 ASCII，否则 daemon 会拒绝拉取。
IMAGE="$(printf '%s' "${IMAGE}" | tr '[:upper:]' '[:lower:]')"
if printf '%s' "${IMAGE}" | grep -qvE '^[a-z0-9]+([._:/-][a-z0-9]+)*$'; then
    echo "镜像地址不合法（只能是小写字母、数字与 . _ : / -）: ${IMAGE}" >&2
    exit 1
fi

# 默认标签带架构后缀：x86 与 arm 的镜像内容不同，共用标签会互相覆盖。
[ -n "${TAG}" ] || TAG="${VERSION}-${PLATFORM}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cp -a "${SRC}/." "${WORK}/"
rm -f "${WORK}"/*.fpk "${WORK}"/app/docker/*.orig

# fnOS 的 fpk 文件名规范: <appname>_<version>_<arch>.fpk
APPNAME="$(sed -n 's/^appname *= *//p' "${WORK}/manifest" | tr -d '[:space:]')"

echo "[build] ${APPNAME} ${VERSION} (${PLATFORM}) -> ${IMAGE}:${TAG}"

# 镜像地址必须写死：fnOS 只替换 TRIM_* 与向导变量，
# ${DOCKER_MIRROR} / ${VERSION} 这类占位符会原样进入 Docker，导致拉取失败。
sed -i "s#^\( *image: \).*#\1${IMAGE}:${TAG}#" \
    "${WORK}/app/docker/docker-compose.yaml"

sed -i \
    -e "s#^version  *= *.*#version               = ${VERSION}#" \
    -e "s#^platform *= *.*#platform              = ${PLATFORM}#" \
    "${WORK}/manifest"

echo "[build] 打包"
( cd "${WORK}" && "${FNPACK}" build )

OUT="${ROOT}/dist/${APPNAME}_${VERSION}_${PLATFORM}.fpk"
mkdir -p "$(dirname "${OUT}")"
mv "${WORK}/${APPNAME}.fpk" "${OUT}"

echo "[build] 完成: ${OUT}"
