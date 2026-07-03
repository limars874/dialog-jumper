# dialog-jumper

A macOS utility experiment for enhancing native Open / Save dialogs.

Goal:

```text
Detect the active Open / Save dialog
→ show a lightweight companion panel
→ jump the dialog to a chosen folder
```

Initial scope:

- Accessibility-based dialog detection.
- Non-activating AppKit overlay panel.
- Clipboard-folder jump via the standard Go to Folder flow.
- Later: favorites, Finder windows, and recent folders.

Status: early MVP exploration.

## Consensus R&D Local Tooling

This project runs `consensus-loop` from a project-local tool checkout:

```bash
mkdir -p .tools
git clone --branch dev https://github.com/ChronoAIProject/consensus-rnd .tools/consensus-rnd
git -C .tools/consensus-rnd checkout abd6db05c508563e1e6fe17abf15925cc0fe8172
chmod +x .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli
```

Pinned tool version:

- Repo: `https://github.com/ChronoAIProject/consensus-rnd`
- Ref: `dev`
- Commit: `abd6db05c508563e1e6fe17abf15925cc0fe8172`

Host runtime facts stay local:

```bash
cp .config/consensus-rnd/host.env.example .config/consensus-rnd/host.env
export CONSENSUS_RND_HOST_ENV=.config/consensus-rnd/host.env
source "$CONSENSUS_RND_HOST_ENV"
```

Use the local CLI path:

```bash
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli daemon-status --json
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli restart-daemons
python3 .tools/consensus-rnd/skills/consensus-loop/scripts/consensus-rnd-cli peek
```
