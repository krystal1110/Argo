# Argo + HAPI 教程：在手机上访问本机 HTML 页面

这篇教程讲一个很具体的工作流：

在 Mac 上用 Argo 打开项目，用 HAPI 把 agent session 接到手机上，然后在手机浏览器里查看本机正在跑的 HTML 页面。

最终你会得到两个手机页面：

1. HAPI 控制台：用来远程操作 HAPI Claude session，让 Claude 修改文件、启动服务、查看日志。
2. HTML 预览页：用来打开本机的 `index.html` 或前端 dev server。

## 0. 先确认 HAPI 已安装

如果还没有安装 HAPI，推荐安装到用户目录：

```sh
npm install -g --prefix "$HOME/.local" @twsxtd/hapi --registry=https://registry.npmjs.org
```

确认 Argo 的 login shell 能找到 HAPI：

```sh
zsh -lic 'whence -p hapi; hapi --version'
```

正常会看到类似：

```text
/Users/<user>/.local/bin/hapi
hapi version: 0.20.2
```

如果这里找不到 `hapi`，先把下面这行放进 `~/.zshrc`，然后重启 Argo：

```sh
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
```

## 1. 在 Argo 里找到 HAPI 菜单

Argo 里不一定有一个写着 `HAPI` 的顶部文字按钮。入口在 workspace 顶部的工作区动作菜单里。

按这个顺序找：

1. 打开 Argo。
2. 在左侧先选中一个 workspace。
3. 看窗口顶部右侧，找到 `square.grid.2x2` 网格按钮。
4. 点击这个网格按钮。
5. 在菜单里选择 `Open HAPI Menu`。

菜单入口大致在这里：

![Argo HAPI 菜单入口](assets/argo-hapi-menu-annotated.png)

打开后，你会看到类似这些选项：

```text
HAPI Hub
HAPI Hub（--relay）
HAPI Claude
HAPI Codex
HAPI Cursor
HAPI Gemini
HAPI Show Settings
HAPI Auth Status
HAPI Auth Login
HAPI Auth Logout
HAPI 文档
```

如果没有看到 `Open HAPI Menu`，通常是两种情况：

- 还没有选中 workspace。
- Argo 没检测到 `hapi` 命令，需要回到第 0 步确认 `zsh -lic 'whence -p hapi'` 能找到它。

## 2. 用 HAPI 启动本地服务

HAPI 的本地服务叫 Hub。手机要先连到 Hub，才能看到和控制本机的 agent session。

在 Argo 菜单里有两种启动方式：

- 只在同一 Wi-Fi 里用：选择 `HAPI Hub`。
- 想通过公网访问：选择 `HAPI Hub（--relay）`。

也可以在 Argo 终端里手动启动。

同一 Wi-Fi 使用：

```sh
HAPI_LISTEN_HOST=0.0.0.0 hapi hub
```

公网 relay 使用：

```sh
hapi hub --relay
```

启动后，终端会输出可以打开的 host。常见有两种：

```text
http://localhost:3006
```

或者 relay 形式：

```text
https://app.hapi.run/?hub=https%3A%2F%2F<id>.relay.hapi.run&token=<token>
```

如果是在手机上访问本机局域网服务，不要复制 `localhost`。先拿 Mac 的局域网 IP：

```sh
ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
```

假设输出是：

```text
192.168.1.23
```

那么手机打开：

```text
http://192.168.1.23:3006
```

如果你用的是 `hapi hub --relay`，就直接复制终端里输出的 `https://app.hapi.run/...` 链接或扫描 QR code。

## 3. 登录 HAPI 时填写 token

打开 HAPI host 后，如果页面要求登录，需要填写 token。

token 可以从 HAPI 的设置里拿：

1. 打开 HAPI 页面。
2. 进入 `Settings`。
3. 找到 token 或 CLI API token。
4. 复制后粘贴到登录框。

如果你还没有进入 HAPI 页面，也可以在 Argo 的 `Open HAPI Menu` 里点 `HAPI Show Settings`，从 HAPI 设置里查看当前 token。

如果你已经在 Mac 上启动过 HAPI，也可以从本机配置文件读取：

```sh
python3 - <<'PY'
import json
from pathlib import Path

settings = Path.home() / ".hapi/settings.json"
print(json.loads(settings.read_text())["cliApiToken"])
PY
```

这会直接打印当前 HAPI 使用的 token。

有些 `hapi hub --relay` 输出的链接已经带了 `token=` 参数，这种情况下手机打开链接后通常不需要手动再填一次。不要把带 token 的链接发给不信任的人。

## 4. 启动对应的 HAPI Claude session

Hub 只是控制台。要让手机真的控制 Claude session，还需要启动一个 HAPI Claude session。

最简单的方法是在 Argo 里启动：

1. 选中目标 workspace。
2. 点击顶部 `square.grid.2x2` 网格按钮。
3. 进入 `Open HAPI Menu`。
4. 选择 `HAPI Claude`。

也可以在 Argo 终端里手动启动：

```sh
cd /Users/liaojingyu/argo
hapi
```

Argo 菜单里的名字是 `HAPI Claude`。CLI 的公开用法是 `hapi [options]`，也就是用 HAPI 包一层 Claude Code session。

如果你希望手机端能从 HAPI 页面新建 session，而不是只能接管当前 session，再启动 Runner：

```sh
hapi runner start --workspace-root /Users/liaojingyu/argo
```

`--workspace-root` 很重要。它限制手机端能浏览和启动 session 的目录范围，不要随手给整个磁盘。

启动完成后，回到手机 HAPI 控制台，应该可以看到对应的 Claude session。之后你就可以在手机上输入需求，例如：

```text
帮我打开这个项目里的 index.html，启动本地预览服务，并告诉我手机应该访问哪个地址。
```

## 5. 启动 HTML 本地预览服务

现在 HAPI 控制台已经能操作 Claude 了，下一步是启动真正的 HTML 页面服务。

如果只是一个普通静态 HTML 文件，例如：

```text
/Users/liaojingyu/argo/demo/index.html
```

在 Argo 终端或 HAPI Claude 里执行：

```sh
cd /Users/liaojingyu/argo/demo
python3 -m http.server 8080 --bind 0.0.0.0
```

然后手机打开：

```text
http://<Mac-IP>:8080/
```

例如 Mac IP 是 `192.168.1.23`，就打开：

```text
http://192.168.1.23:8080/
```

这里不要用：

```text
http://localhost:8080
```

因为手机上的 `localhost` 指的是手机自己，不是 Mac。

## 6. 如果是 Vite 或 Next.js 项目

如果项目不是纯 HTML，而是 Vite、Next.js 之类的前端项目，要让 dev server 监听 `0.0.0.0`。

Vite：

```sh
npm run dev -- --host 0.0.0.0
```

手机打开：

```text
http://<Mac-IP>:5173
```

Next.js：

```sh
npm run dev -- --hostname 0.0.0.0
```

手机打开：

```text
http://<Mac-IP>:3000
```

如果终端输出了其他端口，以终端输出为准。

## 7. 推荐的完整操作顺序

第一次用时，照这个顺序走最稳：

1. 在 Argo 里选中 workspace。
2. 点顶部 `square.grid.2x2` 网格按钮。
3. 进入 `Open HAPI Menu`。
4. 选择 `HAPI Hub` 或 `HAPI Hub（--relay）`。
5. 复制 Hub 输出的 host，用手机浏览器打开。
6. 如果提示登录，去 HAPI `Settings` 复制 token；也可以从 `~/.hapi/settings.json` 读取 `cliApiToken`。
7. 回到 Argo 的 HAPI 菜单，选择 `HAPI Claude`。
8. 手机 HAPI 控制台里打开 Claude session。
9. 让 Claude 启动 HTML 预览服务，例如：

   ```sh
   python3 -m http.server 8080 --bind 0.0.0.0
   ```

10. 手机另开一个标签页访问：

    ```text
    http://<Mac-IP>:8080/
    ```

之后你的工作流就是：手机在 HAPI 里让 Claude 改代码，另一个标签页刷新 HTML 预览。

## 8. 常见问题

### HAPI 页面能打开，但 HTML 页面打不开

HAPI Hub 和 HTML 预览服务是两个不同服务：

- HAPI Hub 默认是 `3006` 端口。
- HTML 预览可能是 `8080`、`5173`、`3000` 或其他端口。

手机打开 HAPI 控制台，不等于自动能打开 HTML 页面。HTML 服务必须单独启动，并且要监听 `0.0.0.0`。

### `hapi hub --relay` 能不能直接让公网访问 HTML 页面

不能直接这样理解。`hapi hub --relay` 暴露的是 HAPI 控制台，不是任意本地端口代理。

如果你要公网直接访问本机 HTML 预览页，需要额外工具，例如 Cloudflare Tunnel、Tailscale、ngrok，或者把页面部署到线上预览环境。

### 手机访问 `localhost` 为什么不行

因为手机里的 `localhost` 是手机自己。访问 Mac 上的服务，要用 Mac 的局域网 IP：

```text
http://<Mac-IP>:8080
```

### 怎么确认 HTML 服务有没有启动

在 Mac 上检查：

```sh
lsof -nP -iTCP:8080 -sTCP:LISTEN
curl -I http://127.0.0.1:8080/
```

如果 Mac 本机能访问，手机不能访问，通常是以下原因：

- 手机和 Mac 不在同一个 Wi-Fi。
- 当前 Wi-Fi 禁止设备互访。
- macOS 防火墙拦截。
- 服务只监听了 `127.0.0.1`，没有监听 `0.0.0.0`。

### 怎么关闭

HTML 服务在终端里按 `Ctrl-C`。

停止 Runner：

```sh
hapi runner stop
```

Hub 如果是前台启动，也按 `Ctrl-C`。最后检查：

```sh
lsof -nP -iTCP:3006 -sTCP:LISTEN
lsof -nP -iTCP:8080 -sTCP:LISTEN
hapi runner status
```

## 参考资料

- HAPI Quick Start: https://hapi.run/docs/guide/quick-start
- HAPI Installation: https://hapi.run/docs/guide/installation
- HAPI How it Works: https://hapi.run/docs/guide/how-it-works
