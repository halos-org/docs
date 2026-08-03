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
readonly INFLUX_PKG=marine-influxdb-container
readonly GRAFANA_PKG=marine-grafana-container
readonly INFLUX_CONTAINER=influxdb
readonly GRAFANA_CONTAINER=grafana

# Image used for `influxd recovery` runs against the boat boltdb. Overridden
# with whatever image the installed influxdb container actually runs, so the
# recovery tooling always matches the server HaLOS ships.
INFLUX_IMG=influxdb:2.9.1

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
PENDING_RESTART=""
declare -a SUMMARY=()

# A restore step stops a service, swaps data, and starts it again. If the
# script dies inside that window, restart the service so a failed restore
# never leaves the system dark, and point at the rollback copies.
on_exit() {
	local rc=$?
	if ((rc != 0)); then
		if [[ -n "$PENDING_RESTART" ]]; then
			warn "Restarting $PENDING_RESTART after the failed restore step..."
			$SUDO systemctl start --no-block "$PENDING_RESTART" 2>/dev/null ||
				warn "Could not restart $PENDING_RESTART — start it manually: sudo systemctl start $PENDING_RESTART"
		fi
		err "Restore did not complete. Any data directory already swapped keeps its fresh HaLOS copy beside it as *.halos-default; after fixing the reported problem it is safe to re-run this script."
	fi
	return $rc
}

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
		die "Backup is marked incomplete (no completeness marker). Re-run the backup until it prints MIGRATION BACKUP COMPLETE AND VERIFIED."
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
	PENDING_RESTART="$SK_PKG.service"
	preserve_default "$target"
	$SUDO mkdir -p "$target"
	$SUDO tar -C "$target" -xf "$SRC/signalk.tar"
	# The host data dir is owned by the invoking user (pi); match it.
	$SUDO chown -R "$REAL_USER:$REAL_USER" "$target"

	# --no-block: Signal K is ordered behind a provisioning one-shot that has no
	# start timeout, so a blocking start hangs the restore on a device that has
	# not provisioned since its last upgrade. verify_signalk polls for readiness.
	$SUDO systemctl start --no-block "$SK_PKG.service"
	PENDING_RESTART=""
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
	# 60s covers a start; it does not cover a provisioning run, which installs the
	# curated plugin set before the app may start and has no deadline of its own.
	# Reporting that as a failure would send the operator debugging a working device.
	local state
	state="$($SUDO systemctl is-active "$SK_PKG-provision.service" 2>/dev/null || true)"
	if [[ "$state" == "activating" || "$state" == "active" ]]; then
		info "Signal K is installing its plugin set before starting; on a slow link"
		info "this takes several minutes. Follow it with:"
		info "  sudo journalctl -fu $SK_PKG-provision.service"
		note "Signal K: restored, provisioning still running."
		return 0
	fi

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

# --- InfluxDB ----------------------------------------------------------------

ensure_pkg() {
	local pkg="$1"
	pkg_installed "$pkg" && return 0
	info "Installing $pkg..."
	$SUDO apt-get update -qq
	$SUDO apt-get install -y "$pkg" >/dev/null
}

# Ensure the package has run once so its data dir / env exist, then leave the
# service stopped for the swap.
init_then_stop_influx() {
	if [[ ! -d "$CA_ROOT/$INFLUX_PKG/data/db" || ! -f "/etc/container-apps/$INFLUX_PKG/env" ]]; then
		info "Letting InfluxDB initialize once..."
		$SUDO systemctl start "$INFLUX_PKG.service"
		wait_container_healthy "$INFLUX_CONTAINER" 60 || true
	fi
	# Run the recovery tooling with the same image as the installed server.
	local img
	img="$($SUDO docker inspect -f '{{.Config.Image}}' "$INFLUX_CONTAINER" 2>/dev/null || true)"
	[[ -n "$img" ]] && INFLUX_IMG="$img"
	$SUDO systemctl stop "$INFLUX_PKG.service" 2>/dev/null || true
	PENDING_RESTART="$INFLUX_PKG.service"
	$SUDO docker rm -f "$INFLUX_CONTAINER" >/dev/null 2>&1 || true
	ensure_influx_image
}

ensure_influx_image() {
	$SUDO docker image inspect "$INFLUX_IMG" >/dev/null 2>&1 && return 0
	info "Pulling $INFLUX_IMG for the InfluxDB recovery tooling..."
	$SUDO docker pull "$INFLUX_IMG" >/dev/null 2>&1 ||
		die "InfluxDB image $INFLUX_IMG is not available locally and could not be pulled. Connect the device to the internet and re-run."
}

wait_container_healthy() {
	local name="$1" timeout="${2:-60}" i
	for i in $(seq 1 "$timeout"); do
		[[ "$($SUDO docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null)" == healthy ]] && return 0
		sleep 1
	done
	return 1
}

# Mint a fresh operator token from the swapped-in boltdb (server must be down).
# Echoes three lines: username, org name, token.
mint_operator_token() {
	local db="$1" user org out token
	user="$(recovery_list "$db" user)"
	org="$(recovery_list "$db" org)"
	[[ -n "$user" && -n "$org" ]] || die "Could not read a user/org from the boat InfluxDB boltdb."
	out="$($SUDO docker run --rm -v "$db:/var/lib/influxdb2" "$INFLUX_IMG" \
		influxd recovery auth create-operator --username "$user" --org "$org" \
		--bolt-path /var/lib/influxdb2/influxd.bolt 2>/dev/null)"
	token="$(printf '%s\n' "$out" | grep -oE '[A-Za-z0-9_-]{80,}={0,2}' | head -1)"
	[[ -n "$token" ]] || die "Failed to mint an InfluxDB operator token from the boltdb."
	printf '%s\n%s\n%s\n' "$user" "$org" "$token"
}

# First data row's Name from `influxd recovery <kind> list` (server down).
# The output is "<ID> <Name>"; the name is everything after the ID so names
# containing spaces survive.
recovery_list() {
	local db="$1" kind="$2"
	$SUDO docker run --rm -v "$db:/var/lib/influxdb2" "$INFLUX_IMG" \
		influxd recovery "$kind" list --bolt-path /var/lib/influxdb2/influxd.bolt 2>/dev/null |
		awk 'NR>1 && NF>=2 {sub(/^[^ \t]+[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit}'
}

iexec() { $SUDO docker exec "$INFLUX_CONTAINER" influx "$@"; }

restore_influxdb() {
	[[ "$(mf_get influxdb)" == "present" ]] || {
		info "No InfluxDB data in backup — skipping."
		return 0
	}
	[[ -f "$SRC/influxdb2.tar" ]] || die "Manifest claims InfluxDB data but influxdb2.tar is missing."

	ensure_pkg "$INFLUX_PKG"
	init_then_stop_influx

	local db="$CA_ROOT/$INFLUX_PKG/data/db"
	info "Swapping in boat InfluxDB data (this can take a while for large datasets)..."
	preserve_default "$db"
	$SUDO mkdir -p "$db"
	$SUDO tar -C "$db" -xf "$SRC/influxdb2.tar"
	mirror_default_ownership "$db"

	info "Minting a fresh operator token from the boat database..."
	local creds user org token
	creds="$(mint_operator_token "$db")"
	{
		read -r user
		read -r org
		read -r token
	} <<<"$creds"
	[[ -n "$user" && -n "$org" && -n "$token" ]] || die "Could not parse the minted InfluxDB credentials."

	inject_influx_token "$token"

	info "Starting InfluxDB with the boat data..."
	$SUDO systemctl start "$INFLUX_PKG.service"
	PENDING_RESTART=""
	wait_container_healthy "$INFLUX_CONTAINER" 90 ||
		die "InfluxDB did not become healthy with the restored data. Default preserved at $db.halos-default. Check: sudo journalctl -u $INFLUX_PKG.service -e"

	align_to_marine "$org" "$token"
	note "InfluxDB: boat data restored (source user '$user', org '$org' renamed to 'marine')."
}

mirror_default_ownership() {
	local db="$1" ref="$1.halos-default" owner mode
	if [[ -e "$ref" ]]; then
		owner="$($SUDO stat -c '%U:%G' "$ref")"
		mode="$($SUDO stat -c '%a' "$ref")"
	else
		owner="$REAL_USER:root"
		mode=700
	fi
	$SUDO chown -R "$owner" "$db"
	$SUDO chmod "$mode" "$db"
}

inject_influx_token() {
	local token="$1" env="/etc/container-apps/$INFLUX_PKG/env"
	[[ -f "$env" ]] || die "InfluxDB env file $env not found."
	[[ -e "$env.halos-default" ]] || $SUDO cp "$env" "$env.halos-default"
	if $SUDO grep -q '^INFLUXDB_ADMIN_TOKEN=' "$env"; then
		$SUDO sed -i "s|^INFLUXDB_ADMIN_TOKEN=.*|INFLUXDB_ADMIN_TOKEN=$token|" "$env"
	else
		printf 'INFLUXDB_ADMIN_TOKEN=%s\n' "$token" | $SUDO tee -a "$env" >/dev/null
	fi
}

# Rename the telemetry org+bucket to "marine" so HaLOS' provisioned datasource
# serves the history, and add a v1 DBRP for InfluxQL/Grafana compatibility.
align_to_marine() {
	local org="$1" token="$2"
	wait_influx_ready "$token"

	local org_id buck
	org_id="$(iexec org list --token "$token" --json 2>/dev/null |
		ORG_NAME="$org" python3 -c '
import json, os, sys
try:
    orgs = json.load(sys.stdin)
except Exception:
    orgs = []
print(next((o["id"] for o in orgs if o.get("name") == os.environ["ORG_NAME"]), ""))
')"
	buck="$(select_telemetry_bucket "$org" "$token")"
	local buck_id="${buck%%$'\t'*}" buck_name="${buck#*$'\t'}"
	[[ -n "$org_id" && -n "$buck_id" ]] || die "Could not resolve org/bucket ids for the rename."

	if [[ "$org" != marine ]]; then
		iexec org update --id "$org_id" --name marine --token "$token" >/dev/null 2>&1 ||
			warn "Could not rename org '$org' to 'marine' (already taken?). HaLOS' default datasource may not resolve the data."
	fi
	if [[ "$buck_name" != marine ]]; then
		iexec bucket update --id "$buck_id" --name marine --token "$token" >/dev/null 2>&1 ||
			warn "Could not rename bucket '$buck_name' to 'marine'."
	fi
	iexec v1 dbrp create --bucket-id "$buck_id" --db marine --rp autogen --default \
		--org marine --token "$token" >/dev/null 2>&1 ||
		warn "Could not create the marine/autogen DBRP (may already exist)."

	smoke_query "$token"
}

wait_influx_ready() {
	local token="$1" i
	for i in $(seq 1 30); do
		iexec org list --token "$token" >/dev/null 2>&1 && return 0
		sleep 2
	done
	die "InfluxDB is up but not answering authenticated queries with the minted token."
}

# Echo "<id>\t<name>" of the telemetry bucket, prompting if more than one
# exists. JSON output keeps bucket names with spaces intact.
select_telemetry_bucket() {
	local org="$1" token="$2"
	local -a buckets=()
	mapfile -t buckets < <(iexec bucket list --org "$org" --token "$token" --json 2>/dev/null |
		python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    rows = []
for b in rows:
    name = b.get("name", "")
    if name and not name.startswith("_"):
        print(b["id"] + "\t" + name)
')
	case "${#buckets[@]}" in
	0) die "No data buckets found in the boat InfluxDB." ;;
	1) printf '%s' "${buckets[0]}" ;;
	*)
		warn "Multiple buckets found — choose the main telemetry bucket to map to 'marine':" >&2
		local i=1 b
		for b in "${buckets[@]}"; do
			printf '   %d) %s\n' "$i" "${b#*$'\t'}" >&2
			((i++))
		done
		local choice
		read -r -p "Bucket to rename to 'marine' [1-${#buckets[@]}] " choice
		if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#buckets[@]})); then
			die "Invalid selection."
		fi
		printf '%s' "${buckets[$((choice - 1))]}"
		;;
	esac
}

smoke_query() {
	local token="$1" out
	out="$(iexec query 'from(bucket:"marine") |> range(start:-520w) |> first()' \
		--org marine --token "$token" 2>/dev/null | grep -c _value || true)"
	if (( ${out:-0} > 0 )); then
		info "Smoke test passed: historical telemetry is queryable in the 'marine' bucket."
	else
		warn "Smoke test returned no rows — the bucket may be empty or queries need a wider range."
	fi
}

# --- Grafana -----------------------------------------------------------------

grafana_ip() {
	$SUDO docker inspect "$GRAFANA_CONTAINER" \
		-f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null
}

restore_grafana() {
	[[ "$(mf_get grafana)" == "present" ]] || {
		info "No Grafana data in backup — skipping."
		return 0
	}
	[[ -f "$SRC/grafana.db" ]] || {
		warn "Manifest claims Grafana data but grafana.db is missing — skipping dashboards."
		return 0
	}
	# The minted token lets the boat datasource authenticate against the new data.
	local token
	token="$($SUDO grep -E '^INFLUXDB_ADMIN_TOKEN=' "/etc/container-apps/$INFLUX_PKG/env" 2>/dev/null | cut -d= -f2-)"
	[[ -n "$token" ]] || {
		warn "Could not read the InfluxDB token from /etc/container-apps/$INFLUX_PKG/env — skipping dashboard import. You can redo it manually later; your data is still available via HaLOS' built-in marine dashboards."
		note "Grafana: import skipped — InfluxDB token missing."
		return 0
	}

	ensure_pkg "$GRAFANA_PKG"
	$SUDO systemctl start "$GRAFANA_PKG.service" 2>/dev/null || true
	wait_container_healthy "$GRAFANA_CONTAINER" 60 || true

	local ip
	ip="$(grafana_ip)"
	[[ -n "$ip" ]] || {
		warn "Could not find the Grafana container IP — skipping dashboard import. Your data is still available via HaLOS' built-in marine dashboards."
		return 0
	}

	info "Importing boat dashboards and datasources into Grafana..."
	import_grafana "$SRC/grafana.db" "http://$ip:3000" "$token" || {
		warn "Grafana import did not fully succeed. Your historical data is still available via HaLOS' built-in marine dashboards."
		note "Grafana: import incomplete — see warnings above."
		return 0
	}
	note "Grafana: boat dashboards and datasources imported."
}

# Re-create boat InfluxDB datasources (preserving UID, injecting the minted
# token) and import boat dashboards via the Grafana HTTP API.
import_grafana() {
	local db="$1" url="$2" token="$3"
	GRAFANA_URL="$url" GRAFANA_DB="$db" INFLUX_TOKEN="$token" \
		python3 - <<'PY'
import json, os, sqlite3, urllib.request, urllib.error, base64

url = os.environ["GRAFANA_URL"].rstrip("/")
db = os.environ["GRAFANA_DB"]
token = os.environ.get("INFLUX_TOKEN", "")
auth = base64.b64encode(b"admin:admin").decode()

def call(method, path, payload):
    req = urllib.request.Request(
        url + path, data=json.dumps(payload).encode(),
        method=method,
        headers={"Content-Type": "application/json",
                 "Authorization": "Basic " + auth})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 0, str(e)

con = sqlite3.connect(db)
con.row_factory = sqlite3.Row

ds_ok = ds_fail = auth_fail = 0
for row in con.execute("SELECT uid,name,type,access,database,json_data FROM data_source"):
    if (row["type"] or "") != "influxdb":
        continue
    jd = json.loads(row["json_data"] or "{}")
    jd.setdefault("httpMode", "POST")
    jd.setdefault("httpHeaderName1", "Authorization")
    payload = {
        "uid": row["uid"], "name": row["name"], "type": "influxdb",
        "access": row["access"] or "proxy", "url": "http://influxdb:8086",
        "database": row["database"], "jsonData": jd, "isDefault": False,
        "secureJsonData": {"httpHeaderValue1": "Token " + token},
    }
    st, _ = call("POST", "/api/datasources", payload)
    if st == 409:  # already exists -> not fatal
        ds_ok += 1
    elif 200 <= st < 300:
        ds_ok += 1
    else:
        if st in (401, 403):
            auth_fail += 1
        ds_fail += 1

dash_ok = dash_fail = 0
# Older Grafana stores dashboards as JSON in dashboard.data (is_folder=0).
# Newer Grafana uses a different store and leaves this empty/absent; in that
# case we simply import nothing — HaLOS ships its own marine dashboards.
try:
    rows = con.execute("SELECT data FROM dashboard WHERE is_folder=0").fetchall()
except sqlite3.OperationalError:
    rows = []
    print("note: this Grafana version does not expose dashboards in dashboard.data")
for row in rows:
    try:
        model = json.loads(row["data"])
    except Exception:
        dash_fail += 1
        continue
    model["id"] = None
    st, _ = call("POST", "/api/dashboards/db",
                 {"dashboard": model, "overwrite": True,
                  "message": "Restored from OpenPlotter backup"})
    if 200 <= st < 300:
        dash_ok += 1
    else:
        if st in (401, 403):
            auth_fail += 1
        dash_fail += 1

print(f"datasources: {ds_ok} ok, {ds_fail} failed; dashboards: {dash_ok} ok, {dash_fail} failed")
if auth_fail:
    print("note: Grafana rejected the default admin credentials — this HaLOS "
          "Grafana does not accept admin:admin, so the import cannot proceed.")
# Fail only if we could not import anything at all.
raise SystemExit(0 if (ds_fail == 0 and dash_fail == 0) else 1)
PY
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
	trap on_exit EXIT
	locate_backup "$arg"
	validate_manifest
	require_marine_halos

	restore_signalk
	restore_opencpn
	restore_influxdb
	restore_grafana

	print_summary
	info "Done."
}

main "$@"
