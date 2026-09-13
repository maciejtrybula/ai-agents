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

toml_escape_scalar() {
  node -e '
const value = process.argv[1] ?? ""
const escapes = {"\b": "\\b", "\t": "\\t", "\n": "\\n", "\f": "\\f", "\r": "\\r"}
const escaped = value
  .replace(/\\/g, "\\\\")
  .replace(/"/g, "\\\"")
  .replace(/[\u0000-\u001f\u007f]/g, (character) => {
    return escapes[character] ?? `\\u${character.codePointAt(0).toString(16).padStart(4, "0")}`
  })
process.stdout.write(escaped)
' "$1"
}

toml_escape_multiline_body() {
  node -e '
const fs = require("fs")
const value = fs.readFileSync(0, "utf8")
let escaped = ""
for (const character of value) {
  if (character === "\\") escaped += "\\\\"
  else if (character === "\r") escaped += "\\r"
  else if (character === "\n") escaped += "\n"
  else if (character === "\b") escaped += "\\b"
  else if (character === "\f") escaped += "\\f"
  else if (character === "\t") escaped += "\t"
  else if (character.codePointAt(0) < 0x20 || character.codePointAt(0) === 0x7f) {
    escaped += `\\u${character.codePointAt(0).toString(16).padStart(4, "0")}`
  } else {
    escaped += character
  }
}

// A quote run of three or more would close the multiline basic string. Escape
// only those runs so ordinary canonical body text remains readable.
escaped = escaped.replace(/"{3,}/g, (run) => "\\\"".repeat(run.length))
process.stdout.write(escaped)
'
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

# Read a canonical description while resolving plain and block scalar forms.
# Markdown keeps the original frontmatter block; Codex needs the scalar value.
read_agent_description() {
  awk '
    BEGIN { frontmatter=0; in_description=0; description_style=""; description="" }
    /^---$/ {
      frontmatter++
      if (frontmatter == 2) exit
      next
    }
    frontmatter != 1 { next }
    !in_description && /^description:[[:space:]]*/ {
      value=$0
      sub(/^description:[[:space:]]*/, "", value)
      if (value ~ /^[>|][+-]?[[:space:]]*$/) {
        in_description=1
        description_style=substr(value, 1, 1)
        next
      }
      print value
      exit
    }
    in_description {
      if ($0 != "" && $0 !~ /^[[:space:]]+/) exit
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (description_style == ">") {
        if (line == "") {
          if (description != "") description=description "\n"
        } else {
          if (description != "" && description !~ /\n$/) description=description " "
          description=description line
        }
      } else {
        if (description != "") description=description "\n"
        description=description line
      }
    }
    END {
      if (in_description) print description
    }
  ' "$1"
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

  # Frontmatter = lines between the opening `---` (line 1) and the closing `---`.
  local frontmatter_block
  frontmatter_block="$(sed -n '2,/^---$/p' "$canonical_file" | sed '$d')"

  if [[ "$platform" == "codex" ]]; then
    local canonical_name canonical_description
    canonical_name="$(printf '%s\n' "$frontmatter_block" | awk '/^name:/{sub(/^name:[ \t]*/, ""); print; exit}')"
    canonical_description="$(read_agent_description "$canonical_file")"
    if [[ -z "$canonical_name" || -z "$canonical_description" ]]; then
      printf 'Error: canonical agent is missing name or description: %s\n' "$canonical_file" >&2
      exit 1
    fi
    if [[ -n "$agent_description" ]]; then
      canonical_description="$agent_description"
    fi

    local out_file="$out_dir/$slug.toml"
    mkdir -p "$out_dir"
    rm -f "$out_dir/$slug.md"
    {
      printf 'name = "%s"\n' "$(toml_escape_scalar "$canonical_name")"
      printf 'description = "%s"\n' "$(toml_escape_scalar "$canonical_description")"
      printf 'model = "%s"\n' "$(toml_escape_scalar "$platform_model")"
      printf 'developer_instructions = """\n'
      awk 'BEGIN{f=0} /^---$/ && f<2{f++; next} f>=2{print}' "$canonical_file" | toml_escape_multiline_body
      printf '"""\n'
    } >"$out_file"

    printf '%s\n' "$out_file"
    return
  fi

  local out_file="$out_dir/$slug.md"
  mkdir -p "$out_dir"

  {
    printf -- '---\n'
    while IFS= read -r line; do
      # `platforms:` is generator metadata, not agent frontmatter: drop it.
      if [[ "$line" == platforms:* ]]; then
        continue
      fi
      # OpenCode derives the agent ID from the filename; `name` is canonical
      # generator metadata, not a native V2 Markdown-agent field.
      if [[ "$platform" == "opencode" && "$line" == name:* ]]; then
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
      if [[ "$platform" == "opencode" ]]; then
        printf 'request:\n'
        printf '  body:\n'
        printf '    temperature: %s\n' "$platform_temperature"
      else
        printf 'temperature: %s\n' "$platform_temperature"
      fi
    fi
    printf -- '---\n'
    # Body = everything after the closing frontmatter delimiter (starts with a blank line).
    awk 'BEGIN{f=0} /^---$/ && f<2{f++; next} f>=2{print}' "$canonical_file"
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

platform_slugs=()
platform_dirs=()
platform_project_dirs=()
platform_models=()
platform_colors=()
platform_temperatures=()
while IFS=$'\t' read -r pslug pdir pprojdir pmodel pcolor ptemperature; do
  [[ -n "$pslug" ]] || continue
  if [[ "$pprojdir" == "-" ]]; then
    pprojdir=""
  fi
  platform_slugs+=("$pslug")
  platform_dirs+=("$pdir")
  platform_project_dirs+=("$pprojdir")
  platform_models+=("$pmodel")
  platform_colors+=("$pcolor")
  platform_temperatures+=("$ptemperature")
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

  for platform_index in "${!platform_slugs[@]}"; do
    pslug="${platform_slugs[$platform_index]}"
    # If a platforms list is declared, skip platforms not in it.
    if [[ ${#local_platforms[@]} -gt 0 ]]; then
      included=0
      for p in "${local_platforms[@]}"; do
        if [[ "$p" == "$pslug" ]]; then included=1; break; fi
      done
      [[ "$included" == "1" ]] || continue
    fi
    render_platform_file "$slug" "$canonical_file" "$pslug" "${platform_dirs[$platform_index]}" "${platform_project_dirs[$platform_index]}" "${platform_models[$platform_index]}" "${platform_colors[$platform_index]}" "${platform_temperatures[$platform_index]-}"
    generated_count=$((generated_count + 1))
  done
done

printf 'Generated %d platform agent file(s) from %s.\n' "$generated_count" "$canonical_dir"
