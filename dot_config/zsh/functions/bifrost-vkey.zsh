_profile_env_value() {
  local key="$1"
  local profile="$2"
  local profile_key="${key}_${${profile:u}}"
  local value="${(P)profile_key}"

  if [[ -z "$value" ]]; then
    value="${(P)key}"
  fi

  print -r -- "$value"
}

_bifrost_virtual_key_by_name() {
  local base_url="$1"
  local admin_header="$2"
  local auth_value="$3"
  local source_name="$4"
  local response

  response="$(curl -fsSL "${base_url%/}/api/governance/virtual-keys" \
    -H "$admin_header: $auth_value")" || return 1

  jq -e --arg source_name "$source_name" '
    def virtual_keys:
      if type == "array" then .
      else (.virtual_keys // .data // .items // [])
      end;

    virtual_keys[]
    | select(.name == $source_name)
    | {
        provider_configs,
        team_id,
        customer_id,
        budget: (
          .budget
          | if . == null then null
            else {
              max_limit,
              reset_duration
            } | with_entries(select(.value != null))
            end
        ),
        rate_limit: (
          .rate_limit
          | if . == null then null
            else {
              token_max_limit,
              token_reset_duration,
              request_max_limit,
              request_reset_duration
            } | with_entries(select(.value != null))
            end
        ),
        key_ids
      }
  ' <<<"$response"
}

bifrost_vkey() {
  local profile="${CHEZMOI_PROFILE:-dev}"
  local dry_run=0
  local source_vkey_name=""

  while (( $# )); do
    case "$1" in
      dev|ai|server|macos)
        profile="$1"
        ;;
      --dry-run)
        dry_run=1
        ;;
      --from)
        shift
        if (( ! $# )); then
          print -u2 -- 'bifrost_vkey: --from requires a virtual key name'
          return 2
        fi
        source_vkey_name="$1"
        ;;
      --from=*)
        source_vkey_name="${1#--from=}"
        ;;
      --no-source)
        source_vkey_name="__none__"
        ;;
      -h|--help)
        print 'usage: bifrost_vkey [dev|ai|server|macos] [--from NAME|--no-source] [--dry-run]'
        print 'requires: BIFROST_BASE_URL and BIFROST_ADMIN_TOKEN'
        print 'dev default: copy non-secret governance config from virtual key named openclaw-main'
        print 'manual mode: set BIFROST_PROVIDER_CONFIGS_JSON[_PROFILE] and BIFROST_KEY_IDS_JSON[_PROFILE]'
        print 'optional: BIFROST_TEAM_ID[_PROFILE], BIFROST_CUSTOMER_ID[_PROFILE], budget/rate-limit env vars'
        return 0
        ;;
      *)
        print -u2 -- "bifrost_vkey: unknown argument: $1"
        return 2
        ;;
    esac
    shift
  done

  if ! command -v curl > /dev/null 2>&1 || ! command -v jq > /dev/null 2>&1; then
    print -u2 -- 'bifrost_vkey: curl and jq are required'
    return 1
  fi

  local base_url="${BIFROST_BASE_URL:-}"
  local admin_token="${BIFROST_ADMIN_TOKEN:-}"
  local admin_header="${BIFROST_ADMIN_HEADER:-Authorization}"
  local provider_configs_json="$(_profile_env_value BIFROST_PROVIDER_CONFIGS_JSON "$profile")"
  local team_id="$(_profile_env_value BIFROST_TEAM_ID "$profile")"
  local customer_id="$(_profile_env_value BIFROST_CUSTOMER_ID "$profile")"
  local key_ids_json="$(_profile_env_value BIFROST_KEY_IDS_JSON "$profile")"
  local source_budget_json=""
  local source_rate_limit_json=""
  local budget_max_limit="$(_profile_env_value BIFROST_BUDGET_MAX_LIMIT "$profile")"
  local budget_reset_duration="$(_profile_env_value BIFROST_BUDGET_RESET_DURATION "$profile")"
  local token_max_limit="$(_profile_env_value BIFROST_TOKEN_MAX_LIMIT "$profile")"
  local token_reset_duration="$(_profile_env_value BIFROST_TOKEN_RESET_DURATION "$profile")"
  local request_max_limit="$(_profile_env_value BIFROST_REQUEST_MAX_LIMIT "$profile")"
  local request_reset_duration="$(_profile_env_value BIFROST_REQUEST_RESET_DURATION "$profile")"

  if [[ -z "$base_url" || -z "$admin_token" ]]; then
    print -u2 -- 'bifrost_vkey: BIFROST_BASE_URL and BIFROST_ADMIN_TOKEN must be set'
    return 1
  fi

  if [[ "$source_vkey_name" == "__none__" ]]; then
    source_vkey_name=""
  elif [[ -z "$source_vkey_name" ]]; then
    source_vkey_name="$(_profile_env_value BIFROST_SOURCE_VKEY_NAME "$profile")"
    if [[ -z "$source_vkey_name" && "$profile" == dev ]]; then
      source_vkey_name="openclaw-main"
    fi
  fi

  local auth_value="$admin_token"
  if [[ "$admin_header" == Authorization ]]; then
    auth_value="Bearer $admin_token"
  fi

  if [[ -n "$source_vkey_name" ]]; then
    local source_config
    source_config="$(_bifrost_virtual_key_by_name "$base_url" "$admin_header" "$auth_value" "$source_vkey_name")" || {
      print -u2 -- "bifrost_vkey: could not find source virtual key: $source_vkey_name"
      return 1
    }

    if [[ -z "$provider_configs_json" ]]; then
      provider_configs_json="$(jq -c '.provider_configs' <<<"$source_config")"
    fi
    if [[ -z "$team_id" ]]; then
      team_id="$(jq -r '.team_id // empty' <<<"$source_config")"
    fi
    if [[ -z "$customer_id" ]]; then
      customer_id="$(jq -r '.customer_id // empty' <<<"$source_config")"
    fi
    if [[ -z "$key_ids_json" ]]; then
      key_ids_json="$(jq -c 'if .key_ids == null then empty else .key_ids end' <<<"$source_config")"
    fi
    source_budget_json="$(jq -c 'if .budget == null or .budget == {} then empty else .budget end' <<<"$source_config")"
    source_rate_limit_json="$(jq -c 'if .rate_limit == null or .rate_limit == {} then empty else .rate_limit end' <<<"$source_config")"
  fi

  if [[ -z "$provider_configs_json" ]]; then
    print -u2 -- "bifrost_vkey: set BIFROST_PROVIDER_CONFIGS_JSON or BIFROST_PROVIDER_CONFIGS_JSON_${${profile:u}}, or use --from NAME"
    return 1
  fi

  if [[ -n "$team_id" && -n "$customer_id" ]]; then
    print -u2 -- 'bifrost_vkey: team and customer ids are mutually exclusive'
    return 1
  fi

  if ! jq -e 'type == "array"' > /dev/null 2>&1 <<<"$provider_configs_json"; then
    print -u2 -- 'bifrost_vkey: provider configs must be a valid JSON array'
    return 1
  fi

  if [[ -n "$key_ids_json" ]] && ! jq -e 'type == "array"' > /dev/null 2>&1 <<<"$key_ids_json"; then
    print -u2 -- 'bifrost_vkey: key ids must be a valid JSON array'
    return 1
  fi

  if [[ -z "$key_ids_json" ]] && ! jq -e 'any(.[]; has("key_ids"))' > /dev/null 2>&1 <<<"$provider_configs_json"; then
    print -u2 -- 'bifrost_vkey: key ids are required unless copied from a source virtual key or embedded in provider configs'
    return 1
  fi

  local host_name="$(hostname -s 2> /dev/null || hostname)"
  local timestamp="$(date -u +%Y%m%d%H%M%S)"
  local name="${BIFROST_VK_NAME:-opencode-${profile}-${host_name}-${timestamp}}"
  local description="${BIFROST_VK_DESCRIPTION:-OpenCode ${profile} virtual key for ${host_name}}"
  local payload

  payload="$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --argjson provider_configs "$provider_configs_json" \
    '{
      name: $name,
      description: $description,
      provider_configs: $provider_configs,
      is_active: true
    }')"

  if [[ -n "$team_id" ]]; then
    payload="$(jq --arg team_id "$team_id" '. + {team_id: $team_id}' <<<"$payload")"
  fi

  if [[ -n "$customer_id" ]]; then
    payload="$(jq --arg customer_id "$customer_id" '. + {customer_id: $customer_id}' <<<"$payload")"
  fi

  if [[ -n "$key_ids_json" ]]; then
    payload="$(jq --argjson key_ids "$key_ids_json" '. + {key_ids: $key_ids}' <<<"$payload")"
  fi

  if [[ -n "$budget_max_limit" ]]; then
    payload="$(jq \
      --arg budget_max_limit "$budget_max_limit" \
      --arg budget_reset_duration "${budget_reset_duration:-1M}" \
      '. + {
        budget: {
          max_limit: ($budget_max_limit | tonumber),
          reset_duration: $budget_reset_duration
        }
      }' <<<"$payload")"
  elif [[ -n "$source_budget_json" ]]; then
    payload="$(jq --argjson budget "$source_budget_json" '. + {budget: $budget}' <<<"$payload")"
  fi

  if [[ -n "$token_max_limit" || -n "$request_max_limit" ]]; then
    payload="$(jq \
      --arg token_max_limit "$token_max_limit" \
      --arg token_reset_duration "${token_reset_duration:-1h}" \
      --arg request_max_limit "$request_max_limit" \
      --arg request_reset_duration "${request_reset_duration:-1m}" \
      '. + {
        rate_limit: (
          (if $token_max_limit != "" then {
            token_max_limit: ($token_max_limit | tonumber),
            token_reset_duration: $token_reset_duration
          } else {} end)
          +
          (if $request_max_limit != "" then {
            request_max_limit: ($request_max_limit | tonumber),
            request_reset_duration: $request_reset_duration
          } else {} end)
        )
      }' <<<"$payload")"
  elif [[ -n "$source_rate_limit_json" ]]; then
    payload="$(jq --argjson rate_limit "$source_rate_limit_json" '. + {rate_limit: $rate_limit}' <<<"$payload")"
  fi

  if (( dry_run )); then
    print -- "$payload"
    return 0
  fi

  local response
  response="$(curl -fsSL -X POST "${base_url%/}/api/governance/virtual-keys" \
    -H 'Content-Type: application/json' \
    -H "$admin_header: $auth_value" \
    -d "$payload")" || return 1

  local virtual_key="$(jq -r '.value // .virtual_key.value // .data.value // empty' <<<"$response")"
  local virtual_key_id="$(jq -r '.id // .virtual_key.id // .data.id // empty' <<<"$response")"

  if [[ -z "$virtual_key" ]]; then
    print -u2 -- 'bifrost_vkey: failed to parse virtual key from API response'
    print -u2 -- "$response"
    return 1
  fi

  local env_dir="${XDG_CONFIG_HOME:-$HOME/.config}/env.d"
  local env_file="$env_dir/opencode-bifrost.zsh"
  local clean_base_url="${base_url%/}"

  umask 077
  mkdir -p "$env_dir"

  {
    print '# Generated by bifrost_vkey. Safe to overwrite by re-running the helper.'
    print -r -- "export BIFROST_BASE_URL=${(qqq)clean_base_url}"
    print -r -- "export BIFROST_VIRTUAL_KEY=${(qqq)virtual_key}"
    print -r -- "export BIFROST_VIRTUAL_KEY_ID=${(qqq)virtual_key_id}"
    print -r -- "export BIFROST_PROFILE=${(qqq)profile}"
  } >| "$env_file"

  source "$env_file"

  print -- "stored virtual key in $env_file"
  if [[ -n "$virtual_key_id" ]]; then
    print -- "virtual key id: $virtual_key_id"
  fi
}
