# ARM64 实验路线（非推荐）

默认优先使用 x86-64 VPS，并使用 `Dockerfile` 和 `compose.yaml`。本节保留 ARM64 路线，供手头只有 ARM64 VPS 或需要复现实验的人参考；它的性能、兼容性和调试体验都更差，不应作为新部署的默认选择。

## 工作原理与限制

Neko/XFCE 桌面本身运行原生 ARM64 Linux 程序。Windows galgame 的 PE 指令却可能是 x86 或 x86-64。Wine 负责 Windows API 兼容，但 ARM64 Wine 不会把 x86 指令转换成 ARM 指令。

本仓库的 ARM64 镜像在 ARM64 上编译启用了 Box32 的 Box64，再安装 AMD64 和 i386 Wine：Box64 转译 x86-64 Wine 组件，Box32 路径协助运行 32 位 Windows 程序。Compose 配置不映射 GPU，Xorg 和视频编码可能使用 CPU。CPU 开销、帧时间和兼容性取决于 VPS 型号及 galgame 引擎。

曾用这一方案让一款 32 位视觉小说进入主菜单并继续到剧情；这只验证了单个作品的部分流程，不代表其它作品都能运行。曾遇到的坑包括：

- 首次构建需要从源码编译 Box64，耗时和构建期间 CPU 占用都会增加。之后复用本地镜像即可，不要每次启动都 `--build`。
- 32 位与 64 位 PE 需要正确的 Wine loader 和独立 prefix。prefix 第一次创建后架构固定；错误选择时应新建对应 prefix。
- `BOX64_PROFILE=fastest` 曾使一条 32 位启动链黑屏；另一条 64 位启动链没有明显收益。不要把低 CPU 占用误认为更快。
- 软件渲染时，减少 Mesa `LP_NUM_THREADS` 会降低 CPU，但线程过少会让帧率低于 30 FPS。应在同一场景比较画面帧率、输入响应和 CPU；测试中使用 4 个线程并开启 `vblank_mode=1` 后，体感响应较好，但不是所有作品的固定答案。
- `DXVK_FRAME_RATE` 在 WineD3D 且没有 Vulkan/DXVK 时不生效。先看 Wine 日志确认实际图形后端。
- 大型视频、DRM、DirectShow/Media Foundation 需求及特殊 launcher 都可能成为阻碍。先直接验证目标 galgame，再处理串流层问题。

## 使用方式

1. 确认 `uname -m` 返回 `aarch64` 或 `arm64`，并检查所用 Neko 基础镜像确实提供 ARM64。查看目标 exe 的 PE 架构及作品的运行需求。
2. 将 `.env` 按主部署手册配置好公网地址和登录密码。ARM Compose 使用不同的容器、桌面目录和 prefix 路径，避免与 x86-64 prefix 混用。
3. 将 galgame 放入 `galgames/sample-galgame/`，按 PE 架构编辑 `desktop-arm64/sample-galgame.desktop`。
4. 构建并启动：

   ```sh
   docker compose -f compose.arm64.yaml config --quiet
   docker compose -f compose.arm64.yaml up -d --build
   docker compose -f compose.arm64.yaml ps
   docker compose -f compose.arm64.yaml logs --tail=200 neko-arm64
   ```

5. 首次构建期间 CPU 使用率高是预期情况。镜像成功后，后续重启用 `up -d`，避免重复编译。
6. 从桌面快捷方式启动，并分别验证画面、输入、音频和存档持久化。若失败，记录 exe 架构、Wine prefix 架构和完整 Wine 日志，不要不断叠加猜测性的 Box64 参数。

32 位作品需要设置 `WINEARCH=win32` 和使用 Box32 loader。桌面启动器中的 `/usr/local/bin/wine` 是 64 位 wrapper；若目标 exe 是 32 位，将它改为 `WINEARCH=win32` 并调用 `/usr/bin/box64 /usr/lib/wine/wine`，同时使用一个新的 32 位 prefix。64 位作品则使用 `WINEARCH=win64`、`/usr/local/bin/wine` 和独立 64 位 prefix。

网页 HTTPS、域名、端口和 Nginx 仍使用 `DEPLOYMENT.md` 中的流程。ARM Compose 只是替换 Neko/Wine 容器构建与启动文件，不会自动解决作品自身的 Wine 兼容问题。
