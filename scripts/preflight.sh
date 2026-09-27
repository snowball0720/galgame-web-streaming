#!/bin/sh
set -eu

printf '%s\n' '== System =='
uname -a
if [ -r /etc/os-release ]; then
    sed -n '1,8p' /etc/os-release
fi

printf '\n%s\n' '== Tools =='
for tool in docker docker-compose curl git lspci vainfo; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '%-16s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf '%-16s %s\n' "$tool" 'not found'
    fi
done
if docker compose version >/dev/null 2>&1; then
    docker compose version
fi

printf '\n%s\n' '== Display devices =='
if [ -d /dev/dri ]; then
    ls -l /dev/dri
else
    printf '%s\n' '/dev/dri is absent'
fi

printf '\n%s\n' '== GPU =='
if command -v lspci >/dev/null 2>&1; then
    lspci -nnk | grep -A3 -Ei 'VGA compatible|3D controller|Display controller' || true
else
    printf '%s\n' 'Install pciutils to identify the GPU.'
fi

printf '\n%s\n' '== Device groups =='
for group in render video; do
    if command -v getent >/dev/null 2>&1; then
        getent group "$group" || true
    fi
done

printf '\n%s\n' '== Repository inputs =='
for path in .env games/sample-game; do
    if [ -e "$path" ]; then
        printf '%s: present\n' "$path"
    else
        printf '%s: absent\n' "$path"
    fi
done

printf '\n%s\n' 'Preflight is read-only; it does not install packages or change firewall rules.'
