#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: forge-test.sh <environment> <workspace-name-or-id>

Examples:
  forge-test.sh staging test-org
  FORGE_TEST_ALLOW_PROD=1 forge-test.sh production 00000000-0000-0000-0000-000000000000
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

environment="$1"
workspace_ref="$2"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/forge-test.XXXXXX")"
forge_bin="$tmp_dir/forge"
trap 'rm -rf "$tmp_dir"' EXIT

run() {
  printf '\n==> '
  printf '%q ' "$@"
  printf '\n'
  "$@"
}

run_ws() {
  printf '\n==> PLATFORM_WORKSPACE_ID=%q ' "$workspace_id"
  printf '%q ' "$@"
  printf '\n'
  PLATFORM_WORKSPACE_ID="$workspace_id" "$@"
}

json_field() {
  local field="$1"
  python3 -c 'import json,sys
field=sys.argv[1]
raw=sys.stdin.read().strip()
if not raw:
    sys.exit(0)
try:
    data=json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)
value=data.get(field, "")
if value is None:
    value=""
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)' "$field"
}

platform_env_file_value() {
  local key="$1"
  python3 - "$environment" "$key" <<'PY'
from pathlib import Path
import sys

environment, key = sys.argv[1], sys.argv[2]
for path in (Path(f".env.platform.{environment}"), Path(f".env.{environment}")):
    if not path.exists():
        continue
    found = ""
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        name, value = line.split("=", 1)
        if name.strip() == key:
            found = value.strip().strip("\"'")
    print(found)
    raise SystemExit(0)
raise SystemExit(0)
PY
}

url_host() {
  local raw_url="$1"
  python3 - "$raw_url" <<'PY'
import sys
from urllib.parse import urlparse

parsed = urlparse(sys.argv[1])
print(parsed.hostname or "")
PY
}

resolve_api_url() {
  if [[ -n "${PLATFORM_API_URL:-}" ]]; then
    printf '%s\n' "$PLATFORM_API_URL"
    return
  fi

  local show_json
  show_json="$("$forge_bin" platform config show "$environment" --json 2>/dev/null || true)"
  local api_url
  api_url="$(printf '%s' "$show_json" | json_field api_url)"
  if [[ -n "$api_url" ]]; then
    printf '%s\n' "$api_url"
    return
  fi

  platform_env_file_value PLATFORM_API_URL
}

resolve_identity_url() {
  if [[ -n "${IDENTITY_URL:-}" ]]; then
    printf '%s\n' "$IDENTITY_URL"
    return
  fi

  local show_json
  show_json="$("$forge_bin" platform config show "$environment" --json 2>/dev/null || true)"
  local identity_url
  identity_url="$(printf '%s' "$show_json" | json_field identity_url)"
  if [[ -n "$identity_url" ]]; then
    printf '%s\n' "$identity_url"
    return
  fi

  platform_env_file_value IDENTITY_URL
}

is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

resolve_workspace_id() {
  local ref="$1"
  if is_uuid "$ref"; then
    printf '%s\n' "$ref"
    return
  fi

  local workspaces_json
  workspaces_json="$("$forge_bin" platform workspace list --env "$environment" --json)"
  WORKSPACES_JSON="$workspaces_json" python3 - "$ref" <<'PY'
import json
import os
import sys

ref = sys.argv[1].strip().lower()
data = json.loads(os.environ["WORKSPACES_JSON"])
items = data.get("items", data) if isinstance(data, dict) else data
if not isinstance(items, list):
    print("workspace list response was not an array or items envelope", file=sys.stderr)
    raise SystemExit(1)

matches = []
for item in items:
    if not isinstance(item, dict):
        continue
    values = [str(item.get(k, "")).strip().lower() for k in ("id", "slug", "name")]
    if ref in values:
        matches.append(item)

if len(matches) == 1:
    workspace_id = str(matches[0].get("id", "")).strip()
    if workspace_id:
        print(workspace_id)
        raise SystemExit(0)

if not matches:
    print(f"no workspace matched {sys.argv[1]!r}; pass the workspace UUID", file=sys.stderr)
else:
    print(f"workspace reference {sys.argv[1]!r} is ambiguous; pass the workspace UUID", file=sys.stderr)
    for item in matches:
        print(f"- {item.get('id', '')} {item.get('slug', '')} {item.get('name', '')}", file=sys.stderr)
raise SystemExit(1)
PY
}

check_auth_ready() {
  local doctor_json auth_method token_cached workspace_set complete

  printf '\n==> '
  if [[ -n "$workspace_id" ]]; then
    printf 'PLATFORM_WORKSPACE_ID=%q ' "$workspace_id"
  fi
  printf '%q ' "$forge_bin" platform config doctor --env "$environment" --json
  printf '\n'
  if [[ -n "$workspace_id" ]]; then
    doctor_json="$(PLATFORM_WORKSPACE_ID="$workspace_id" "$forge_bin" platform config doctor --env "$environment" --json)"
  else
    doctor_json="$("$forge_bin" platform config doctor --env "$environment" --json)"
  fi
  printf '%s\n' "$doctor_json"

  auth_method="$(printf '%s' "$doctor_json" | json_field auth_method)"
  token_cached="$(printf '%s' "$doctor_json" | json_field device_code_token_cached)"
  workspace_set="$(printf '%s' "$doctor_json" | json_field workspace_id_set)"
  complete="$(printf '%s' "$doctor_json" | json_field complete)"
  if [[ -z "$workspace_id" && "$workspace_set" != "true" ]]; then
    echo "Workspace name resolution requires a configured PLATFORM_WORKSPACE_ID. Pass the workspace UUID instead." >&2
    exit 2
  fi
  if [[ "$complete" != "true" ]]; then
    echo "Platform config is incomplete for environment '$environment'. Run: forge platform config doctor --env $environment --json" >&2
    exit 2
  fi
  if [[ "$auth_method" == "device_code" && "$token_cached" != "true" ]]; then
    echo "Device-code auth is configured but no token is cached. Run: forge auth login --platform --env $environment" >&2
    exit 2
  fi
}

lower_env="$(printf '%s' "$environment" | tr '[:upper:]' '[:lower:]')"
workspace_id=""
if is_uuid "$workspace_ref"; then
  workspace_id="$workspace_ref"
fi

run go test ./...
run go build -o "$forge_bin" ./cmd/forge

api_url="$(resolve_api_url)"
identity_url="$(resolve_identity_url)"
if [[ -z "$identity_url" ]]; then
  identity_url="$api_url"
fi
api_host="$(url_host "$api_url")"
identity_host="$(url_host "$identity_url")"
if [[ "$lower_env" == "prod" || "$lower_env" == "production" ]]; then
  if [[ "${FORGE_TEST_ALLOW_PROD:-}" != "1" ]]; then
    echo "Refusing production live test without FORGE_TEST_ALLOW_PROD=1." >&2
    exit 2
  fi
elif [[ -z "$api_host" ]]; then
  echo "Refusing non-production environment '$environment' because the effective Platform API URL could not be safely resolved." >&2
  exit 2
elif [[ "$api_host" == "api.platform.amigo.ai" ]]; then
  echo "Refusing non-production environment '$environment' because it resolves to production Platform API: $api_url" >&2
  exit 2
elif [[ "$identity_host" == "api.platform.amigo.ai" ]]; then
  echo "Refusing non-production environment '$environment' because it resolves to production identity service: $identity_url" >&2
  exit 2
fi

if [[ "$lower_env" == "staging" && "$api_host" != "internal-api.platform.amigo.ai" ]]; then
  echo "Refusing staging test because PLATFORM_API_URL is not the staging Platform API host: $api_url" >&2
  exit 2
fi
if [[ "$lower_env" == "staging" && "$identity_host" != "internal-api.platform.amigo.ai" ]]; then
  echo "Refusing staging test because IDENTITY_URL is not the staging Platform identity host: $identity_url" >&2
  exit 2
fi

check_auth_ready

checked_workspace_id="$workspace_id"
if [[ -z "$workspace_id" ]]; then
  workspace_id="$(resolve_workspace_id "$workspace_ref")"
fi
printf '\nResolved workspace: %s\n' "$workspace_id"
if [[ "$workspace_id" != "$checked_workspace_id" ]]; then
  check_auth_ready
fi

run_ws "$forge_bin" platform workspace list --workspace "$workspace_id" --env "$environment" --json

printf '\nForge live smoke test passed for environment %q workspace %q.\n' "$environment" "$workspace_id"
