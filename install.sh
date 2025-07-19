#!/usr/bin/env bash
# ---------------------------------------------------------------
# LainLinuxSS – one-shot installer for Arch Linux
# ---------------------------------------------------------------
set -euo pipefail
shopt -s nullglob

# ---------- tiny helpers ----------
info()  { printf "\e[1;34m[INFO ]\e[0m %s\n" "$*"; }
warn()  { printf "\e[1;33m[WARN ]\e[0m %s\n" "$*"; }
fatal() { printf "\e[1;31m[FATAL]\e[0m %s\n" "$*"; exit 1; }

# Become root for system tasks, but remember the real user for dotfiles
if [[ $EUID -ne 0 ]]; then
  sudo -E "$0" "$@"
  exit 0
fi
real_user="${SUDO_USER:-$(logname)}"
real_home="$(eval echo "~$real_user")"

# ---------- package list ----------
PKGS=(
  sddm qt5-graphicaleffects qt5-quickcontrols2
  i3-wm i3status polybar rofi picom feh ranger thunar
  dunst xorg-xinit xorg-xrandr network-manager-applet
)
info "Updating system and installing packages…"
pacman -Syu --noconfirm "${PKGS[@]}"

# ---------- enable SDDM ----------
info "Enabling SDDM login manager..."
systemctl enable sddm.service

# ---------- install theme ----------
theme_src=(sddm-lain-wired-theme*  )   # matches your -master folder
theme_src="${theme_src[0]}"
[[ -d $theme_src ]] || fatal "Theme directory not found."

theme_dst=/usr/share/sddm/themes/lain-wired
info "Installing Lain-Wired theme → $theme_dst"
rm -rf "$theme_dst"; mkdir -p "$theme_dst"
cp -r "${theme_src}/." "$theme_dst"

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-theme.conf <<'EOF'
[Theme]
Current=lain-wired
EOF

# ---------- deploy dotfiles ----------
dot_src=(dotfiles* )                 # matches dotfiles-master
dot_src="${dot_src[0]}"
if [[ -d $dot_src ]]; then
  info "Copying dotfiles into $real_home"
  rsync -a --delete --no-perms --no-owner --no-group \
        "$dot_src"/. "$real_home"/
else
  warn "dotfiles directory not found – skipping."
fi

# ---------- fix ownership ----------
chown -R "$real_user":"$real_user" "$real_home"

info "✅  Finished! Reboot and enjoy your Lain-themed desktop."
