# Deployment runbook

This runbook deploys a galgame/visual-novel streaming service only. It is not a general Windows game or cloud-gaming setup and does not target action or real-time games. Wine compatibility depends on the exact galgame, its engine, codecs, APIs, and DRM; validate each requested title and do not promise that all galgames work. Adapt package commands to the installed Linux distribution; do not blindly overwrite existing host configuration.

## 1. Inspect the host and repository

Run:

```sh
./scripts/preflight.sh
uname -m
cat /etc/os-release
git status --short
```

The checked-in Dockerfile targets Debian-based Linux on x86-64 and an Intel GPU. Confirm that `/dev/dri` exists and that an Intel render device is present. Common device nodes are `/dev/dri/cardN` and `/dev/dri/renderD128`; the `N` is host-dependent. Check `lspci -nnk` when available. If there is no Intel GPU, do not claim GPU acceleration: use software rendering/encoding by removing the Intel Xorg override, `/dev/dri` mapping, GPU group additions, and VA-API environment from the deployment, then start with a lower target such as 1280×720/30 and 3–4 Mbps. If another GPU exists, use its supported driver and Neko encoder instead.

Confirm the user has a domain and that its A record points at this VPS. Check AAAA records too: remove a stale IPv6 record if the server does not accept IPv6 traffic. Determine the public IPv4 from trusted host/cloud configuration; do not copy the documentation address into `.env`. Check free disk space before building; image layers, the Wine prefix, and galgame data can take several gigabytes.

If the galgame archive or executable is not available, finish the service setup and desktop, then ask the user to provide the legal galgame files and the executable path. Do not download a galgame on the user's behalf from an untrusted source.

## 2. Install host dependencies

Ensure Docker Engine and the Docker Compose plugin are installed using the official instructions for the host distribution. On Ubuntu or Debian, use Docker's signed APT repository: install `ca-certificates` and `curl`, add Docker's official key to `/etc/apt/keyrings/docker.asc`, add the matching `download.docker.com/linux/<distribution>` repository for the host codename and architecture, then install `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`. Enable and start the Docker service. Do not use an unreviewed convenience script as root.

Install host inspection tools from the distribution repositories as available: `git`, `pciutils`, `vainfo`, `intel-gpu-tools`, and `mesa-utils`. A minimal cloud VPS may not have any GPU tools or `/dev/dri`; in that case follow the software-rendering fallback below rather than treating missing utilities as a failed installation.

The account running Compose needs access to Docker. The container needs access to the Intel render device. Read the actual host group IDs:

```sh
stat -c '%A %U:%G %n' /dev/dri/*
getent group render
getent group video
```

Set `RENDER_GID` and `VIDEO_GID` in `.env` to the host values. Do not assume the example IDs are correct.

## 3. Configure secrets, domain, and galgame directories

Copy the example and edit it locally:

```sh
cp .env.example .env
chmod 600 .env
```

Set `DOMAIN`, `PUBLIC_IP`, both long random Neko passwords, and the actual GPU group IDs. `DOMAIN` is used by the Nginx example; `PUBLIC_IP` is Neko's WebRTC NAT address. UDP 443 is wildcard-bound by Compose. Keep `.env` out of Git and do not paste its contents into logs.

Create persistent directories:

```sh
mkdir -p galgames/sample-galgame wine-prefix
```

The galgame files must be readable by the Neko desktop account. The Wine prefix must be writable by it. Check the image's actual UID/GID before setting ownership (the common Neko UID is `1000`); make only the project data directories writable by that account, not the whole host or repository.

Put user-provided galgame files under `galgames/sample-galgame/`. Keep the full directory structure: visual novels often load resources relative to the executable. Update `desktop/sample-galgame.desktop` to match the actual directory and executable. The launcher changes to the galgame directory before starting Wine so relative assets resolve.

Inspect the executable before creating a prefix:

```sh
file galgames/sample-galgame/Galgame.exe
```

Set `WINEARCH=win64` for a 64-bit executable or `win32` for a 32-bit executable, both in Compose and the launcher. Wine prefix architecture is fixed when that prefix is first initialized; use a fresh prefix if the architecture was chosen incorrectly. The included image installs 32-bit runtime libraries, but unusual galgames may still need additional DLLs or codecs.

## 4. Check network and start Neko

Allow inbound TCP 80 and 443 and UDP 443 in both the host firewall and provider security group. Keep SSH access intact. TCP 18088 stays bound to `127.0.0.1`; do not expose it directly to the Internet. UDP 443 binds on all host interfaces so the template also works when a cloud provider maps a public address to a private NIC. If Docker reports that an address cannot be assigned, check whether the public IP is actually configured on the host; keep `PUBLIC_IP` as the WebRTC NAT address and use the wildcard UDP bind shown in Compose.

Review the rendered config, then build and start:

```sh
docker compose config --quiet
docker compose up -d --build
docker compose ps
docker compose logs --tail=200 neko
```

Check the Neko health endpoint from the host:

```sh
curl --fail http://127.0.0.1:18088/health
```

If health is not ready, inspect container logs before changing settings. A container being `running` does not prove that the desktop, GPU, encoder, or WebRTC path works.

## 5. Configure HTTPS in two stages

The first Nginx configuration must not reference certificate files that do not exist yet.

1. Install Nginx and Certbot using the host distribution's supported packages.
2. Install `nginx/stream.example.org.http.conf` as a temporary site, replacing the example domain. It serves the ACME challenge from `/var/www/acme` and proxies HTTP only to loopback.
3. Create `/var/www/acme/.well-known/acme-challenge`, run `nginx -t`, then reload Nginx.
4. Request a certificate with the webroot method, for example:

   ```sh
   certbot certonly --webroot -w /var/www/acme -d YOUR_DOMAIN
   ```

5. Install `nginx/stream.example.org.conf` as the final site, replacing the example domain in the server name and certificate paths. Check with `nginx -t` before reloading.
6. Confirm automated renewal is enabled and run the Certbot renewal dry run if supported.

Preserve existing Nginx sites. If ports 80/443 are already in use, inspect the active configuration and add a narrow virtual host instead of replacing it.

## 6. Verify GPU rendering and video encoding separately

The galgame renderer and the Neko video encoder are separate GPU paths. Low GPU utilization on a still menu is normal for a mostly static visual novel; it does not prove acceleration is broken.

Check OpenGL from inside the container using the Neko display (the display number can vary by image):

```sh
docker exec --user neko -e DISPLAY=:99.0 neko-wine-demo glxinfo -B
```

Look for the Intel/Mesa renderer and `Accelerated: yes`; `llvmpipe` means software rendering. Check the VA-API device:

```sh
docker exec neko-wine-demo vainfo --display drm --device /dev/dri/renderD128
```

On the host, `sudo intel_gpu_top` can show activity while the galgame animates or video encodes. Confirm the actual WebRTC stream in a browser too: a successful HTTP health check does not validate UDP connectivity or encoding.

If GPU access fails, verify the device node, group IDs, container membership, host driver, and Xorg log before changing codecs. Hardware OpenGL can work while hardware video encoding fails, and vice versa.

## 7. Run and validate a galgame

Open the Neko URL in a browser, log in with the Neko user password, and launch the galgame from the desktop shortcut. For diagnosis, first confirm that Wine can start the executable inside the container; then check video, mouse/keyboard, and audio through Neko separately.

For a manual launch, adapt the following to the actual paths and architecture:

```sh
docker exec -d --user 1000:1000 \
  --env DISPLAY=:99.0 \
  --env WINEARCH=win64 \
  --env WINEPREFIX=/wine-prefix/sample-galgame \
  --workdir '/galgames/sample-galgame' \
  neko-wine-demo wine Galgame.exe
```

Use the Neko container's actual desktop UID if it is not `1000`. Wine's first launch may initialize the prefix or show a Mono prompt. A blank window, missing video, or silent opening movie is often a Wine codec/API compatibility issue, not a WebRTC issue. Record the exact galgame symptom and Wine log before adding DLL overrides.

Save location is galgame-specific. Check whether saves are written beside the galgame, in the Wine prefix's `drive_c/users/...` tree, or elsewhere. Ensure the chosen location is on a persistent bind mount, restart the container, and verify a test save remains.

## 8. Practical tuning and lessons learned

- Start at 1280×720/30 or the sample 1920×1080/60 settings only after the galgame works. The desktop resolution, galgame's own display mode, capture frame rate, and browser's received frame rate are separate values. Fullscreen often avoids scaling artifacts; verify actual received FPS rather than assuming a config value guarantees it.
- For static illustrated scenes, 1080p at 8 Mbps is a reasonable starting point. If the result looks the same at lower bandwidth, try 4–6 Mbps or 30 FPS and compare the same animated scene. Higher bitrate mostly increases network use when the image barely changes.
- H.264/legacy Neko configurations may require both `NEKO_H264=true` and a non-zero bitrate. If encoder initialization fails or the stream is black, inspect Neko logs and try the codec settings documented for the exact Neko image version.
- Do not infer hardware encoding from GPU-accelerated galgame rendering. Check VA-API and Neko's encoder path independently.
- On a software-rendered host, Mesa `llvmpipe` can consume several CPU cores. In a measured test, reducing `LP_NUM_THREADS` from its default improved CPU use but eventually dropped galgame frame rate below the 30 FPS stream target. Keep the default unless a same-scene comparison shows a better tradeoff. `vblank_mode=1` improved perceived pacing in one test; verify per galgame and display mode.
- Do not add `DXVK_FRAME_RATE` unless the galgame actually runs through DXVK. If Wine logs show WineD3D and no Vulkan, the setting will not cap the galgame.
- Avoid speculative Wine/Box64 “fastest” flags. A lower CPU reading can mean the galgame stalled or rendered less, not that it became faster. Compare responsiveness, rendered FPS, and logs together.
- A visually static scene can show near-zero GPU use while functioning correctly. Test during animation, transitions, or video playback before diagnosing utilization.

### CPU architecture pitfalls

`amd64` means the x86-64 instruction-set architecture; it does not mean the CPU vendor is AMD. Wine translates Windows APIs but does not translate CPU instructions. A 64-bit Windows galgame needs x86-64 Wine; a 32-bit Windows galgame needs a working 32-bit Wine path. An ARM64 VPS cannot run those binaries with ARM64 Wine alone. The options are an x86-64 VPS, or an ARM64-specific build that uses Box64/Box32 with x86 Wine; the latter adds CPU cost and compatibility risk. Full-system QEMU emulation can be expensive and nested virtualization may not be available.

One tested Box32 path black-screened with `BOX64_PROFILE=fastest`, while a separate 64-bit path showed no meaningful improvement from the same profile. Treat low CPU during a failed launch as a possible hang, not a performance win. The included `Dockerfile` is x86-64 only; do not try to fix an ARM mismatch by merely changing an image tag.

## 9. Operations and backups

Useful commands:

```sh
docker compose ps
docker compose logs -f neko
docker compose restart neko
docker compose down
```

`docker compose down` preserves bind-mounted galgame files and Wine prefixes. Back up `galgames/`, `wine-prefix/`, and the galgame's actual save directory separately. Back up `.env` securely; do not put it in a public archive. After editing the desktop launcher, its read-only bind mount updates immediately; after changing Compose or the Dockerfile, recreate/rebuild the service as needed.

## Troubleshooting checklist

| Symptom | Check first |
| --- | --- |
| Neko page unavailable | `docker compose ps`, container logs, `curl http://127.0.0.1:18088/health`, Nginx `nginx -t`, TCP 443 and DNS |
| Page loads but stream times out | UDP 443 at host and provider firewall, public IP/NAT value, stale AAAA record, browser WebRTC diagnostics |
| Black or frozen stream | Neko logs, valid non-zero bitrate, codec support, desktop/Xorg startup |
| `llvmpipe` renderer | `/dev/dri` mapping, Intel device node, host render group ID, Xorg config/log |
| VA-API permission or init error | `vainfo`, render device ownership, `RENDER_GID`, Intel media driver and supported codec |
| Galgame starts then exits | PE architecture, matching fresh Wine prefix, working directory, missing dependencies, Wine log |
| Galgame opens but media is black/silent | galgame codec/API requirements, Wine support, audio sink and Neko audio track; isolate from browser transport |
| Saves disappear | actual save path and whether it lies on a persistent bind mount |
