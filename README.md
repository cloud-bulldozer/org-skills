# Cloud Bulldozer Skills Marketplace

A centralized marketplace of AI coding skills for the [Cloud Bulldozer](https://github.com/cloud-bulldozer) organization.

Skills are portable markdown instructions that work across Claude Code, Cursor, and any LLM provider (OpenAI, Gemini, Ollama, etc.). Install only what you need.

**Browse the marketplace:** [cloud-bulldozer.github.io/org-skills](https://cloud-bulldozer.github.io/org-skills)

## Quick Start

### Claude Code

```bash
# Register the marketplace (one-time)
/plugin marketplace add cloud-bulldozer/org-skills

# Install a plugin
/plugin install orion@cb-skills
```

### Cursor

```bash
curl -fsSL https://raw.githubusercontent.com/cloud-bulldozer/org-skills/main/install-cursor.sh | bash
```

### Any LLM

Skills are just markdown — read the `SKILL.md` and pass it as a system prompt to any provider.

```python
skill = open("orion/skills/orion-regression-analysis/SKILL.md").read()
query = "Analyze cluster-density-v2 results on AWS"
```

#### OpenAI

```python
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": skill},
        {"role": "user", "content": query},
    ],
)
print(resp.choices[0].message.content)
```

#### Anthropic

```python
from anthropic import Anthropic

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
resp = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=8192,
    system=skill,
    messages=[{"role": "user", "content": query}],
)
print("".join(block.text for block in resp.content if hasattr(block, "text")))
```

#### Google Vertex AI

```python
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_google_vertexai.model_garden import ChatAnthropicVertex

client = ChatAnthropicVertex(
    model_name="claude-3-5-sonnet-v2@20241022",
    project=os.environ["GOOGLE_CLOUD_PROJECT"],
    location=os.environ.get("GOOGLE_CLOUD_LOCATION", "us-east5"),
    max_output_tokens=8192,
    temperature=0.01,
)
resp = client.invoke([
    SystemMessage(content=skill),
    HumanMessage(content=query),
])
print(resp.content)
```

## Updating

This only refreshes the catalog (what's available). To actually update an installed plugin to a newer version, you still need to reinstall it:

```bash
/plugin marketplace add cloud-bulldozer/org-skills
/plugin install orion@cb-skills
```

You can auto-sync the catalog on session start by adding a hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/plugin marketplace add cloud-bulldozer/org-skills"
          }
        ]
      }
    ]
  }
}
```

## Available Plugins

| Plugin | Skill | Description |
|--------|-------|-------------|
| [orion](orion/) | `orion-regression-analysis` | Performance regression detection for OpenShift CPT — Elasticsearch setup, metric discovery, config generation, and result analysis using [Orion](https://github.com/cloud-bulldozer/orion) |

See [PLUGINS.md](PLUGINS.md) for the full plugin directory.

## Repository Structure

```
org-skills/
├── .claude-plugin/marketplace.json        # Marketplace registry
├── <plugin-name>/                         # One directory per plugin
│   ├── .claude-plugin/plugin.json         # Plugin metadata (name, version)
│   └── skills/<skill-name>/              # One directory per skill
│       ├── SKILL.md                       # Skill definition (required)
│       ├── docs/                          # Reference guides (optional)
│       ├── scripts/                       # Utility scripts (optional)
│       └── assets/                        # Templates, configs (optional)
├── skills/                                # Flat symlinks for Cursor
├── images/                                # Container image (Dockerfile, settings)
├── docs/                                  # Marketplace website (GitHub Pages)
└── install-cursor.sh                      # Cursor installer
```

## Container

A pre-configured container image is available with Claude Code and all plugins pre-installed. This is useful for CI/CD pipelines or headless execution.

### Build

```bash
docker build -t org-skills -f images/Dockerfile .
```

### Run

```bash
# Interactive
docker run -it \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  org-skills

# Non-interactive (headless)
docker run --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -v "$(pwd):/workspace" \
  org-skills --print "Generate an Orion config for cluster-density-v2 on AWS"
```

For Vertex AI:

```bash
docker run --rm \
  -e CLAUDE_CODE_USE_VERTEX=1 \
  -e CLOUD_ML_REGION="us-east5" \
  -e ANTHROPIC_VERTEX_PROJECT_ID="$PROJECT_ID" \
  -v "$HOME/.config/gcloud:/home/claude/.config/gcloud:ro" \
  -v "$(pwd):/workspace" \
  org-skills --print "Generate an Orion config for node-density"
```

The container pre-registers the `cb-skills` marketplace and enables the `orion` plugin. See `images/claude-settings.json` for the configuration.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding skills and plugins.

## License

Apache-2.0
