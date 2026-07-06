# HAPI 手机公网访问配置指南

本文记录从安装依赖、启动 HAPI Hub、启动 Runner，到手机公网访问和关闭服务的完整流程。

如果目标是“用手机查看 Argo workspace 里本机运行的 HTML 页面”，先看教程版：

```text
docs/argo-hapi-local-html-mobile.md
```

## 当前结论

- Argo 当前实现没有单独的 `HAPI` 顶部文字按钮。
- HAPI 入口位于顶部 `square.grid.2x2` 工作区动作菜单里。
- 必须先选中一个 workspace，且 Argo 能检测到 `hapi` 可执行文件，菜单里才会出现 `Open HAPI Menu`。
- 公网访问不要直接打开 relay 域名；应打开 `https://app.hapi.run/?hub=<relay-url>&token=<token>`。

## 安装 HAPI

推荐安装到用户目录，避免 `sudo`：

```sh
npm install -g --prefix "$HOME/.local" @twsxtd/hapi --registry=https://registry.npmjs.org
```

确认 `~/.local/bin` 在 login shell 的 `PATH` 中：

```sh
zsh -lic 'whence -p hapi; hapi --version'
```

预期能看到类似：

```text
/Users/<user>/.local/bin/hapi
hapi version: 0.20.2
```

也可以用 Homebrew 安装：

```sh
brew install tiann/tap/hapi
```

如果 Homebrew 报 Command Line Tools 过旧，需要先更新 Xcode Command Line Tools；不要为了安装 HAPI 直接删系统目录，除非你明确知道影响。

## Argo 侧配置

Argo 通过 login shell 检测 HAPI：

```sh
zsh -lic 'whence -p hapi'
```

如果这个命令能找到 `hapi`，重启或重新激活 Argo 后，HAPI 菜单会出现在顶部 `square.grid.2x2` 工作区动作菜单中。

检查 Debug 版 Argo 设置：

```sh
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / ".argo-debug/settings.json"
data = json.loads(p.read_text())
print("showHAPIToolbarButton =", data.get("showHAPIToolbarButton", True))
PY
```

如果输出是 `False`，在 Argo 设置里打开 HAPI toolbar 入口，或把该字段改回 `true` 后重启 Argo。

## 启动公网访问

先取本机局域网 IP：

```sh
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
echo "$LAN_IP"
```

启动 HAPI Hub，并监听所有网卡，同时开启 relay：

```sh
HAPI_LISTEN_HOST=0.0.0.0 \
HAPI_PUBLIC_URL="http://${LAN_IP}:3006" \
hapi hub --relay
```

第一次启动会生成 `cliApiToken`，保存到：

```text
~/.hapi/settings.json
```

Hub 输出中会出现：

```text
Open in browser:
  https://app.hapi.run/?hub=https%3A%2F%2F<id>.relay.hapi.run&token=<token>
```

手机公网访问应打开这条完整 URL。

## 后台运行 Hub

macOS 自带 `screen` 可以让 Hub 在后台保持运行：

```sh
cd /tmp
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
/usr/bin/screen -L -dmS argo-hapi-hub \
  env HAPI_LISTEN_HOST=0.0.0.0 \
      HAPI_PUBLIC_URL="http://${LAN_IP}:3006" \
      hapi hub --relay
```

查看 Hub 日志和 QR code：

```sh
screen -r argo-hapi-hub
```

在 `screen` 里按 `Ctrl-a d` 退出查看但不停止 Hub。

## 启动 Runner

Runner 允许手机端远程创建新的 agent session。建议限制 workspace root：

```sh
hapi runner start --workspace-root /Users/liaojingyu/argo
```

检查 Runner：

```sh
hapi runner status
```

## 验证公网访问

从 Hub 日志里复制 relay URL，例如：

```text
https://<id>.relay.hapi.run
```

验证 relay 本身：

```sh
curl -I "https://<id>.relay.hapi.run"
```

预期：

```text
HTTP/2 200
```

验证官方 Web App：

```sh
TOKEN="$(python3 - <<'PY'
import json, pathlib
print(json.loads((pathlib.Path.home() / ".hapi/settings.json").read_text())["cliApiToken"])
PY
)"
HUB="https://<id>.relay.hapi.run"
python3 - <<PY
import urllib.parse
print("https://app.hapi.run/?hub=" + urllib.parse.quote("${HUB}", safe="") + "&token=${TOKEN}")
PY
```

把输出 URL 发到手机浏览器打开。

## 关闭服务

关闭 Hub：

```sh
screen -S argo-hapi-hub -X quit
```

关闭 Runner：

```sh
hapi runner stop
```

确认没有公网入口和本地监听：

```sh
lsof -nP -iTCP:3006 -sTCP:LISTEN
hapi runner status
pgrep -af 'hapi hub|tunwg|hapi runner start-sync|hapi claude --hapi-starting-mode remote' || true
```

如果 `screen` 已退出但 Hub 子进程残留，可按 `hapi runner status` 或 `pgrep` 输出中的 PID 手动结束：

```sh
kill <pid>
```

## 常见问题

### Argo 顶部没有 HAPI 按钮

当前 Argo 没有独立的 HAPI 顶部文字按钮。入口在顶部 `square.grid.2x2` 工作区动作菜单中：

1. 先选中一个 workspace。
2. 点击顶部 `square.grid.2x2` 按钮。
3. 菜单里找 `Open HAPI Menu`。

如果仍没有：

```sh
zsh -lic 'whence -p hapi'
```

如果找不到，说明 Argo 的 login shell 检测不到 HAPI。确认 `~/.local/bin` 在 `~/.zshrc` 里：

```sh
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
```

然后重启 Argo。

### 直接打开 relay URL 只看到 HAPI Hub 提示页

这是正常的。relay URL 是 API/Hub 地址，不是前端 App 地址。手机应打开：

```text
https://app.hapi.run/?hub=<url-encoded-relay-url>&token=<token>
```

### HTTPS relay 起初打不开

`hapi hub --relay` 有时需要等待证书签发。日志会先显示：

```text
Waiting for trusted TLS certificate
```

稍等后再验证：

```sh
curl -I "https://<id>.relay.hapi.run"
```

### 公网能访问但手机无法创建 session

确认 Runner 正在运行且 workspace root 包含目标目录：

```sh
hapi runner status
hapi runner start --workspace-root /Users/liaojingyu/argo
```

### 安全提醒

- 不要把带 `token=` 的 URL 发给别人。
- 用完公网访问后关闭 Hub 和 Runner。
- relay URL 暴露到公网后可能会收到扫描请求；HAPI 依赖 token 做访问控制。
