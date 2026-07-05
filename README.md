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

## AI Workflow Notes

This project is experimenting with AI worker orchestration.

- Consensus R&D is archived as a documented trial in `.docs/consensus-rnd-sop.md`.
- Sortie is the next local orchestration trial. See `.docs/sortie-trial-sop.md` and `.docs/sortie-trial-log.md`.
- Runtime data stays local under ignored directories such as `.sortie/`, `.tools/`, `.worktrees/`, and `.refactor-loop/`.
