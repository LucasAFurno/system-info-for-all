#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# ================= Utilidades de plataforma/distro =================
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
cmd(){ command -v "$1" >/dev/null 2>&1; }

detect_linux_distro() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local id_low like_low
    id_low="$(printf '%s' "${ID:-}" | tr '[:upper:]' '[:lower:]')"
    like_low="$(printf '%s' "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
    case "$id_low" in
      ubuntu|debian|linuxmint) echo "debian"; return ;;
      fedora|rhel|rocky|almalinux|centos) echo "fedora"; return ;;
      arch|endeavouros|manjaro) echo "arch"; return ;;
      alpine) echo "alpine"; return ;;
      opensuse*|sles) echo "suse"; return ;;
    esac
    case "$like_low" in
      *debian*) echo "debian" ;;
      *rhel*|*fedora*) echo "fedora" ;;
      *arch*) echo "arch" ;;
      *alpine*) echo "alpine" ;;
      *suse*) echo "suse" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

ensure_root_for_install() {
  if [ "$EUID" -ne 0 ]; then
    printf "Necesito permisos de root para instalar paquetes en Linux. Abortando instalación.\n"
    return 1
  fi
}

pm_update_linux() {
  case "$LINUX_DISTRO" in
    debian) apt update -y ;;
    fedora) dnf -y makecache ;;
    arch)   pacman -Sy --noconfirm ;;
    alpine) apk update ;;
    suse)   zypper refresh ;;
    *)      return 0 ;;
  esac
}

pm_install_linux() {
  # $@ = paquetes
  case "$LINUX_DISTRO" in
    debian) DEBIAN_FRONTEND=noninteractive apt install -y "$@" ;;
    fedora) dnf install -y "$@" ;;
    arch)   pacman -S --noconfirm --needed "$@" ;;
    alpine) apk add --no-cache "$@" ;;
    suse)   zypper install -y "$@" ;;
    *)      printf "No se reconoce la distro para instalar: %s\n" "$*"; return 1 ;;
  esac
}

ensure_brew() {
  if cmd brew; then return 0; fi
  printf "Homebrew no está instalado.\n"
  read -rp "¿Querés instalar Homebrew? (recomendado en macOS) [s/N]: " r
  if [[ "$r" =~ ^[sS]$ ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Agregar brew al PATH en shells comunes (no rompemos si falla)
    if [ -d /opt/homebrew/bin ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)" || true
    elif [ -d /usr/local/bin ]; then
      eval "$(/usr/local/bin/brew shellenv)" || true
    fi
  else
    return 1
  fi
}

pm_install_macos() {
  # $@ = paquetes
  ensure_brew || { printf "No se puede instalar (falta brew).\n"; return 1; }
  brew update
  brew install "$@"
}

# ================= Estilos (solo si hay TTY) =================
espaciado="============================================================"
if [ -t 1 ] && cmd tput; then
  bold=$(tput bold); reset=$(tput sgr0)
  c1=$(tput setaf 6)   # cian
  c2=$(tput setaf 3)   # amarillo
else
  bold=""; reset=""; c1=""; c2=""
fi

titulo(){ printf "\n%s%s%s\n%s\n" "$bold" "${c1}$1" "$reset" "$espaciado"; }

# ================= Encabezado =================
PLATFORM="linux"
if is_macos; then PLATFORM="macos"; fi
LINUX_DISTRO="unknown"
[ "$PLATFORM" = "linux" ] && LINUX_DISTRO="$(detect_linux_distro)"

printf "Información del sistema (%s%s)\n%s\n" "$PLATFORM" \
  "$([ "$PLATFORM" = "linux" ] && printf "/%s" "$LINUX_DISTRO" || true)" \
  "$espaciado"

# SO y Kernel / Versión
titulo "SO y Kernel"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  printf "SO:        %s\n" "${PRETTY_NAME:-Desconocido}"
elif is_macos; then
  printf "SO:        macOS %s\n" "$(sw_vers -productVersion 2>/dev/null || echo "?")"
else
  printf "SO:        (desconocido)\n"
fi
printf "Kernel:    %s\n" "$(uname -r)"
printf "Hostname:  %s\n" "$(hostname)"

# Uptime y carga
titulo "Uptime y Carga"
if is_macos && ! cmd uptime; then
  printf "Uptime:    (comando uptime no disponible)\n"
else
  printf "Uptime:    %s\n" "$(uptime -p 2>/dev/null || uptime || true)"
fi
printf "Load avg:  %s\n" "$(cut -d ' ' -f1-3 /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg 2>/dev/null || echo "?")"

# CPU
titulo "CPU"
if cmd lscpu; then
  printf "Modelo:    %s\n" "$(lscpu | awk -F: '/Model name/ {sub(/^ /,"",$2); print $2; exit}')"
elif is_macos; then
  printf "Modelo:    %s\n" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "?")"
else
  printf "Modelo:    %s\n" "$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
fi
if cmd nproc; then cores="$(nproc)"; else cores="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "?")"; fi
printf "Cores:     %s\n" "$cores"

# Memoria RAM
titulo "Estado de la memoria RAM"
if cmd free; then
  free -h
elif is_macos; then
  vm_stat || true
else
  awk '/MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree/ {printf "%-14s %s\n",$1,$2}' /proc/meminfo 2>/dev/null || true
fi

# Disco
titulo "Disco (uso por sistema de archivos)"
if is_macos; then
  df -h
else
  df -hT -x tmpfs -x devtmpfs 2>/dev/null || df -h -x tmpfs -x devtmpfs
fi

# Red
titulo "Red"
if is_macos; then
  printf "Interfaces:\n"; ifconfig | awk '/^[a-z0-9]/ {print $1}'
  printf "IP(s):     %s\n" "$(ipconfig getifaddr en0 2>/dev/null || true) $(ipconfig getifaddr en1 2>/dev/null || true)"
else
  printf "IPs (LAN): %s\n" "$(hostname -I 2>/dev/null || true)"
  if cmd ip; then
    ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src"){print "Salida:   "$(i+1); exit}}'
  fi
fi

# Gráficos
titulo "Gráficos"
if is_macos; then
  system_profiler SPDisplaysDataType 2>/dev/null | awk -F: '/Chipset Model|VRAM/ {gsub(/^[ \t]+/,"",$2); printf "%-14s %s\n",$1,$2}'
elif cmd lspci; then
  lspci | grep -Ei 'vga|3d|display' || printf "No detectado\n"
else
  printf "lspci no disponible\n"
fi

# ================= Sensores (instalación opcional) =================
titulo "Temperaturas"
if [ "$PLATFORM" = "linux" ]; then
  if ! cmd sensors; then
    printf "El comando 'sensors' no está instalado.\n"
    read -rp "¿Querés instalar el paquete de sensores? [s/N]: " resp
    if [[ "$resp" =~ ^[sS]$ ]]; then
      if ensure_root_for_install; then
        pm_update_linux || true
        case "$LINUX_DISTRO" in
          debian|arch|suse|alpine) pkg="lm-sensors" ;;
          fedora)                   pkg="lm_sensors" ;;
          *)                        pkg="lm-sensors" ;;
        esac
        pm_install_linux "$pkg" || printf "No se pudo instalar %s.\n" "$pkg"
        if cmd sensors-detect; then
          printf "\nEjecutando 'sensors-detect' (podés responder YES a lo básico):\n"
          sensors-detect || true
        fi
      fi
    fi
  fi
  if cmd sensors; then sensors || true; else printf "Comando 'sensors' no disponible.\n"; fi

else # macOS
  if ! cmd osx-cpu-temp; then
    printf "Herramienta de temperatura en macOS no encontrada.\n"
    read -rp "¿Querés instalar 'osx-cpu-temp' con Homebrew? [s/N]: " rm
    if [[ "$rm" =~ ^[sS]$ ]]; then
      pm_install_macos osx-cpu-temp || printf "No se pudo instalar osx-cpu-temp.\n"
    fi
  fi
  if cmd osx-cpu-temp; then
    printf "CPU Temp:  %s\n" "$(osx-cpu-temp)"
  else
    printf "Podés instalar luego 'brew install osx-cpu-temp' para ver temperatura.\n"
  fi
fi

# ================= Batería =================
titulo "Batería"
if [ "$PLATFORM" = "linux" ]; then
  shown=false
  if cmd upower; then
    bat="$(upower -e | awk '/battery/ {print; exit}')"
    if [ -n "${bat:-}" ]; then
      upower -i "$bat" | awk -F: '
        /state|percentage|time to empty|time to full|energy|energy-full|capacity/ {
          gsub(/^[ \t]+/,"",$2); printf "%-14s %s\n",$1,$2
        }'
      shown=true
    fi
  fi
  if [ "$shown" = false ] && cmd acpi; then acpi -b || printf "Sin batería detectada.\n"; shown=true; fi
  if [ "$shown" = false ]; then
    printf "No hay herramientas de batería ('upower' o 'acpi').\n"
    read -rp "¿Querés instalar 'upower'? [s/N]: " rb
    if [[ "$rb" =~ ^[sS]$ ]]; then
      if ensure_root_for_install; then
        pm_update_linux || true
        pm_install_linux upower || printf "No se pudo instalar upower.\n"
        if cmd upower; then
          bat="$(upower -e | awk '/battery/ {print; exit}')"
          [ -n "${bat:-}" ] && upower -i "$bat" | awk -F: '
            /state|percentage|time to empty|time to full|energy|energy-full|capacity/ {
              gsub(/^[ \t]+/,"",$2); printf "%-14s %s\n",$1,$2
            }'
          shown=true
        fi
      fi
    fi
    if [ "$shown" = false ] && cmd acpi; then acpi -b || printf "Sin batería detectada.\n"; shown=true; fi
    [ "$shown" = false ] && printf "Sin datos de batería.\n"
  fi
else
  # macOS
  if cmd pmset; then
    pmset -g batt | sed '1d' || true
  else
    printf "No se puede leer batería (falta pmset).\n"
  fi
fi

# ================= Top procesos por RAM =================
titulo "Top 5 procesos por RAM"
ps -eo user:12,pid,%mem,%cpu,cmd --sort=-%mem | head -n 6

printf "\n%s\n" "$espaciado"
printf "%sFin del reporte.%s\n" "$c2" "$reset"
