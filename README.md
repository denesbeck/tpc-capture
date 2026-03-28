# tpc-capture

A tmux plugin that captures your current pane layout and saves it as a [tpc](https://github.com/denesbeck/tmux-pane-controller) config file.

## Features

- Captures pane geometry and running commands from the current tmux window
- Reconstructs the split tree automatically
- Interactive popup for naming the layout
- Esc to cancel at any point
- Saves directly to `~/.config/tpc/` in tpc-compatible YAML format

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [yq](https://github.com/mikefarah/yq) - YAML processor
- [b3sum](https://github.com/BLAKE3-team/BLAKE3) - BLAKE3 hashing

```bash
brew install yq b3sum
```

## Install

### With TPM

Add to your `tmux.conf`:

```tmux
set -g @plugin 'denesbeck/tpc-capture'
```

### Manual

```bash
git clone https://github.com/denesbeck/tpc-capture.git ~/path/to/tpc-capture
```

Add to your `tmux.conf`:

```tmux
run-shell '~/path/to/tpc-capture/capture.tmux'
```

## Usage

1. Arrange your tmux panes the way you want them
2. Press `prefix + S` to open the capture popup
3. Enter a layout name and description (or Esc to cancel)
4. The layout is saved to `~/.config/tpc/` and can be loaded with `tpc load`

## Configuration

```tmux
set -g @tpc_capture_key 'S'            # default: S
set -g @tpc_capture_popup_width '60%'  # default: 60%
set -g @tpc_capture_popup_height '50%' # default: 50%
```

## How it works

The plugin runs inside a `display-popup`, which means it operates outside of any pane. This ensures all pane commands are captured accurately without interference.

It reads pane geometry via `tmux list-panes`, reconstructs the split tree by finding vertical and horizontal divider lines recursively, and outputs tpc-compatible YAML.

## Companion CLI

Use [tpc](https://github.com/denesbeck/tmux-pane-controller) to load, validate, edit, and manage your saved layouts.

## License

MIT
