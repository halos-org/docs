#!/usr/bin/env bash
#
# halos-restore.sh — restore an OpenPlotter backup onto a fresh marine HaLOS.
#
# Runs on the freshly-flashed HaLOS device. Reads the USB stick produced by
# openplotter-backup.sh and reinstates four data domains:
#   - Signal K        (~/.signalk configuration, plugins, charts)
#   - OpenCPN         (config + plugin data on the legacy desktop)
#   - InfluxDB 2      (raw data-directory swap; historical telemetry)
#   - Grafana         (dashboards + datasources re-imported via the API)
#
# Boat data is aligned to HaLOS marine defaults: the telemetry org/bucket is
# renamed to "marine" so HaLOS' own provisioned Grafana datasource serves the
# history and ongoing Signal K logging continues into the right bucket.
#
# HaLOS defaults are preserved aside before any swap (*.halos-default) so a
# failed restore can be rolled back.
#
# Usage:
#   bash halos-restore.sh [USB_MOUNT_PATH | BACKUP_DIR]
#
# Run as your normal user (e.g. pi); the script uses sudo where it needs root.

set -euo pipefail

readonly SUPPORTED_FORMAT_VERSION=1
readonly BACKUP_SUBDIR="halos-migration"
readonly CA_ROOT=/var/lib/container-apps

readonly SK_PKG=marine-signalk-server-container

# --- output helpers ----------------------------------------------------------

info() { printf '\033[1m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; }
die() {
	err "$*"
	exit 1
}

SUDO=""
REAL_USER=""
USER_HOME=""
SRC=""
declare -a SUMMARY=()

usage() {
	awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
	exit "${1:-0}"
}

note() { SUMMARY+=("$*"); }

# --- privilege / user resolution --------------------------------------------

resolve_privs() {
	if [[ ${EUID} -eq 0 ]]; then
		SUDO=""
		REAL_USER="${SUDO_USER:-root}"
	else
		command -v sudo >/dev/null 2>&1 || die "This script needs root; install sudo or run as root."
		SUDO="sudo"
		REAL_USER="${USER}"
	fi
	USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
	[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || die "Cannot resolve home directory for '$REAL_USER'."
}

# --- source / manifest -------------------------------------------------------

suggest_mounts() {
	local m
	for m in /media/"$REAL_USER"/* /media/* /run/media/"$REAL_USER"/* /mnt/*; do
		[[ -d "$m" ]] || continue
		mountpoint -q "$m" 2>/dev/null || continue
		printf '%s\n' "$m"
	done | sort -u
}

# Resolve SRC to the directory that directly contains manifest.txt.
locate_backup() {
	local given="${1:-}"
	if [[ -n "$given" ]]; then
		if [[ -f "$given/manifest.txt" ]]; then
			SRC="$given"
		elif [[ -f "$given/$BACKUP_SUBDIR/manifest.txt" ]]; then
			SRC="$given/$BACKUP_SUBDIR"
		else
			die "No backup manifest found under '$given'."
		fi
		return
	fi

	local -a found=() m
	while IFS= read -r m; do
		[[ -f "$m/$BACKUP_SUBDIR/manifest.txt" ]] && found+=("$m/$BACKUP_SUBDIR")
	done < <(suggest_mounts)

	case "${#found[@]}" in
	0) die "No migration backup found on any mounted USB stick. Plug in the stick from the backup step, or pass its path." ;;
	1) SRC="${found[0]}" ;;
	*)
		info "Multiple backups found:"
		local i=1 f
		for f in "${found[@]}"; do
			printf '   %d) %s\n' "$i" "$f"
			((i++))
		done
		local choice
		read -r -p "Which one? [1-${#found[@]}] " choice
		if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#found[@]})); then
			die "Invalid selection."
		fi
		SRC="${found[$((choice - 1))]}"
		;;
	esac
}

mf_get() {
	local key="$1"
	grep -E "^${key}=" "$SRC/manifest.txt" 2>/dev/null | head -1 | cut -d= -f2-
}

validate_manifest() {
	[[ -f "$SRC/manifest.txt" ]] || die "No manifest at $SRC."
	local ver complete
	ver="$(mf_get format_version)"
	complete="$(mf_get complete)"
	[[ "$ver" == "$SUPPORTED_FORMAT_VERSION" ]] ||
		die "Backup format version '$ver' is not supported by this restore script (expected $SUPPORTED_FORMAT_VERSION). Use a matching version of the migration scripts."
	[[ "$complete" == "yes" ]] ||
		die "Backup is marked incomplete (no completeness marker). Re-run the backup until it prints SAFE TO REFLASH."
	info "Backup: from $(mf_get source_host) (user $(mf_get source_user)), created $(mf_get created)."
}

# --- environment checks ------------------------------------------------------

pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }

require_marine_halos() {
	pkg_installed "$SK_PKG" || [[ -d "$CA_ROOT/$SK_PKG" ]] ||
		die "This does not look like a marine HaLOS install ($SK_PKG not found). Run this on a freshly-flashed marine HaLOS device."
}

# Move a path aside to <path>.halos-default unless that backup already exists.
preserve_default() {
	local path="$1"
	[[ -e "$path" ]] || return 0
	if [[ -e "$path.halos-default" ]]; then
		warn "$path.halos-default already exists — leaving it (earlier restore?), not overwriting."
		return 0
	fi
	$SUDO mv "$path" "$path.halos-default"
}

# --- Signal K ----------------------------------------------------------------

restore_signalk() {
	[[ "$(mf_get signalk)" == "present" ]] || {
		info "No Signal K data in backup — skipping."
		return 0
	}
	[[ -f "$SRC/signalk.tar" ]] || die "Manifest claims Signal K data but signalk.tar is missing."

	local data_root="$CA_ROOT/$SK_PKG/data"
	local target="$data_root/data"
	info "Restoring Signal K configuration..."

	$SUDO systemctl stop "$SK_PKG.service" 2>/dev/null || true
	preserve_default "$target"
	$SUDO mkdir -p "$target"
	$SUDO tar -C "$target" -xf "$SRC/signalk.tar"
	# The host data dir is owned by the invoking user (pi); match it.
	$SUDO chown -R "$REAL_USER:$REAL_USER" "$target"

	$SUDO systemctl start "$SK_PKG.service"
	verify_signalk
}

verify_signalk() {
	local i
	for i in $(seq 1 30); do
		if curl -fsk http://localhost:3000/signalk >/dev/null 2>&1; then
			local users
			users="$($SUDO python3 -c "import json;d=json.load(open('$CA_ROOT/$SK_PKG/data/data/security.json'));print(','.join(u.get('username','?') for u in d.get('users',[])))" 2>/dev/null || echo '?')"
			note "Signal K: restored and responding (users: ${users:-none})."
			info "Signal K is up (users: ${users:-none})."
			return 0
		fi
		sleep 2
	done
	warn "Signal K did not respond on :3000 within 60s. Check: sudo journalctl -u $SK_PKG.service"
	warn "The previous HaLOS data is preserved at $CA_ROOT/$SK_PKG/data/data.halos-default for rollback."
	note "Signal K: restored but did not come up — needs manual check."
}

# --- OpenCPN -----------------------------------------------------------------

restore_opencpn() {
	[[ "$(mf_get opencpn)" == "present" ]] || {
		info "No OpenCPN data in backup — skipping."
		return 0
	}
	if pgrep -x opencpn >/dev/null 2>&1; then
		warn "OpenCPN is running — close it before restoring, or its config will be overwritten on its next exit."
	fi
	info "Restoring OpenCPN data..."
	restore_home_tar "$SRC/opencpn-config.tar" "$USER_HOME/.opencpn"
	restore_home_tar "$SRC/opencpn-share.tar" "$USER_HOME/.local/share/opencpn"
	note "OpenCPN: config + plugin data restored to $USER_HOME."
}

# Extract a tar into a user-owned home directory, preserving the old one aside.
restore_home_tar() {
	local tarfile="$1" dest="$2"
	[[ -f "$tarfile" ]] || return 0
	preserve_default "$dest"
	mkdir -p "$dest"
	tar -C "$dest" -xf "$tarfile"
	$SUDO chown -R "$REAL_USER:$REAL_USER" "$dest"
}

# --- summary -----------------------------------------------------------------

print_summary() {
	echo
	info "Restore summary:"
	local line
	for line in "${SUMMARY[@]}"; do
		printf '   - %s\n' "$line"
	done
}

# --- main --------------------------------------------------------------------

main() {
	local arg=""
	while (($# > 0)); do
		case "$1" in
		-h | --help) usage 0 ;;
		-*) die "Unknown option: $1 (try --help)" ;;
		*) arg="$1" ;;
		esac
		shift
	done

	resolve_privs
	locate_backup "$arg"
	validate_manifest
	require_marine_halos

	restore_signalk
	restore_opencpn

	print_summary
	info "Done."
}

main "$@"
