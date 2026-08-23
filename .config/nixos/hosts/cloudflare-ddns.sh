#!/usr/bin/env bash
# Cloudflare DDNS: point the origin A records at the box's current public IP.
# Reads CF_API_TOKEN from the environment (systemd EnvironmentFile). Only PATCHes
# a record when it actually changed, and PATCH preserves the grey-cloud (proxied=false)
# setting since it only touches "content". Idempotent + quiet on no-op.
set -uo pipefail
: "${CF_API_TOKEN:?CF_API_TOKEN not set}"
API=https://api.cloudflare.com/client/v4

# records to keep updated:  "zone:record-name"
RECORDS=(
  "grish.haus:grish.haus"
  "grish.haus:*.grish.haus"
  "grish.dev:grish.dev"
)

log() { printf '%s\n' "$*"; }   # journald captures stdout

# --- current public IP (ipify, fallback to Cloudflare's own trace) ---
ip=$(curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null) \
  || ip=$(curl -fsS --max-time 10 https://cloudflare.com/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=//p')
if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  log "ERROR: could not determine public IPv4 (got '$ip')"; exit 1
fi

cf() { curl -fsS --max-time 15 \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" "$@"; }

declare -A ZONEID
zone_id() {
  local z=$1
  if [[ -z "${ZONEID[$z]:-}" ]]; then
    ZONEID[$z]=$(cf "$API/zones?name=$z&status=active" | jq -r '.result[0].id // empty')
  fi
  [[ -n "${ZONEID[$z]}" ]] || { log "ERROR: no zone id for $z"; return 1; }
  printf '%s' "${ZONEID[$z]}"
}

changed=0
for spec in "${RECORDS[@]}"; do
  zone=${spec%%:*}; name=${spec#*:}
  zid=$(zone_id "$zone") || continue
  qname=${name//\*/%2A}                       # url-encode the wildcard *
  rec=$(cf "$API/zones/$zid/dns_records?type=A&name=$qname") || { log "ERROR: lookup failed for $name"; continue; }
  rid=$(jq -r '.result[0].id // empty' <<<"$rec")
  cur=$(jq -r '.result[0].content // empty' <<<"$rec")
  [[ -z "$rid" ]] && { log "WARN: no A record for '$name' in $zone (skipping)"; continue; }
  [[ "$cur" == "$ip" ]] && continue
  if cf -X PATCH "$API/zones/$zid/dns_records/$rid" --data "{\"content\":\"$ip\"}" >/dev/null; then
    log "updated $name: $cur -> $ip"; changed=1
  else
    log "ERROR: PATCH failed for $name"
  fi
done
[[ $changed -eq 0 ]] && log "no change (public IP = $ip)"
exit 0
