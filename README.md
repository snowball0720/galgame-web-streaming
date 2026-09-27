# Neko + Wine Galgame 串流演示

本仓库专门演示在 Linux x86-64 主机上运行 Windows galgame（视觉小说），并通过浏览器串流访问。它不是通用 Windows 游戏或云游戏方案，也不以动作类、实时操作类游戏为目标。galgame 文件需要由使用者自行准备；具体作品仍需逐一验证 Wine 兼容性。

如果让编程 Agent 在 VPS 上完成部署，先让它阅读 [`AGENTS.md`](AGENTS.md)，再按 [`DEPLOYMENT.md`](DEPLOYMENT.md) 执行。文档包含主机检查、HTTPS 首次签发、GPU 验证、galgame 接入和常见故障的处理顺序。

## 目录结构

```text
galgame-web-streaming/
├── .env.example
├── .gitignore
├── .dockerignore
├── AGENTS.md
├── ARM64-EXPERIMENTAL.md
├── DEPLOYMENT.md
├── Dockerfile
├── Dockerfile.arm64
├── compose.yaml
├── compose.arm64.yaml
├── desktop/
│   └── sample-galgame.desktop
├── docker/
│   └── xorg-intel.conf
├── docker-arm64/
│   ├── wine
│   └── wineserver
├── desktop-arm64/
│   └── sample-galgame.desktop
├── nginx/
│   ├── stream.example.org.http.conf
│   └── stream.example.org.conf
└── scripts/
    └── preflight.sh
```

`scripts/preflight.sh` 只读取主机信息，不安装软件或改动配置。把仓库克隆到 VPS 后，可以让 Agent：“先阅读 `AGENTS.md` 和 `DEPLOYMENT.md`，检查这台主机并按仓库说明部署。如果缺少域名、galgame 路径或凭据，一次性列出需要我补充的内容。”

## 准备

需要一台运行 Linux x86-64 的主机、Docker Compose、一个指向主机公网地址的域名，以及用户自行准备的 galgame 文件。当前 Compose 模板按 Intel GPU 编码配置；普通 CPU VPS 可以由 Agent 按部署手册调整为软件渲染和较低串流参数。

复制本目录作为项目目录，然后设置环境变量：

```sh
cp .env.example .env
```

编辑 `.env`，填写域名、公网 IPv4 和强密码。不要把 `.env` 提交到 Git。

把合法取得的 galgame 文件放在 `galgames/sample-galgame/`，并确认入口程序位于：

```text
galgames/sample-galgame/Galgame.exe
```

如实际目录或 exe 文件名不同，请同步修改 `desktop/sample-galgame.desktop`。

## 启动

```sh
docker compose up -d --build
```

Neko Web 界面只监听 `127.0.0.1:18088`，建议通过 Nginx 和 HTTPS 提供网页访问。WebRTC 使用配置的公网 IPv4 和 UDP 443；请在主机防火墙及云平台安全组开放 TCP 80/443 和 UDP 443。

Nginx 示例在 `nginx/stream.example.org.conf`。将 `stream.example.org` 换成自己的域名，并在启用 TLS 前配置好证书。具体证书签发方式取决于所用 ACME 客户端。

## GPU 与串流参数

Compose 示例设置 1920×1080、60 FPS、H.264、8 Mbps 和 VA-API。galgame 渲染与视频编码是两个独立环节：`/dev/dri`、Xorg 和 Mesa 负责图形渲染；Neko 的 VA-API 编码由 `NEKO_HWENC` 配置。可在容器内用 `glxinfo -B` 检查 OpenGL 渲染器，用 `vainfo` 检查 VA-API 支持，并观察实际画面确认链路。

不同 x86 主机的 GPU 型号、设备节点和组 ID 可能不同。示例里的 `/dev/dri/card1` 需要根据主机实际情况调整；`render` 和 `video` 组 ID 可用 `getent group render` 与 `getent group video` 查询。

ARM64 主机有单独的实验配置 `Dockerfile.arm64`、`compose.arm64.yaml` 和 `ARM64-EXPERIMENTAL.md`。它通过 Box64/Box32 转译 x86 Wine，性能和兼容性都不如原生 x86-64 路线，只有目标 VPS 为 ARM64 且接受这些限制时再选。

ARM64 部署时使用 `docker compose -f compose.arm64.yaml ...`，不要用默认的 x86-64 Compose 文件。两套配置会占用相同 Web 和 WebRTC 端口，不要同时启动。构建需要编译 Box64，首次会明显更慢；详细步骤和 32 位/64 位启动器说明见实验文档。

## 文件说明

- `Dockerfile`：在 Neko XFCE 镜像上安装 Wine、Intel VA-API 驱动和日文字体。
- `compose.yaml`：容器、设备、端口和 Neko 串流参数。
- `docker/xorg-intel.conf`：让虚拟 Xorg 使用 Intel modesetting/glamor。
- `desktop/sample-galgame.desktop`：galgame 桌面启动器示例。
- `nginx/stream.example.org.conf`：Nginx TLS 反向代理示例。
- `nginx/stream.example.org.http.conf`：首次签发证书时使用的 HTTP ACME challenge 配置。

这是 galgame 教程模板，不包含作品文件、账号密码、证书或可直接使用的公网地址。部署前请按自己的环境检查并修改占位配置。它不承诺所有 galgame 都能由 Wine 正常运行，更不面向其它类型的 Windows 游戏。
