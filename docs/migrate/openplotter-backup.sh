#!/usr/bin/env bash
#
# openplotter-backup.sh — back up an OpenPlotter (Raspberry Pi OS) marine setup
# to a USB stick, in preparation for an in-place reflash to HaLOS.
#
# Runs on the LIVE OpenPlotter system. Copies four data domains to a USB stick:
#   - Signal K        (~/.signalk, minus node_modules and raw logs)
#   - InfluxDB 2      (/var/lib/influxdb, raw data directory)
#   - Grafana         (/var/lib/grafana/grafana.db, dashboards + datasources)
#   - OpenCPN         (~/.opencpn and ~/.local/share/opencpn)
#
# Each domain is stored as a tar archive so ownership and permissions survive
# even on a FAT/exFAT stick. The companion halos-restore.sh reinstates them on
# the freshly-flashed HaLOS device.
#
# IMPORTANT: this backs up ONLY the four migration domains above — it is NOT a
# full-system backup. In-place migration wipes the device, so save anything else
# you care about (personal files, charts outside ~/.opencpn, custom /etc config,
# apps you installed yourself) separately before reflashing. The script proves
# only that the migration backup itself is complete; it cannot vouch for the
# rest of your disk.
#
# Usage:
#   bash openplotter-backup.sh [--force] [--user NAME] [USB_MOUNT_PATH]
#
# Run as your normal user (e.g. pi); the script uses sudo where it needs root.

set -euo pipefail

readonly MANIFEST_FORMAT_VERSION=1
readonly BACKUP_SUBDIR="halos-migration"
readonly FAT_FILE_LIMIT=$((4 * 1024 * 1024 * 1024)) # 4 GiB per-file cap on FAT32

# --- output helpers ----------------------------------------------------------

info() { printf '\033[1m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[31m[x]\033[0m %s\n' "$*" >&2; }
die() {
	err "$*"
	exit 1
}

# --- globals populated during run -------------------------------------------

SUDO=""
REAL_USER=""
USER_HOME=""
DEST_ROOT=""
DEST=""
FORCE=0
declare -a STOPPED_SERVICES=()
SERVICES_RESTARTED=0
SUCCESS=0

usage() {
	# Print the leading comment block (everything after the shebang up to the
	# first non-comment line), stripped of the leading "# ".
	awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
	exit "${1:-0}"
}

# Restart any services we stopped, on any exit path. Runs via EXIT trap so an
# interrupted or failed backup never leaves the user's system dark.
cleanup() {
	local rc=$?
	if ((SERVICES_RESTARTED == 0)) && ((${#STOPPED_SERVICES[@]} > 0)); then
		info "Restarting services on the source system..."
		start_services
	fi
	if ((rc != 0)) && ((SUCCESS == 0)); then
		err "Backup did NOT complete. Do not reflash — the backup is incomplete."
	fi
	return $rc
}

# --- privilege / user resolution --------------------------------------------

resolve_user() {
	local want="${1:-}"
	if [[ -n "$want" ]]; then
		REAL_USER="$want"
	elif [[ ${EUID} -eq 0 ]]; then
		if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
			REAL_USER="${SUDO_USER}"
		else
			die "Run as your normal user (not root), or pass --user NAME so I know whose ~/.signalk and ~/.opencpn to back up."
		fi
	else
		REAL_USER="${USER}"
	fi

	USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
	[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || die "Cannot resolve home directory for user '$REAL_USER'."

	# Privileged operations (service control, reading /var/lib) need root.
	if [[ ${EUID} -eq 0 ]]; then
		SUDO=""
	elif command -v sudo >/dev/null 2>&1; then
		SUDO="sudo"
	else
		die "This script needs root for some steps but sudo is not available. Re-run as root with --user $REAL_USER."
	fi
}

# --- USB target selection ----------------------------------------------------

# Suggest mounted removable filesystems under the usual auto-mount roots.
suggest_usb_mounts() {
	local m
	for m in /media/"$REAL_USER"/* /media/* /run/media/"$REAL_USER"/* /mnt/*; do
		[[ -d "$m" ]] || continue
		mountpoint -q "$m" 2>/dev/null || continue
		printf '%s\n' "$m"
	done | sort -u
}

select_dest_root() {
	local given="${1:-}"
	if [[ -n "$given" ]]; then
		[[ -d "$given" ]] || die "USB path '$given' does not exist."
		mountpoint -q "$given" 2>/dev/null || warn "'$given' is not a mount point — make sure your USB stick is actually mounted there."
		DEST_ROOT="$given"
		return
	fi

	local -a candidates=()
	mapfile -t candidates < <(suggest_usb_mounts)
	if ((${#candidates[@]} == 0)); then
		die "No mounted USB stick found. Insert and mount a stick, then re-run — or pass the mount path explicitly: bash $0 /media/$REAL_USER/MYSTICK"
	fi

	info "Detected these mounted removable filesystems:"
	local i=1 c
	for c in "${candidates[@]}"; do
		printf '   %d) %s (%s free)\n' "$i" "$c" "$(human_free "$c")"
		((i++))
	done

	local choice
	read -r -p "Which one is your backup USB stick? [1-${#candidates[@]}] " choice
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#candidates[@]})); then
		die "Invalid selection."
	fi
	DEST_ROOT="${candidates[$((choice - 1))]}"
}

human_free() {
	df -h --output=avail "$1" 2>/dev/null | tail -1 | tr -d ' '
}

fs_type() {
	df -T "$1" 2>/dev/null | awk 'NR==2 {print $2}'
}

avail_bytes() {
	# df -B1 reports available bytes in the 4th column.
	df -B1 --output=avail "$1" 2>/dev/null | tail -1 | tr -d ' '
}

# --- size measurement / preflight -------------------------------------------

dir_bytes() {
	# Sum of a path's apparent size in bytes, 0 if absent.
	local path="$1"
	[[ -e "$path" ]] || {
		echo 0
		return
	}
	$SUDO du -sb "$path" 2>/dev/null | cut -f1
}

SK_BYTES=0
INFLUX_BYTES=0
GRAFANA_BYTES=0
OPENCPN_CONF_BYTES=0
OPENCPN_SHARE_BYTES=0
OPENCPN_BYTES=0

measure_sources() {
	info "Measuring source data..."
	[[ -d "$USER_HOME/.signalk" ]] && SK_BYTES="$(dir_bytes "$USER_HOME/.signalk")"
	[[ -d /var/lib/influxdb ]] && INFLUX_BYTES="$(dir_bytes /var/lib/influxdb)"
	[[ -f /var/lib/grafana/grafana.db ]] && GRAFANA_BYTES="$(dir_bytes /var/lib/grafana/grafana.db)"
	OPENCPN_CONF_BYTES="$(dir_bytes "$USER_HOME/.opencpn")"
	OPENCPN_SHARE_BYTES="$(dir_bytes "$USER_HOME/.local/share/opencpn")"
	OPENCPN_BYTES=$((OPENCPN_CONF_BYTES + OPENCPN_SHARE_BYTES))
}

preflight() {
	local total=$((SK_BYTES + INFLUX_BYTES + GRAFANA_BYTES + OPENCPN_BYTES))
	((total > 0)) || die "Found none of Signal K, InfluxDB, Grafana or OpenCPN data on this system. Nothing to back up."

	local avail fstype
	avail="$(avail_bytes "$DEST_ROOT")"
	fstype="$(fs_type "$DEST_ROOT")"

	info "Source data total: $(bytes_to_h "$total"). USB free: $(human_free "$DEST_ROOT") (filesystem: ${fstype:-unknown})."

	# FAT32 cannot hold a single file larger than 4 GiB — the InfluxDB archive
	# is the one likely to exceed it. FUSE mounts (exFAT/NTFS drivers) report
	# "fuseblk", hiding the real filesystem; those usually have no 4 GiB limit,
	# so only warn.
	if ((INFLUX_BYTES > FAT_FILE_LIMIT)); then
		if [[ "$fstype" == "vfat" || "$fstype" == "msdos" ]]; then
			die "The USB stick is FAT32, which cannot store files larger than 4 GiB, but the InfluxDB data is $(bytes_to_h "$INFLUX_BYTES"). Reformat the stick as exFAT or ext4 and try again."
		elif [[ "$fstype" == "fuseblk" || -z "$fstype" ]]; then
			warn "Could not confirm the USB filesystem type (${fstype:-unknown}). If the stick is FAT32 it cannot hold the $(bytes_to_h "$INFLUX_BYTES") InfluxDB archive — should the backup fail mid-write, reformat as exFAT or ext4."
		fi
	fi

	# Require the stick to hold the data with a little headroom for tar overhead.
	local needed=$((total + total / 20 + 16 * 1024 * 1024))
	if [[ -n "$avail" ]] && ((avail < needed)); then
		die "USB stick is too small: needs about $(bytes_to_h "$needed") free, has $(human_free "$DEST_ROOT"). Use a larger stick."
	fi
}

bytes_to_h() {
	numfmt --to=iec --suffix=B "$1" 2>/dev/null || printf '%s bytes' "$1"
}

# --- service control ---------------------------------------------------------

# Echo the unit names that exist on this system among our known candidates,
# including any signalk* unit (OpenPlotter's exact name varies). signalk.socket
# is listed before signalk.service so it stops first — otherwise its socket
# activation (ListenStream=3000) would restart the server on the next client
# connection, mid-copy.
detect_services() {
	local known=(influxdb.service grafana-server.service signalk.socket signalk.service) u
	mapfile -t -O "${#known[@]}" known < <(
		systemctl list-unit-files --no-legend 'signalk*.service' 2>/dev/null | awk '{print $1}'
	)
	declare -A uniq=()
	for u in "${known[@]}"; do
		[[ -n "$u" ]] || continue
		[[ -n "${uniq[$u]:-}" ]] && continue
		uniq[$u]=1
		if $SUDO systemctl list-unit-files "$u" >/dev/null 2>&1 ||
			$SUDO systemctl is-active --quiet "$u" 2>/dev/null; then
			printf '%s\n' "$u"
		fi
	done
}

stop_services() {
	local -a units=()
	mapfile -t units < <(detect_services)
	local u
	for u in "${units[@]}"; do
		if $SUDO systemctl is-active --quiet "$u" 2>/dev/null; then
			info "Stopping $u for a consistent copy..."
			$SUDO systemctl stop "$u"
			STOPPED_SERVICES+=("$u")
		fi
	done
}

# Restart in reverse stop order, so signalk.service comes up before its socket.
start_services() {
	local i u
	for ((i = ${#STOPPED_SERVICES[@]} - 1; i >= 0; i--)); do
		u="${STOPPED_SERVICES[$i]}"
		$SUDO systemctl start "$u" 2>/dev/null ||
			warn "Could not restart $u — start it manually with: sudo systemctl start $u"
	done
	SERVICES_RESTARTED=1
}

# --- backup ------------------------------------------------------------------

prepare_dest() {
	DEST="$DEST_ROOT/$BACKUP_SUBDIR"
	if [[ -e "$DEST" ]] && [[ -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
		((FORCE == 1)) ||
			die "A backup already exists at $DEST. Use --force to overwrite it, or pick an empty stick."
		warn "Overwriting existing backup at $DEST (--force)."
		rm -rf "${DEST:?}"/*
	fi
	mkdir -p "$DEST"
}

# tar a directory's contents (paths relative to the directory) into dest.
tar_dir() {
	local src="$1" out="$2"
	shift 2
	$SUDO tar --numeric-owner -C "$src" -cf "$out" "$@" .
}

backup_signalk() {
	((SK_BYTES > 0)) || {
		info "No Signal K data — skipping."
		return
	}
	info "Backing up Signal K ($(bytes_to_h "$SK_BYTES"))..."
	tar_dir "$USER_HOME/.signalk" "$DEST/signalk.tar" \
		--exclude=./node_modules --exclude='./skserver-raw_*.log'
}

backup_influxdb() {
	((INFLUX_BYTES > 0)) || {
		info "No InfluxDB data — skipping."
		return
	}
	info "Backing up InfluxDB ($(bytes_to_h "$INFLUX_BYTES")) — this is the big one, please wait..."
	tar_dir /var/lib/influxdb "$DEST/influxdb2.tar"
}

backup_grafana() {
	((GRAFANA_BYTES > 0)) || {
		info "No Grafana database — skipping."
		return
	}
	info "Backing up Grafana dashboards..."
	$SUDO cp "/var/lib/grafana/grafana.db" "$DEST/grafana.db"
	# The DB holds datasource secrets; keep it owner-only for the user, who
	# reads it without root on the restore side. No-op on FAT sticks.
	$SUDO chown "$REAL_USER" "$DEST/grafana.db" 2>/dev/null || true
	$SUDO chmod 600 "$DEST/grafana.db" 2>/dev/null || true
}

backup_opencpn() {
	((OPENCPN_BYTES > 0)) || {
		info "No OpenCPN data — skipping."
		return
	}
	info "Please make sure OpenCPN is CLOSED (it writes its config on exit)."
	local ans
	read -r -p "Is OpenCPN closed? [y/N] " ans
	[[ "$ans" =~ ^[Yy]$ ]] || die "Close OpenCPN and re-run."
	if ((OPENCPN_CONF_BYTES > 0)); then
		info "Backing up OpenCPN config..."
		tar_dir "$USER_HOME/.opencpn" "$DEST/opencpn-config.tar"
		warn_relocated_charts
	fi
	if ((OPENCPN_SHARE_BYTES > 0)); then
		info "Backing up OpenCPN plugin data..."
		tar_dir "$USER_HOME/.local/share/opencpn" "$DEST/opencpn-share.tar"
	fi
}

# Charts stored outside ~/.opencpn (user-chosen folders) are not captured.
warn_relocated_charts() {
	local conf="$USER_HOME/.opencpn/opencpn.conf"
	[[ -f "$conf" ]] || return 0
	local dirs
	dirs="$(grep -a -i 'ChartDir' "$conf" 2>/dev/null | grep -av "$USER_HOME/.opencpn" || true)"
	if [[ -n "$dirs" ]]; then
		warn "OpenCPN references chart folders outside ~/.opencpn. These are NOT backed up automatically:"
		printf '%s\n' "$dirs" | sed 's/^/      /' >&2
		warn "Copy those chart folders to your USB stick manually if you need them."
	fi
}

# --- manifest + verification -------------------------------------------------

present() { (($1 > 0)) && echo present || echo absent; }

write_manifest() {
	local mf="$DEST/manifest.txt"
	{
		echo "format_version=$MANIFEST_FORMAT_VERSION"
		echo "created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
		echo "source_host=$(hostname)"
		echo "source_user=$REAL_USER"
		echo "signalk=$(present "$SK_BYTES")"
		echo "signalk_bytes=$SK_BYTES"
		echo "influxdb=$(present "$INFLUX_BYTES")"
		echo "influxdb_bytes=$INFLUX_BYTES"
		echo "grafana=$(present "$GRAFANA_BYTES")"
		echo "grafana_bytes=$GRAFANA_BYTES"
		echo "opencpn=$(present "$OPENCPN_BYTES")"
		echo "opencpn_bytes=$OPENCPN_BYTES"
	} >"$mf"
}

# Confirm each present domain produced a non-empty artifact, and that the
# InfluxDB archive actually contains both the boltdb (metadata) and the
# engine/ tree (the time-series data itself) at a plausible size.
verify_backup() {
	info "Verifying backup integrity..."
	# Flush the archives to disk first so the read-backs below validate
	# persisted data, not the page cache.
	sync
	local ok=1

	check_artifact() {
		local label="$1" path="$2"
		if [[ ! -s "$path" ]]; then
			err "Missing or empty: $label ($path)"
			ok=0
		fi
	}

	((SK_BYTES > 0)) && check_artifact "Signal K" "$DEST/signalk.tar"
	((GRAFANA_BYTES > 0)) && check_artifact "Grafana" "$DEST/grafana.db"
	((OPENCPN_CONF_BYTES > 0)) && check_artifact "OpenCPN config" "$DEST/opencpn-config.tar"
	((OPENCPN_SHARE_BYTES > 0)) && check_artifact "OpenCPN share" "$DEST/opencpn-share.tar"

	if ((INFLUX_BYTES > 0)); then
		check_artifact "InfluxDB" "$DEST/influxdb2.tar"
		if [[ -s "$DEST/influxdb2.tar" ]]; then
			local listing
			listing="$(tar -tf "$DEST/influxdb2.tar" 2>/dev/null)" || listing=""
			if ! grep -q 'influxd\.bolt' <<<"$listing"; then
				err "InfluxDB archive is missing influxd.bolt — the data is incomplete."
				ok=0
			fi
			# The boltdb is only metadata; the history lives under engine/.
			if [[ -d /var/lib/influxdb/engine ]] && ! grep -q '^\./engine/' <<<"$listing"; then
				err "InfluxDB archive is missing the engine/ data directory — the telemetry history is NOT in the backup."
				ok=0
			fi
			local tar_size
			tar_size="$(stat -c %s "$DEST/influxdb2.tar" 2>/dev/null || echo 0)"
			if ((tar_size < INFLUX_BYTES / 2)); then
				err "InfluxDB archive ($(bytes_to_h "$tar_size")) is far smaller than the measured source data ($(bytes_to_h "$INFLUX_BYTES")) — it looks truncated."
				ok=0
			fi
		fi
	fi

	((ok == 1)) || die "Verification failed. The backup is NOT safe to rely on."

	# The completeness marker: only written once everything checks out.
	echo "complete=yes" >>"$DEST/manifest.txt"
	sync
}

# --- main --------------------------------------------------------------------

main() {
	local user_arg="" dest_arg=""
	while (($# > 0)); do
		case "$1" in
		-h | --help) usage 0 ;;
		--force) FORCE=1 ;;
		--user)
			shift
			user_arg="${1:-}"
			[[ -n "$user_arg" ]] || die "--user needs a name."
			;;
		-*) die "Unknown option: $1 (try --help)" ;;
		*) dest_arg="$1" ;;
		esac
		shift
	done

	resolve_user "$user_arg"
	trap cleanup EXIT

	info "HaLOS migration backup — source user: $REAL_USER"
	select_dest_root "$dest_arg"
	measure_sources
	preflight
	prepare_dest

	stop_services

	backup_signalk
	backup_influxdb
	backup_grafana
	backup_opencpn

	write_manifest
	verify_backup

	start_services

	SUCCESS=1
	echo
	info "Migration backup written to: $DEST"
	printf '\033[1;32m========================================\n'
	printf '  MIGRATION BACKUP COMPLETE AND VERIFIED\n'
	printf '========================================\033[0m\n'
	echo "Signal K, InfluxDB, Grafana and OpenCPN are backed up and verified"
	echo "on the USB stick."
	echo
	warn "This is NOT a full-system backup. Personal files, charts stored"
	warn "outside ~/.opencpn, custom /etc configuration and any apps you"
	warn "installed yourself are NOT included — copy those to the stick now if"
	warn "you need them."
	echo
	warn "The backup contains credentials (Signal K user accounts, Grafana and"
	warn "InfluxDB secrets). Treat the stick as sensitive and wipe it once the"
	warn "migration is done."
	echo
	echo "Once you have also saved anything else you care about, you can"
	echo "reflash. Keep the stick safe through the reflash, then run"
	echo "halos-restore.sh on the new HaLOS system to restore your data."
}

main "$@"
