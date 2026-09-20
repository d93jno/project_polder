# Engine setup

Project Polder uses **Godot 4** (GDScript, Forward+). Presentation and systems follow `docs/UI_UX_Document.md` and the GDD; this file only covers the editor and local build pipeline.

## Required version

Pinned in [`.godot-version`](../.godot-version): **4.7.2**.

Install the official Linux x86_64 editor to `$HOME/bin` and keep a `godot` symlink:

```bash
# Example (adjust if you already extracted the zip)
install -m 755 Godot_v4.7.2-stable_linux.x86_64 "$HOME/bin/"
ln -sfn Godot_v4.7.2-stable_linux.x86_64 "$HOME/bin/godot"
godot --version   # expect 4.7.2.stable...
```

Ensure `$HOME/bin` is early on your `PATH` so it beats the Snap Godot 3.1 package (`/snap/bin/godot`).

Export templates for **4.7.2.stable** must live at:

`$HOME/.local/share/godot/export_templates/4.7.2.stable/`

(Official `Godot_v4.7.2-stable_export_templates.tpz`, extracted so `version.txt` reads `4.7.2.stable`.)

## Local commands

From the repo root:

| Command | What it does |
| --- | --- |
| `make editor` / `./scripts/editor.sh` | Open the editor |
| `make run` / `./scripts/run.sh` | Run the project |
| `make import` | Headless asset import |
| `make build` / `./scripts/build.sh` | Linux x86_64 release → `build/linux/` |
| `make check-godot` | Verify binary path and version pin |

Override the binary with `GODOT=/path/to/godot make build`.

## Project settings (locked for this pass)

- Scripting: GDScript only
- Renderer: Forward+
- First export target: Linux x86_64 only
- CI: none yet (local scripts / Makefile only)
