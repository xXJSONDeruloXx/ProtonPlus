# ProtonPlus AI Coding Agent Instructions

## Project Overview

ProtonPlus is a GTK4/Libadwaita compatibility tools manager for Linux gaming, built with Vala. It manages Proton versions and other compatibility tools across Steam, Lutris, Heroic Games Launcher, Bottles, and WineZGUI.

## Architecture & Key Components

### Core Structure
- **Entry Point**: `src/main.vala` → `Widgets.Application` → `Widgets.Window`
- **Model-View Architecture**: Models in `src/models/`, UI widgets in `src/widgets/`
- **Two-Tab Interface**: Runners (compatibility tools) and Games management
- **Launcher Abstraction**: Base `Models.Launcher` with specific implementations for each gaming platform

### Data Models Hierarchy
```
Models.Launcher (abstract base)
├── Models.Launchers.Steam (VDF config parsing)
├── Models.Launchers.Lutris (YAML configs)
├── Models.Launchers.Bottles (JSON configs)
└── Models.Launchers.{HGL,WineZGUI}

Models.Runner (abstract base)
├── Models.Runners.Basic (GitHub/GitLab releases)
├── Models.Runners.GitHub (API integration)
└── Models.Runners.SteamTinkerLaunch (special case)

Models.Release (abstract base)
├── Models.Releases.Basic (standard releases)
├── Models.Releases.GitHubAction (CI artifacts)
└── Models.Releases.SteamTinkerLaunch (special handling)
```

### Critical Steam Integration
- **VDF (Valve Data Format)**: Binary parser in `src/models/vdf/` handles Steam's config files
- **Steam Profile Management**: `Models.SteamProfile` manages userdata, localconfig.vdf, shortcuts.vdf
- **Compatibility Tool Mapping**: Steam stores per-game tool assignments in config.vdf
- **Launch Options**: Stored in localconfig.vdf, parsed with regex patterns

## Build System & Dependencies

### Meson Configuration
```bash
# Development build
meson setup build --prefix=/usr/local
meson compile -C build

# Install system-wide
ninja -C build install
```

### Key Dependencies (from meson.build)
- **GTK4**: Modern UI framework
- **Libadwaita >= 1.6**: GNOME HIG-compliant widgets (Adw.HeaderBar, Adw.StatusPage, etc.)
- **JSON-GLib**: API response parsing
- **libsoup-3.0**: HTTP client for downloads
- **libarchive**: Compressed file extraction
- **libgee**: Advanced collections

### Resource Compilation
- Icons/UI files compiled via `data/com.vysp3r.ProtonPlus.gresource.xml`
- Desktop integration through metainfo.xml and .desktop files
- GSettings schema: `data/com.vysp3r.ProtonPlus.gschema.xml`

## Development Patterns

### Widget Patterns
```vala
// Standard widget construction pattern
public class MyWidget : Gtk.Box {
    construct {
        // Initialize UI elements
        // Connect signals
        // Set CSS classes
    }
}

// Use Adw widgets for modern appearance
var header_bar = new Adw.HeaderBar();
var status_page = new Adw.StatusPage();
```

### Async Operations
```vala
// All I/O operations are async
public async bool load_data() {
    var success = yield Utils.Web.GET(url);
    return success != null;
}

// Use delegates for callbacks
public delegate void progress_callback(bool is_percent, int64 progress);
```

### Signal Connections
```vala
// Property change notifications
button.notify["active"].connect(on_active_changed);

// Custom signals with lambda expressions
button.clicked.connect(() => {
    // Handle click
});
```

### Error Handling
```vala
// Use Vala's exception system
try {
    var content = yield operation();
} catch (Error e) {
    message(e.message); // Logs to console
    return false;
}
```

## Launcher-Specific Conventions

### Steam VDF Parsing
- Use string operations with precise start/end text markers
- Handle both text and binary VDF formats
- Steam IDs conversion: SteamID64 ↔ SteamID3 ↔ Account ID
- Example pattern:
```vala
start_text = "\"CompatToolMapping\"\n\t\t\t\t{";
start_pos = content.index_of(start_text, 0) + start_text.length;
end_pos = content.index_of(end_text, start_pos);
```

### Runner Configuration Format
- Runners defined in `data/runners.json` with GitHub/GitLab API endpoints
- Support for multiple directory name formats per launcher
- Asset position handling for GitHub releases
- Hardware capability conditions (x86_64_v3 detection)

### Widget Responsiveness
- Use `Adw.Clamp` for maximum width constraints
- Apply CSS classes: `"card"`, `"flat"`, `"boxed-list"`
- Toast notifications via `Adw.ToastOverlay.add_toast()`

## Testing & CI

### Local Testing
```bash
# Syntax validation
meson test -C build --print-errorlogs

# Manual testing with debug output
G_MESSAGES_DEBUG=all ./build/src/protonplus
```

### CI Pipeline (`.github/workflows/main.yml`)
- **Native Build**: Ubuntu with apt dependencies
- **Flatpak Build**: Uses GNOME 48 runtime
- Validates desktop files and AppStream metadata

## Key Integration Points

### External Dependencies Check
- Steam client detection via steamclient.dll presence
- Compatibility tool validation in launcher directories
- System tool dependencies (STL requires yad, xdotool, etc.)

### File System Operations
- Atomic file modifications via `Utils.Filesystem.modify_file()`
- Archive extraction with progress callbacks
- Directory permissions and .steam symlink handling

### Web API Integration
- GitHub/GitLab release API consumption
- Download progress tracking with speed/ETA calculation
- User-Agent: "ProtonPlus/{version}"

## Common Pitfalls

1. **VDF Parsing**: Steam's text format is whitespace-sensitive; maintain exact indentation
2. **Thread Safety**: All UI updates must happen on main thread; use `Idle.add()` for background→UI communication
3. **Memory Management**: Vala handles most cleanup, but close streams explicitly
4. **Localization**: Use `_("Translatable text")` for all user-facing strings
5. **Installation Types**: Handle System/Flatpak/Snap variations for each launcher

## Debug Environment
Set `G_MESSAGES_DEBUG=all` for verbose logging. Key debug points:
- VDF parsing steps with start/end positions
- HTTP request/response cycles
- File system operations
- Model data loading sequences
