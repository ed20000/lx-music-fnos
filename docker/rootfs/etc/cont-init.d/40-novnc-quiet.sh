#!/bin/sh
# 让 noVNC 连接时不自动展开左侧控制栏。
#
# noVNC 连接成功后读 setting first_run：不等于 'false' 就展开控制栏、
# 2 秒后自动收起，并把 first_run 写成 'false'。只要在页面脚本执行前
# 预置这个键，面板就一直保持收起，只留一个可点开的细把手。
#
# 做法是往 index.html 的 </head> 前注入一段小脚本，而不是修改上游的
# ui.js —— 上游文件会随基础镜像整体替换，注入点更稳定。
# 用 awk 而非 python，避免依赖基础镜像里未必存在的解释器。
# 脚本幂等：重复执行不会重复注入。

set -eu

INDEX=/opt/noVNC/index.html
MARKER='novnc-quiet-init'

[ -f "${INDEX}" ] || exit 0
grep -q "${MARKER}" "${INDEX}" && exit 0

TMP="${INDEX}.tmp"
awk -v marker="${MARKER}" '
    /<\/head>/ && !done {
        print "    <script id=\"" marker "\">"
        print "      // 预置 first_run=false：noVNC 据此跳过首次自动展开控制栏。"
        print "      try {"
        print "        var _k = \"first_run\";"
        print "        if (localStorage.getItem(_k) === null) localStorage.setItem(_k, \"false\");"
        print "      } catch (e) {}"
        print "    </script>"
        done = 1
    }
    { print }
' "${INDEX}" > "${TMP}"

mv "${TMP}" "${INDEX}"
echo "novnc-quiet-init: injected"
