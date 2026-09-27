# Agent deployment instructions

This repository is intended to let an agent deploy a browser-accessible Windows game desktop on the VPS where it was cloned. Treat `DEPLOYMENT.md` as the operational runbook and the checked-in Compose, Docker, Xorg, desktop, and Nginx files as templates to adapt to the actual host.

## Work autonomously

- Inspect the host and this repository before changing anything. Use `scripts/preflight.sh` and read `DEPLOYMENT.md`.
- Complete routine, reversible setup without asking for confirmation. Back up host configuration before editing it.
- Do not assume the VPS architecture, GPU, distribution, domain, public address, existing firewall, or game executable from these examples.
- If a required user-specific value is missing, gather the missing items in one concise question: domain, whether DNS already points to this VPS, game directory and executable, and any credentials needed to access those files. Do useful host inspection while waiting.
- Never print passwords, write them to shell history, or commit `.env`. Ask the user to enter passwords into `.env` through the available secure workflow. Set `.env` permissions to `0600`.
- Game binaries and archives are user-provided data. Do not download or redistribute commercial game files. Do not put them in the Docker build context or Git history.
- Do not replace an existing public web server, firewall policy, or unrelated Docker service blindly. Inspect it, make a narrow change, and preserve a rollback copy.

## Deployment outcome

When required values are available, finish the deployment rather than stopping at a plan:

1. Verify supported architecture and host capabilities. The checked-in image is for Linux x86-64 with an Intel GPU. Adapt it for a different host only when the correct driver and Neko encoder are clear; otherwise explain the exact missing choice.
2. Install or verify Docker Engine and Compose for the host distribution.
3. Prepare `.env`, private game/prefix directories, Intel device access, and firewall rules. Keep Neko's HTTP port bound to loopback; expose WebRTC UDP 443 and serve the web UI behind HTTPS.
4. Build and start the Neko container. Check Compose status, container health endpoint, logs, display renderer, and VA-API access.
5. Configure Nginx and a valid TLS certificate for the user's domain. Check the Nginx configuration before reloading it.
6. Create a game-specific desktop launcher using the actual executable path and correct Wine architecture. Initialize a persistent Wine prefix, start the game, and verify browser video, input, audio, and save persistence where the game permits.
7. Recheck restart behavior and report the URL, service state, verified GPU paths, unresolved game-specific compatibility issues, and backup/config locations. Never include secrets in the report.

Ask before an action only if it is irreversible, would disrupt an unrelated service, or requires a decision the host and repository cannot establish. Opening the ports and installing this service are implied by an explicit request to deploy it.
