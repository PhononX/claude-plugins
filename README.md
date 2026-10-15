# PhononX Claude Code plugins

The `carbonvoice` plugin marketplace for Claude Code.

```
/plugin marketplace add PhononX/claude-plugins
```

| Plugin | What it does | Source |
|---|---|---|
| `cv-channel` | Talk to a running Claude Code session through Carbon Voice | npm: `@carbonvoice/cv-claude-channel` ([repo](https://github.com/PhononX/cv-claude-channels)) |
| `cos` | A chief of staff with durable memory, reached through Carbon Voice | [`plugins/cos`](plugins/cos) |

**Getting started with Chief of Staff:** one line in Terminal installs everything:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"
```
Full instructions: [plugins/cos/README.md](plugins/cos/README.md).

## Maintainers

- **cv-channel** is released with `npm publish` from its own repo. Bump its `version` here to match.
- **cos** lives in this repo. Bump `version` in both `plugins/cos/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` for every release; users get it via `/plugin marketplace update`.
- Keep the marketplace name `carbonvoice`. Team/Enterprise managed settings reference it in
  `allowedChannelPlugins`.

Test locally before publishing:
```
claude plugin validate . --strict
cd /tmp/test-workspace && claude --plugin-dir /path/to/claude-plugins/plugins/cos
```
