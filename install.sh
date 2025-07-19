#!/usr/bin/env bash
# ---------------------------------------------------------------
# LainLinuxSS – one-shot installer for Arch Linux
# ---------------------------------------------------------------
set -euo pipefail
shopt -s nullglob

info()  { printf "\e[1;34m[INFO ]\e[0m %s\n" "$*"; }
warn()  { printf "\e[1;33m[WARN ]\e[0m %s\n" "$*"; }
fatal() { printf "\e[1;31m[FATAL]\e[0m %s\n" "$*"; exit 1; }

# re-exec as root if needed
if [[ $EUID -ne 0 ]]; then
  sudo -E "$0" "$@"
  exit 0
fi
real_user="${SUDO_USER:-$(logname)}"
real_home="$(eval echo "~$real_user")"

# ---------- official pkgs ----------
PKGS=(
  sddm
  qt5-graphicaleffects qt5-quickcontrols2 qt5-quickcontrols qt5-multimedia
  i3-wm i3status polybar rofi picom feh ranger thunar dunst
  alacritty python-pywal imagemagick playerctl pavucontrol
  ttf-font-awesome noto-fonts-emoji
  xorg-xinit xorg-xrandr network-manager-applet
)

info "Updating system & installing pacman packages…"
pacman -Syu --noconfirm --needed "${PKGS[@]}"

# ---------- enable SDDM ----------
info "Enabling SDDM login manager..."
systemctl enable sddm.service

# ---------- install theme ----------
theme_src=(sddm-lain-wired-theme*)  # matches -master
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
dot_src=(dotfiles*)   # matches dotfiles-master
dot_src="${dot_src[0]}"
if [[ -d $dot_src ]]; then
  info "Copying dotfiles into $real_home"
  # copy safely even though source is nested in $real_home
  cp -a "${dot_src}/." "$real_home"/
else
  warn "dotfiles directory not found – skipping."
fi

# ---------- AUR section (wpgtk, brave) ----------
AUR_PKGS=(wpgtk brave-browser)
if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
  info "Installing paru (AUR helper)…"
  pacman -S --noconfirm --needed base-devel git
  sudo -u "$real_user" bash -c '
    cd "$(mktemp -d)" &&
    git clone https://aur.archlinux.org/paru.git &&
    cd paru &&
    makepkg -si --noconfirm
  '
fi

if command -v paru >/dev/null 2>&1; then
  info "Installing AUR packages: ${AUR_PKGS[*]}"
  sudo -u "$real_user" paru -S --noconfirm --needed "${AUR_PKGS[@]}" || warn "AUR install failed; install manually later."
elif command -v yay >/dev/null 2>&1; then
  info "Installing AUR packages via yay…"
  sudo -u "$real_user" yay -S --noconfirm --needed "${AUR_PKGS[@]}" || warn "AUR install failed; install manually later."
else
  warn "No AUR helper; wpgtk & brave NOT installed."
fi

# ---------- fix ownership ----------
chown -R "$real_user":"$real_user" "$real_home"

info "✅ Finished! Reboot to use your Lain-themed desktop."
