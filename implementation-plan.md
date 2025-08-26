Fetching external references (OptiScaler wiki + setup script + Decky Framegen script) to ground an implementation plan. I'll refetch external pages correctly by including a query string to extract core content about install steps. Drafting an implementation blueprint for OptiScaler integration—below is a structured, end‑to‑end plan you can refine before we start coding.

## Decisions Summary (Resolved from Open Questions)
Default Source: Bleeding-edge bundled release (latest).
State Handling (Initial): Simplest possible — rely on on-disk detection; lightweight JSON state may be added later only if needed.
Launch Options Modification: Inject WINEDLLOVERRIDES snippet immediately to the left of %command% if present; if no %command% append at end. Merge with existing WINEDLLOVERRIDES variable without duplication.
Scope (Initial UI): Steam games only; other launchers deferred.
Testing Approach: Test-driven where practical; start with focused unit-level tests (string launch options manipulation) before broader install logic.

## Checklist (Scope Definition)
- Identify feature surface (per-game vs global) and UX entry points
- Source selection (official vs bundled bleeding-edge assets)
- GitHub asset discovery + download logic
- Archive extraction (7z/zip) with libarchive
- Game executable path resolution (including Unreal heuristics)
- File deployment + safe backups + selectable inject filename
- INI post-processing (optional DLSS spoofing toggle)
- Per‑game install status detection + update/removal flow
- Steam launch options override automation (WINEDLLOVERRIDES)
- Data/state persistence (so UI reflects installed status)
- Async workflow + progress reporting + error handling
- UI dialog design (install/update/remove/configure)
- Removal/uninstall routine (restore backups / cleanup)
- Edge cases & safeguards
- Testing strategy (unit-ish components + manual QA steps)

## Progress Update (Aug 25 2025)
Legend: [x] done, [~] partial/in progress, [ ] pending.

Core Foundations:
- [x] Decisions captured (bleeding-edge default, Steam-only scope for Phase 1, simple on-disk detection, launch override merge rules, TDD for pure logic).
- [x] `OptiScalerManager` implemented with detection heuristic.
- [x] Launch options merge utility (`Utils.LaunchOptions.ensure_override`) + unit test (idempotent merge verified).
- [x] Minimal install workflow: GitHub latest bleeding-edge release fetch → asset URL scrape → download → extract via existing filesystem helper → deploy core files (`OptiScaler.dll` renamed to injection target + `OptiScaler.ini`).
- [x] Backup & restore logic for existing injection target (renames to `.b` and restores on removal) with heuristic to skip if already OptiScaler.
- [x] Removal workflow: delete injection + ini, restore backup if present.
- [x] Minimal UI dialog (`OptiScalerDialog`) with install/remove actions, spinner, simple status; integrated via `ExtraButton` popover (Steam games only).
- [x] Menu item integration & diagnostic verification (temporary debug output since removed).
- [ ] Launch options auto-apply integration (utility exists; not yet invoked by install flow).
- [ ] State persistence (planned JSON) – not started.
- [ ] Advanced detection (hash/version extraction, Unreal exe scan, conflict detection) – not started.
- [ ] INI spoof toggle application – not started (placeholder in `InstallOptions`).
- [ ] Alternate injection filename selection UI – not yet surfaced (manager supports only default name path variable).
- [ ] Support file deployment beyond core dll + ini (libs, directories) – deferred.

Technical Debt / TODOs:
- Replace ad-hoc release JSON string scrape with proper JSON-GLib parsing & asset selection (handles multiple assets, errors robustly).
- Persist backup metadata / install state (so detection can distinguish foreign mods vs ours without relying solely on `.ini`).
- Improve error reporting (currently logs only; dialog surfaces generic failure toast).
- Strengthen extraction/deployment validation (hashes, size checks).
- Provide unit tests for backup/restore logic and removal idempotence.

Risk Notes (Updated):
- Overwrite risk mitigated by backup rename, but lack of hash/version means potential misclassification of existing mod remains.
- Network/API failure still only produces generic toast; user lacks actionable message.
- String-based release parsing brittle to upstream format changes.

Next Immediate Steps (Phase 1b):
1. Invoke launch options override (optional checkbox to be added in dialog) using existing merge utility. [ ]
2. Add INI spoof toggle editing (simple search/replace `Dxgi=auto` vs `Dxgi=false`). [ ]
3. Introduce basic state persistence (JSON) storing injection name + simple version string (release tag) + backup created flag. [ ]
4. Upgrade release parsing to JSON-GLib with error handling + asset selection fallback. [ ]
5. Add alternate injection filename selector in dialog (dropdown). [ ]

Planned Later (Phase 2+):
- Expand detection heuristics (Unreal exe scan) + per-game exe selection.
- Advanced conflict detection (hash other mod dll; warn user).
- Support file deployment for additional bundled libs and cleanup logic on removal.
- Rich error surface (detail label in dialog) + retry button.

Quality Gates Status (Current):
- Build: Passing (warnings: unhandled GLib.Error in dialog install/remove calls, unreachable catch clauses in manager—safe but to clean up).
- Tests: Launch options test passing; no new tests yet for install/remove.

Open Items (Active):
- Decide user-facing messaging for backup creation (inform after first overwrite?).
- Determine minimal state JSON path & schema (likely under `~/.local/share/ProtonPlus/optiscaler/state.json`).
- Evaluate whether to gate install when game appears running (optional pre-check).

This section will be updated after launch options integration and state persistence are implemented.

## 1. Feature Shape & User Flow
Target: “One‑click (guided) OptiScaler setup” from each Steam (and later other launcher) game row.

Entry Points:
- Add “OptiScaler” item to the existing `ExtraButton` popover OR a dedicated icon (only for Windows games / DX12/Vulkan plausible environments).
- Status icon indicator (optional follow‑up) when installed.

User Flow (Happy Path):
1. User clicks “Setup OptiScaler”.
2. Dialog opens:
   - Detect game exe path (installdir + heuristic scan for Shipping.exe or known subpaths).
   - Shows: Install status, detected GPU vendor (optional), injection filename selector (default dxgi.dll), checkboxes:
     - Enable DLSS spoofing (sets Dxgi=auto vs Dxgi=false)
     - Use bundled bleeding-edge build (vs latest stable)
     - Preserve existing OptiScaler.ini (if updating)
   - “Install” button (or “Update” / “Remove” if already installed).
3. Progress modal: download → extract → deploy → optionally patch launch options.
4. Success summary + copyable launch override text if not auto-applied.

## 2. Source & Asset Strategy
Option A (stable official):
- GitHub API: `GET https://api.github.com/repos/optiscaler/OptiScaler/releases/latest`
- Find asset whose name starts with `OptiScaler_v` (but this may lack bundled external libs).

Option B (preferred automated bundle):
- Repo: `xXJSONDeruloXx/OptiScaler-Bleeding-Edge`
- Asset pattern: `BUNDLED_OptiScaler_*.7z`
- Provide toggle “Use bleeding-edge bundle”.
Fallback if API fails: allow user to provide local archive path.

Mitigation:
- Validate filename (allow only expected safe pattern).
- Size sanity check (non-zero, under e.g. 200 MB).

## 3. Download & Extract
Existing Tools:
- `Utils.Web.Download()` for streaming with progress; may add speed/time callbacks to UI.
- `libarchive` already linked: implement `Utils.Filesystem.extract_archive(archive_path, dest_dir)` if not present (wrap libarchive streaming).

Temporary staging:
- Place downloads in `$XDG_CACHE_HOME/ProtonPlus/optiscaler/` (create if missing).
- Extract to staging, then selectively copy files.

## 4. Game Executable Path Resolution
Heuristics (borrow logic from Decky-Framegen `fgmod.sh`):
- Start with `Models.Games.Steam.installdir` (already stored).
- Unreal detection: if `<installdir>/Engine` exists, search depth ≤4 for `*Binaries/Win64/*Shipping.exe` excluding `Engine`.
- Fallback: scan for `.exe` with notable names in common subdirectories (`bin/x64`, `Retail`, `Binaries/Win64`, etc.).
- If multiple candidates → let user pick from dropdown.
- Persist chosen path per game (store in small JSON under config directory: e.g. `~/.local/share/ProtonPlus/optiscaler/installed.json` keyed by launcher+appid).

## 5. Injection Filename Handling
Supported filenames (list from spec):
- `dxgi.dll` (default)
- `winmm.dll`
- `d3d12.dll`
- `dbghelp.dll`
- `version.dll`
- `wininet.dll`
- `winhttp.dll`
- `OptiScaler.asi` (edge; only if ASI loader present—maybe hide unless user checks “Show all”)

Model:
- Enum `OptiScalerInjectionName`
- Map to string
- Validate no conflicting existing mod loader (e.g. if dxgi.dll already in use and not OptiScaler backup scenario).

Backup Policy:
- If target file exists and not already an OptiScaler copy:
  - Move to `filename.b` (only if no existing `.b`).
- On removal:
  - Delete installed injection file + associated OptiScaler payload libs
  - Restore `filename.b` if present.

## 6. Deployment Steps
From extracted bundle:
- Always copy:
  - Core: selected injection dll (rename `OptiScaler.dll`)
  - `OptiScaler.ini` (unless preserve requested)
  - Supporting libs:
    - `amd_fidelityfx_dx12.dll`, `amd_fidelityfx_vk.dll`, `nvapi64.dll`, `nvngx.dll`, `amdxcffx64.dll`, `libxess.dll`/`libxess_dx11.dll`, `dlssg_to_fsr3_amd_is_better.dll`, `fakenvapi.ini`, `D3D12_Optiscaler` dir, `DlssOverrides` dir.
- Conditional INI patch:
  - For “Disable DLSS spoofing” set `Dxgi=false` (sed-like replace of `Dxgi=auto`).
  - Future: FSR4 toggles once Mesa version detection is stable (deferred placeholder).

## 7. Steam Launch Options Override
Offer checkbox: “Add WINEDLLOVERRIDES automatically”.
Logic:
- Retrieve current launch options via `SteamProfile.launch_options_hashtable`.
- If no existing `WINEDLLOVERRIDES=`, prepend:
  - `WINEDLLOVERRIDES=<injection>=n,b %command%`
- If exists but missing injection name, merge intelligently (avoid duplicates, keep order).
- Write back using existing `change_launch_options()` on the Game (ensure escaping preserved).
Safety:
- Display resulting string before applying; allow user to skip.

## 8. Detection of Existing Installation
Criteria:
- Presence of any supported injection filename whose SHA256 matches previously installed OptiScaler (store hash in state file) OR presence of `OptiScaler.ini` with recognizable header.
- If mismatch & file exists ⇒ warn potential conflict (other mod).
- Provide “Force Install (backup and overwrite)” option.

State file structure (JSON example):
```
{
  \"steam:appid:123456\": {
     \"injection\": \"dxgi.dll\",
     \"hash\": \"abc123...\", 
     \"version\": \"0.7.7-pre12\",
     \"bundle_type\": \"bleeding-edge\",
     \"exe_dir\": \"/path/to/bin/x64\"
  }
}
```

## 9. Data & Code Additions
New Files (planned):
- `src/models/optiscaler-manager.vala` (singleton or namespace):
  - `public async bool install(Game game, InstallOptions opts, progress_cb)`
  - `public bool is_installed(Game game)`
  - `public async bool remove(Game game)`
  - `public GameState? get_state(Game game)`
- `src/widgets/games/optiscaler-dialog.vala`
- `src/utils/archive.vala` (if needed for generic extraction)
- `data/optiscaler.schema.json` (optional—if we formalize state) or simple local JSON in filesystem (no install packaging).
- Extend `ExtraButton` to add menu item.

Re-use:
- `Utils.Web.Download`
- `Utils.Filesystem` for atomic writes/backups

## 10. Async & UI Considerations
- All network + extraction done with `async` + yield; update UI through main thread using `Idle.add()`.
- Provide progress bar:
  - Stages: “Downloading…”, “Extracting…”, “Deploying…”, “Patching launch options…”
  - If we can get byte progress from Download callback, reflect percent; else stage-based increments.

Error Surface:
- Network failure (show retry)
- Archive parse error (suggest manual install)
- Permission denied (user moved library to read-only path)
- Injection filename conflict (existing mod). Offer backup & override.

## 11. Removal Workflow
- Confirm dialog
- Delete injection dll, OptiScaler.ini (optional: preserve if user chooses)
- Remove known support libs only if they match expected names & file size threshold (avoid deleting unrelated user mods).
- Restore original dll backups (`*.b`).
- Optionally strip the `WINEDLLOVERRIDES=` snippet if we previously added and no other overrides remain (heuristic: pattern match injection + `%command%` at start).

## 12. Edge Cases / Safeguards
Edge cases:
- Non-Windows game (skip)
- Proton prefix path locked (Steam Cloud sync busy) → retry/backoff
- Game running (detect via `pgrep` on exe name; warn user to close)
- Multiple installs (user changes injection name) → manage old injection removal first.
- Multi-library scenario (Steam game relocated) → if installdir changes, treat as new install but allow “migrate” (copy state).

## 13. Testing Strategy
Manual scenarios:
1. Fresh install on a DX12 game (Cyberpunk) with default settings.
2. Install with spoofing disabled.
3. Update path: re-run install selecting different injection name -> confirm old removed / backup restored.
4. Removal restores original dxgi.dll if backed up.
5. Launch options patch idempotence: multiple installs should not duplicate override.
Automated (lightweight):
- Unit-ish: mock `Download` by injecting test asset file.
- Archive extraction test with a small curated sample (add under `tests/artifacts/` if we introduce tests later).

## 14. Incremental Delivery Plan
Phase 1: Core backend (manager + download + extraction + deploy) + minimal dialog with install/remove.
Phase 2: Launch options automation + INI spoof toggle.
Phase 3: Advanced detection heuristics (Unreal exe scanning) + status icon + update flow.
Phase 4 (optional): Non-Steam launchers & FSR4 Mesa capability check.

## 15. Potential Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| GitHub API rate limiting | Allow manual URL input / fallback asset list caching |
| Archive format unsupported | Validate with libarchive early; show actionable error |
| Overwriting other mods (e.g. existing dxgi.dll for ReShade) | Detect non-OptiScaler hash & prompt explicit confirmation |
| Launch options corruption | Keep a backup copy of original string in state JSON |
| Future filename expansions | Keep list centralized in enum |

## 16. Future Enhancements (Out of Initial Scope)
- Automatic detection of supported rendering (DX11 vs DX12) via scanning game manifest or probing files.
- Version update notification (compare stored version vs remote latest).
- Inline editing of key OptiScaler.ini values (hot toggles).
- Integration with ProtonGE retrieval to chain improvements.

## 17. (Former) Open Questions — Now Resolved
All prior open questions have been resolved (see Decisions Summary). This section retained for historical traceability; no further action required here for Phase 1.

