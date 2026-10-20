#!/bin/sh
# noVNC 前端补丁，通过注入 index.html 的 <head> 完成。
#
# 1. 预置 first_run=false：跳过控制栏首次自动展开，界面打开就是干净的。
#
# 2. 解锁 AudioContext。浏览器只允许音频上下文在用户手势之后运行，而
#    pcm-player 在页面加载时就创建了它，此时必然 suspended；jlesage 自带的
#    unmute 没能救回来（实测仍然报 "not allowed to start"）。
#    这里包一层构造函数把所有实例记下来，首次交互后统一 resume。
#
# 注入点必须在 app/ui.js 之前。ui.js 是 type="module"（延迟执行），
# 内联脚本同步执行，放在 </head> 前即可保证顺序。

set -eu

INDEX=/opt/noVNC/index.html
MARKER='novnc-tuning'

[ -f "${INDEX}" ] || exit 0
grep -q "${MARKER}" "${INDEX}" && exit 0

TMP="${INDEX}.tmp"
awk -v marker="${MARKER}" '
    /<\/head>/ && !done {
        print "    <script id=\"" marker "\">"
        print "      try {"
        print "        if (localStorage.getItem(\"first_run\") === null) localStorage.setItem(\"first_run\", \"false\");"
        print "      } catch (e) {}"
        print "      (function () {"
        print "        var NativeAC = window.AudioContext || window.webkitAudioContext;"
        print "        if (!NativeAC) return;"
        print "        var instances = [];"
        print "        function TrackedAC(opts) {"
        print "          var ctx = new NativeAC(opts);"
        print "          instances.push(ctx);"
        print "          return ctx;"
        print "        }"
        print "        TrackedAC.prototype = NativeAC.prototype;"
        print "        window.AudioContext = TrackedAC;"
        print "        if (window.webkitAudioContext) window.webkitAudioContext = TrackedAC;"
        print "        var armed = false;"
        print "        function arm() { armed = true; }"
        print "        [\"click\", \"mousedown\", \"keydown\", \"touchstart\", \"pointerdown\"].forEach(function (ev) {"
        print "          window.addEventListener(ev, arm, true);"
        print "        });"
        print "        function unlockAll() {"
        print "          for (var i = 0; i < instances.length; i++) {"
        print "            var c = instances[i];"
        print "            if (c && c.state === \"suspended\") { try { c.resume(); } catch (e) {} }"
        print "          }"
        print "        }"
        print "        setInterval(function () { if (armed) unlockAll(); }, 400);"
        print "      })();"
        print "    </script>"
        done = 1
    }
    { print }
' "${INDEX}" > "${TMP}"

mv "${TMP}" "${INDEX}"
echo "novnc-tuning: injected"
