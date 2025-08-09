System Information Script

Overview

This Bash script collects and displays detailed information about the system, including:

Operating System and Kernel

Uptime and Load Average

CPU model and core count

RAM usage

Disk usage

Network configuration (IPs, default route)

Graphics hardware

Temperatures (via lm-sensors on Linux or osx-cpu-temp on macOS)

Battery status (via upower/acpi on Linux or pmset on macOS)

Top 5 processes by RAM usage

The script supports Linux (Debian/Ubuntu, Fedora/RHEL, Arch, Alpine, openSUSE) and macOS.If a required package is missing, it will prompt the user to install it using the appropriate package manager (apt, dnf, pacman, apk, zypper, or brew).

Features

Cross-platform support for Linux and macOS.

Automatic distribution detection for Linux.

Interactive installation of missing dependencies.

Clean and color-coded output (when run in a TTY).

Root check before installing packages.

Safe Bash scripting practices (set -euo pipefail, quoting, command existence checks).

Works without breaking if a command is unavailable.

Requirements

Bash (v4+ recommended)

Internet access (for installing missing packages)

Supported OS:

macOS (Homebrew optional)

Linux: Debian/Ubuntu, Fedora/RHEL, Arch, Alpine, openSUSE

Optional Dependencies

Installed on demand if missing:

Linux:

lm-sensors (lm_sensors on Fedora) – for CPU/GPU temperature.

upower or acpi – for battery information.

macOS:

Homebrew – required for installing optional tools.

osx-cpu-temp – for CPU temperature.

Installation

Download or copy the script to your machine:

curl -O https://example.com/sistinfo.sh

Make it executable:

chmod +x sistinfo.sh

(Optional) Move it to a directory in your $PATH:

sudo mv sistinfo.sh /usr/local/bin/sistinfo

Usage

Run directly:

./sistinfo.sh

Or from anywhere (if installed in $PATH):

sistinfo

Example Output

System Information (linux/debian)
============================================================
SO and Kernel
SO:        Ubuntu 22.04.5 LTS
Kernel:    6.8.0-41-generic
Hostname:  mymachine

Uptime and Load
Uptime:    up 3 hours, 20 minutes
Load avg:  0.45 0.50 0.48

CPU
Model:     Intel(R) Core(TM) i7-10750H CPU @ 2.60GHz
Cores:     12

...
============================================================
End of report.

Notes

For temperature readings, if you choose to install lm-sensors on Linux, you may be prompted by sensors-detect to confirm detection of specific chips. Answer YES to basic safe prompts.

On macOS, temperature requires brew install osx-cpu-temp.

The script is safe to run without root; however, installing missing packages requires root/admin privileges.

Do you want me to also make a shorter version of this README for GitHub’s top description so it’s cleaner? That way the long details go in the file and the repo looks sharp.
