# Codex Agent TOML Design

## Goal

Generate valid native Codex custom-agent files while keeping the canonical
agent definitions in `.agents/*.md` and preserving Markdown outputs for
Claude and OpenCode.

## Scope

In scope:

- Generate `.codex/agents/<slug>.toml` files.
- Map canonical `name` and `description` to Codex TOML fields.
- Map the canonical body to `developer_instructions`.
- Map the configured model to `model`.
- Stop emitting unsupported `temperature` values for Codex.
- Make sync and tests handle Codex TOML files alongside Markdown files.

Out of scope:

- Converting Codex temperature values to reasoning effort; the values are not
  semantically equivalent and the Codex documentation does not define a
  temperature field for custom agents.
- Mapping OpenCode-only `color`, `mode`, or `permission` frontmatter to Codex.
- Maintaining separate hand-authored Codex sources.

## Chosen Approach

Keep one canonical Markdown source and branch only at platform rendering:

- Claude: YAML-frontmatter Markdown (`.md`).
- OpenCode: YAML-frontmatter Markdown (`.md`).
- Codex: TOML (`.toml`) with native custom-agent fields.

Codex files will contain:

```toml
name = "..."
description = "..."
model = "..."
developer_instructions = """
...
"""
```

The renderer will TOML-quote scalar values and use a literal multiline TOML
string for instructions. Existing canonical descriptions may be folded YAML
scalars; the renderer will resolve them to one description string before
writing TOML.

## Data Flow

1. `generate-agents.sh` reads canonical Markdown frontmatter and body.
2. It applies platform model and description overrides.
3. Claude and OpenCode use the existing Markdown renderer.
4. Codex writes native TOML and omits unsupported fields.
5. `sync-local-agents.sh` discovers Codex `.toml` sources and applies model
   overrides without assuming Markdown frontmatter.

## Validation

- Generation tests assert Codex files are `.toml`, not `.md`.
- Tests assert required Codex keys and the exact instruction body.
- Tests assert Codex files contain no `temperature`, `color`, `mode`, or
  `permission` keys.
- Existing Claude/OpenCode generation and model-override tests remain covered.
- Parity checks extract `developer_instructions` from Codex TOML and compare it
  with the Markdown body from Claude/OpenCode.
- Run the repository shell tests and Markdown lint.
