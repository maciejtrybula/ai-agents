#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"
canonical_dir="$repo_root/.agents"
platforms_file="$repo_root/.config/agent-platforms.json"

target_dir=""

usage() {
  cat <<'EOF'
Usage: generate-agents.sh [--target-dir <path>]

Materializes the canonical agent definitions from .agents/ into the three
per-platform agent directories.

Unless --target-dir is given, outputs are written into the repo staging
dirs that sync-local-agents.sh consumes:

  .claude/agents/, .codex/agents/, .config/opencode/agents/

With --target-dir <path>, outputs are written under:

  <path>/.claude/agents, <path>/.codex/agents, <path>/.opencode/agents

Options:
  --target-dir <path>   Write generated files into an arbitrary destination
                        (e.g. a project's .claude/, .codex/, .opencode/).
  -h, --help            Show this help.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target-dir)
        if [[ $# -lt 2 ]]; then
          printf 'Error: --target-dir requires a path argument.\n' >&2
          exit 1
        fi
        target_dir="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Error: unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

read_platforms_config() {
  node - "$platforms_file" <<'NODE'
const [configFile] = process.argv.slice(2)
const config = JSON.parse(require("fs").readFileSync(configFile, "utf8"))
const out = []
for (const [slug, cfg] of Object.entries(config.platforms || {})) {
  out.push(`${slug}\t${cfg.dir || ""}\t${cfg.projectDir || "-"}\t${cfg.model || ""}\t${cfg.color ? "1" : "0"}\t${cfg.temperature ?? ""}`)
}
process.stdout.write(out.join("\n") + (out.length ? "\n" : ""))
NODE
}

# Look up a per-agent override field for a platform. Prints the value (which may
# be empty) or nothing if no per-agent entry exists.
# $1 = platform slug, $2 = agent slug, $3 = field (model | description)
query_agent_override() {
  node - "$platforms_file" "$1" "$2" "$3" <<'NODE'
const [configFile, platform, agent, field] = process.argv.slice(2)
const config = JSON.parse(require("fs").readFileSync(configFile, "utf8"))
const entry = config?.platforms?.[platform]?.agents?.[agent]
if (entry && entry[field] !== undefined && entry[field] !== null) {
  process.stdout.write(String(entry[field]))
}
NODE
}

# Read the canonical `platforms:` frontmatter list (e.g. "platforms: [codex, opencode]").
# Prints each platform slug on its own line; prints nothing if absent (meaning all platforms).
# $1 = canonical file
read_agent_platforms() {
  awk 'BEGIN{f=0} /^---$/{f++; next} f==1 && /^platforms:/{
    sub(/^platforms:[ \t]*[\[\(]/,""); sub(/[\]\)][ \t]*$/,"")
    n=split($0, a, /[ ,]+/); for (i=1;i<=n;i++) if (a[i] != "") print a[i]
    exit
  }' "$1"
}

# Render one platform file from a canonical source and its platform config.
# $1 = slug, $2 = canonical file, $3 = platform slug, $4 = platform dir, $5 = platform project dir, $6 = platform model, $7 = include color (1/0), $8 = platform temperature (may be empty)
render_platform_file() {
  local slug="$1"
  local canonical_file="$2"
  local platform="$3"
  local platform_dir="$4"
  local platform_project_dir="$5"
  local platform_model="$6"
  local include_color="$7"
  local platform_temperature="$8"

  # Per-agent override wins over the platform default model.
  local agent_model
  agent_model="$(query_agent_override "$platform" "$slug" "model")"
  if [[ -n "$agent_model" ]]; then
    platform_model="$agent_model"
  fi

  # Per-agent description override (e.g. backend-engineer long Examples on
  # codex/opencode) replaces the canonical description line.
  local agent_description
  agent_description="$(query_agent_override "$platform" "$slug" "description")"

  # Per-agent temperature override wins over the platform default temperature.
  local agent_temperature
  agent_temperature="$(query_agent_override "$platform" "$slug" "temperature")"
  if [[ -n "$agent_temperature" ]]; then
    platform_temperature="$agent_temperature"
  fi

  local out_base="$repo_root"
  if [[ -n "$target_dir" ]]; then
    out_base="$target_dir"
  fi

  # When writing into a custom project destination, prefer the per-platform
  # projectDir (e.g. opencode's .opencode/) over the user-local dir.
  local out_platform_dir="$platform_dir"
  if [[ -n "$target_dir" && -n "$platform_project_dir" ]]; then
    out_platform_dir="$platform_project_dir"
  fi

  local out_dir="$out_base/$out_platform_dir"
  local out_file="$out_dir/$slug.md"
  mkdir -p "$out_dir"

  # Frontmatter = lines between the opening `---` (line 1) and the closing `---`.
  local frontmatter_block
  frontmatter_block="$(sed -n '2,/^---$/p' "$canonical_file" | sed '$d')"

  {
    printf -- '---\n'
    while IFS= read -r line; do
      # `platforms:` is generator metadata, not agent frontmatter: drop it.
      if [[ "$line" == platforms:* ]]; then
        continue
      fi
      if [[ "$line" == color:* && "$include_color" != "1" ]]; then
        continue
      fi
      # temperature is supplied per-platform (from the platform config), never
      # from the canonical source, so drop any canonical temperature line to
      # avoid duplicating the platform-provided one.
      if [[ "$line" == temperature:* ]]; then
        continue
      fi
      # A per-agent description override replaces the canonical description.
      if [[ "$line" == description:* && -n "$agent_description" ]]; then
        printf 'description: %s\n' "$agent_description"
        continue
      fi
      printf '%s\n' "$line"
    done <<<"$frontmatter_block"
    printf 'model: %s\n' "$platform_model"
    if [[ -n "$platform_temperature" ]]; then
      printf 'temperature: %s\n' "$platform_temperature"
    fi
    printf -- '---\n'
    # Body = everything after the closing frontmatter delimiter (starts with a blank line).
    awk 'BEGIN{f=0} /^---$/{f++; next} f>=2{print}' "$canonical_file"
  } >"$out_file"

  printf '%s\n' "$out_file"
}

parse_args "$@"

if [[ ! -d "$canonical_dir" ]]; then
  printf 'Error: canonical agents directory not found: %s\n' "$canonical_dir" >&2
  exit 1
fi

if [[ ! -f "$platforms_file" ]]; then
  printf 'Error: platform config not found: %s\n' "$platforms_file" >&2
  exit 1
fi

declare -A platform_dir
declare -A platform_project_dir
declare -A platform_model
declare -A platform_color
declare -A platform_temperature
while IFS=$'\t' read -r pslug pdir pprojdir pmodel pcolor ptemperature; do
  [[ -n "$pslug" ]] || continue
  platform_dir["$pslug"]="$pdir"
  if [[ "$pprojdir" == "-" ]]; then
    pprojdir=""
  fi
  platform_project_dir["$pslug"]="$pprojdir"
  platform_model["$pslug"]="$pmodel"
  platform_color["$pslug"]="$pcolor"
  platform_temperature["$pslug"]="$ptemperature"
done < <(read_platforms_config)

generated_count=0
for canonical_file in "$canonical_dir"/*.md; do
  [[ -e "$canonical_file" ]] || continue
  [[ "$(basename "$canonical_file")" != "README.md" ]] || continue

  slug="$(basename "$canonical_file" .md)"

  # Platform-inclusion: an explicit `platforms:` list restricts where the
  # agent is emitted; absence means all platforms.
  local_platforms=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && local_platforms+=("$p")
  done < <(read_agent_platforms "$canonical_file")

  for pslug in "${!platform_dir[@]}"; do
    # If a platforms list is declared, skip platforms not in it.
    if [[ ${#local_platforms[@]} -gt 0 ]]; then
      included=0
      for p in "${local_platforms[@]}"; do
        if [[ "$p" == "$pslug" ]]; then included=1; break; fi
      done
      [[ "$included" == "1" ]] || continue
    fi
    render_platform_file "$slug" "$canonical_file" "$pslug" "${platform_dir[$pslug]}" "${platform_project_dir[$pslug]}" "${platform_model[$pslug]}" "${platform_color[$pslug]}" "${platform_temperature[$pslug]-}"
    generated_count=$((generated_count + 1))
  done
done

printf 'Generated %d platform agent file(s) from %s.\n' "$generated_count" "$canonical_dir"
