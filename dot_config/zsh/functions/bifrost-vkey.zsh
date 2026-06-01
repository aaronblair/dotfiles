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

_bifrost_login_token() {
  local base_url="$1"
  local username="$2"
  local password="$3"
  local payload
  local response

  payload="$(jq -n \
    --arg username "$username" \
    --arg password "$password" \
    '{username: $username, password: $password}')"

  response="$(curl -fsSL -X POST "${base_url%/}/api/session/login" \
    -H 'Content-Type: application/json' \
    -d "$payload")" || return 1

  jq -r '.token // empty' <<<"$response"
}

_bifrost_virtual_key_by_name() {
  local base_url="$1"
  local source_name="$2"
  shift 2
  local -a auth_args
  auth_args=("$@")
  local response

  response="$(curl -fsSL "${base_url%/}/api/governance/virtual-keys" \
    "${auth_args[@]}")" || return 1

  jq -e --arg source_name "$source_name" '
    def virtual_keys:
      if type == "array" then .
      else (.virtual_keys // .data // .items // [])
      end;

    def clean_budget:
      {
        max_limit,
        reset_duration,
        calendar_aligned
      } | with_entries(select(.value != null));

    def clean_rate_limit:
      {
        token_max_limit,
        token_reset_duration,
        request_max_limit,
        request_reset_duration
      } | with_entries(select(.value != null));

    def direct_budgets:
      if (.budgets // null) != null then .budgets
      elif (.budget // null) != null then [.budget]
      else []
      end;

    def key_ids_from_keys:
      [(.keys // [])[] | .key_id | select(. != null and . != "null")];

    def clean_provider_config:
      {
        provider,
        weight,
        allowed_models: (.allowed_models // []),
        blacklisted_models: (.blacklisted_models // [])
      }
      + (if (direct_budgets | length) > 0 then {budgets: [direct_budgets[] | clean_budget]} else {} end)
      + (if .rate_limit == null or ((.rate_limit | clean_rate_limit) == {}) then {} else {rate_limit: (.rate_limit | clean_rate_limit)} end)
      + (if ((.key_ids // []) | length) > 0 then {key_ids: .key_ids}
         elif (key_ids_from_keys | length) > 0 then {key_ids: key_ids_from_keys}
         elif .allow_all_keys == true then {key_ids: ["*"]}
         else {}
         end);

    def clean_mcp_config:
      {
        mcp_client_name: (.mcp_client_name // .mcp_client.name),
        tools_to_execute: (.tools_to_execute // [])
      } | with_entries(select(.value != null));

    virtual_keys[]
    | select(.name == $source_name)
    | {
        provider_configs: [(.provider_configs // [])[] | clean_provider_config],
        mcp_configs: (if ((.mcp_configs // []) | length) == 0 then null else [(.mcp_configs // [])[] | clean_mcp_config] end),
        team_id,
        customer_id,
        budgets: (if (direct_budgets | length) == 0 then null else [direct_budgets[] | clean_budget] end),
        rate_limit: (if .rate_limit == null or ((.rate_limit | clean_rate_limit) == {}) then null else (.rate_limit | clean_rate_limit) end),
        calendar_aligned
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
        print 'requires: BIFROST_BASE_URL'
        print 'auth: none by default; or BIFROST_AUTH_TOKEN, BIFROST_API_KEY, BIFROST_USERNAME/BIFROST_PASSWORD, or BIFROST_AUTH_HEADER/BIFROST_AUTH_VALUE'
        print 'dev default: copy non-secret governance config from virtual key named openclaw-main'
        print 'manual mode: set BIFROST_PROVIDER_CONFIGS_JSON[_PROFILE] with provider_configs[].key_ids, or set BIFROST_KEY_IDS_JSON[_PROFILE]'
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
  local auth_token="$(_profile_env_value BIFROST_AUTH_TOKEN "$profile")"
  local session_token="$(_profile_env_value BIFROST_SESSION_TOKEN "$profile")"
  local api_key="$(_profile_env_value BIFROST_API_KEY "$profile")"
  local auth_header="$(_profile_env_value BIFROST_AUTH_HEADER "$profile")"
  local auth_value="$(_profile_env_value BIFROST_AUTH_VALUE "$profile")"
  local auth_username="$(_profile_env_value BIFROST_USERNAME "$profile")"
  local auth_password="$(_profile_env_value BIFROST_PASSWORD "$profile")"
  local provider_configs_json="$(_profile_env_value BIFROST_PROVIDER_CONFIGS_JSON "$profile")"
  local mcp_configs_json="$(_profile_env_value BIFROST_MCP_CONFIGS_JSON "$profile")"
  local team_id="$(_profile_env_value BIFROST_TEAM_ID "$profile")"
  local customer_id="$(_profile_env_value BIFROST_CUSTOMER_ID "$profile")"
  local key_ids_json="$(_profile_env_value BIFROST_KEY_IDS_JSON "$profile")"
  local source_budgets_json=""
  local source_rate_limit_json=""
  local source_calendar_aligned=""
  local budget_max_limit="$(_profile_env_value BIFROST_BUDGET_MAX_LIMIT "$profile")"
  local budget_reset_duration="$(_profile_env_value BIFROST_BUDGET_RESET_DURATION "$profile")"
  local token_max_limit="$(_profile_env_value BIFROST_TOKEN_MAX_LIMIT "$profile")"
  local token_reset_duration="$(_profile_env_value BIFROST_TOKEN_RESET_DURATION "$profile")"
  local request_max_limit="$(_profile_env_value BIFROST_REQUEST_MAX_LIMIT "$profile")"
  local request_reset_duration="$(_profile_env_value BIFROST_REQUEST_RESET_DURATION "$profile")"

  if [[ -z "$auth_token" ]]; then
    auth_token="$session_token"
  fi

  if [[ -z "$auth_username" ]]; then
    auth_username="$(_profile_env_value BIFROST_ADMIN_USERNAME "$profile")"
  fi
  if [[ -z "$auth_password" ]]; then
    auth_password="$(_profile_env_value BIFROST_ADMIN_PASSWORD "$profile")"
  fi

  if [[ -z "$base_url" ]]; then
    print -u2 -- 'bifrost_vkey: BIFROST_BASE_URL must be set'
    return 1
  fi

  local -a auth_args
  local auth_needs_login=0
  if [[ -n "$auth_header" || -n "$auth_value" ]]; then
    if [[ -z "$auth_header" || -z "$auth_value" ]]; then
      print -u2 -- 'bifrost_vkey: BIFROST_AUTH_HEADER and BIFROST_AUTH_VALUE must be set together'
      return 1
    fi
    auth_args=(-H "$auth_header: $auth_value")
  elif [[ -n "$auth_token" ]]; then
    auth_args=(-H "Authorization: Bearer $auth_token")
  elif [[ -n "$api_key" ]]; then
    auth_args=(-H "x-api-key: $api_key")
  elif [[ -n "$auth_username" || -n "$auth_password" ]]; then
    if [[ -z "$auth_username" || -z "$auth_password" ]]; then
      print -u2 -- 'bifrost_vkey: BIFROST_USERNAME and BIFROST_PASSWORD must be set together'
      return 1
    fi
    auth_needs_login=1
  else
    auth_args=()
  fi

  if [[ "$source_vkey_name" == "__none__" ]]; then
    source_vkey_name=""
  elif [[ -z "$source_vkey_name" ]]; then
    source_vkey_name="$(_profile_env_value BIFROST_SOURCE_VKEY_NAME "$profile")"
    if [[ -z "$source_vkey_name" && "$profile" == dev ]]; then
      source_vkey_name="openclaw-main"
    fi
  fi

  if [[ -n "$source_vkey_name" ]]; then
    local source_config
    if (( auth_needs_login )); then
      auth_token="$(_bifrost_login_token "$base_url" "$auth_username" "$auth_password")" || {
        print -u2 -- 'bifrost_vkey: Bifrost login failed'
        return 1
      }
      if [[ -z "$auth_token" ]]; then
        print -u2 -- 'bifrost_vkey: Bifrost login response did not include a token'
        return 1
      fi
      auth_args=(-H "Authorization: Bearer $auth_token")
      auth_needs_login=0
    fi

    source_config="$(_bifrost_virtual_key_by_name "$base_url" "$source_vkey_name" "${auth_args[@]}")" || {
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
    if [[ -z "$mcp_configs_json" ]]; then
      mcp_configs_json="$(jq -c 'if .mcp_configs == null or .mcp_configs == [] then empty else .mcp_configs end' <<<"$source_config")"
    fi
    source_budgets_json="$(jq -c 'if .budgets == null or .budgets == [] then empty else .budgets end' <<<"$source_config")"
    source_rate_limit_json="$(jq -c 'if .rate_limit == null or .rate_limit == {} then empty else .rate_limit end' <<<"$source_config")"
    source_calendar_aligned="$(jq -r 'if .calendar_aligned == null then empty else .calendar_aligned end' <<<"$source_config")"
  fi

  if [[ -z "$provider_configs_json" ]]; then
    print -u2 -- "bifrost_vkey: set BIFROST_PROVIDER_CONFIGS_JSON or BIFROST_PROVIDER_CONFIGS_JSON_${${profile:u}}, or use --from NAME"
    return 1
  fi

  if [[ -n "$team_id" && -n "$customer_id" ]]; then
    print -u2 -- 'bifrost_vkey: team and customer ids are mutually exclusive'
    return 1
  fi

  if ! jq -e 'type == "array" and length > 0' > /dev/null 2>&1 <<<"$provider_configs_json"; then
    print -u2 -- 'bifrost_vkey: provider configs must be a non-empty JSON array'
    return 1
  fi

  if [[ -n "$mcp_configs_json" ]] && ! jq -e 'type == "array"' > /dev/null 2>&1 <<<"$mcp_configs_json"; then
    print -u2 -- 'bifrost_vkey: MCP configs must be a valid JSON array'
    return 1
  fi

  if [[ -n "$key_ids_json" ]] && ! jq -e 'type == "array"' > /dev/null 2>&1 <<<"$key_ids_json"; then
    print -u2 -- 'bifrost_vkey: key ids must be a valid JSON array'
    return 1
  fi

  if [[ -n "$key_ids_json" ]]; then
    provider_configs_json="$(jq -c --argjson key_ids "$key_ids_json" \
      'map(if ((.key_ids // []) | length) > 0 then . else . + {key_ids: $key_ids} end)' <<<"$provider_configs_json")"
  fi

  if ! jq -e 'all(.[]; ((.key_ids // []) | (type == "array" and length > 0)))' > /dev/null 2>&1 <<<"$provider_configs_json"; then
    print -u2 -- 'bifrost_vkey: every provider config must include key_ids; set BIFROST_KEY_IDS_JSON[_PROFILE] or use a source key with key assignments'
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

  if [[ -n "$mcp_configs_json" ]]; then
    payload="$(jq --argjson mcp_configs "$mcp_configs_json" '. + {mcp_configs: $mcp_configs}' <<<"$payload")"
  fi

  if [[ -n "$budget_max_limit" ]]; then
    payload="$(jq \
      --arg budget_max_limit "$budget_max_limit" \
      --arg budget_reset_duration "${budget_reset_duration:-1M}" \
      '. + {
        budgets: [{
          max_limit: ($budget_max_limit | tonumber),
          reset_duration: $budget_reset_duration
        }]
      }' <<<"$payload")"
  elif [[ -n "$source_budgets_json" ]]; then
    payload="$(jq --argjson budgets "$source_budgets_json" '. + {budgets: $budgets}' <<<"$payload")"
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

  if [[ "$source_calendar_aligned" == true ]]; then
    payload="$(jq '. + {calendar_aligned: true}' <<<"$payload")"
  fi

  if (( dry_run )); then
    print -- "$payload"
    return 0
  fi

  if (( auth_needs_login )); then
    auth_token="$(_bifrost_login_token "$base_url" "$auth_username" "$auth_password")" || {
      print -u2 -- 'bifrost_vkey: Bifrost login failed'
      return 1
    }
    if [[ -z "$auth_token" ]]; then
      print -u2 -- 'bifrost_vkey: Bifrost login response did not include a token'
      return 1
    fi
    auth_args=(-H "Authorization: Bearer $auth_token")
  fi

  local response
  response="$(curl -fsSL -X POST "${base_url%/}/api/governance/virtual-keys" \
    -H 'Content-Type: application/json' \
    "${auth_args[@]}" \
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
