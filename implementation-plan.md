example of install of opti automation
https://github.com/xXJSONDeruloXx/Decky-Framegen/blob/main/defaults/assets/fgmod.sh

example of unpatching a game aka uninstalling opti from the game

https://github.com/xXJSONDeruloXx/Decky-Framegen/blob/main/defaults/assets/fgmod-uninstaller.sh

discussion on this feature:

Vysp3r
ProtonPlus
[FEATURE] Add the ability to easily setup OptiScaler for games #436
Open
@Vysp3r
Description
Vysp3r
opened on Jun 30 · edited by Vysp3r
Owner
In short you just run OptiScaler Setup.bat in the prefix.

https://github.com/optiscaler/OptiScaler/wiki/Automated-Installation

https://github.com/optiscaler/OptiScaler/blob/master/setup_linux.sh

Linux users should add renamed dll to overrides: WINEDLLOVERRIDES=dxgi=n,b %COMMAND% 

Activity

Vysp3r
added 
enhancement
New feature or request
 on Jun 30
xXJSONDeruloXx
xXJSONDeruloXx commented on Jul 7
xXJSONDeruloXx
on Jul 7
Hey! would love to see this implemented. FYI I recently got a PR accepted to have a linux .sh installer bundled, its in the nightlies and should be in next latest release:

optiscaler/OptiScaler#544

also for automations for finding the right paths and installing the files with handling for various renames needed I suggest you check out my project for decky-optiscaler:

https://github.com/xXJSONDeruloXx/decky-optiscaler

and also, optiscaler-bleeding-edge, which I use to automate build and bundle of optiscaler and its semi-vital external libraries, especially for AMD gpu that are so common on linux:

https://github.com/xXJSONDeruloXx/OptiScaler-Bleeding-Edge

(you will probably want to use the BUNDLED_ version .7z from the latest release for the best automation)

Hope this helps! Let me know how I could attempt to support this feature if you can prioritize

Vysp3r
Vysp3r commented on Jul 7
Vysp3r
on Jul 7
Owner
Author
@xXJSONDeruloXx Yeah I saw that they added a .sh file which was really nice to see.

I will def check out your project once I will start working on this.

I basically just download your bundle and extract it to make it work?
That's what I understand from your release description.

xXJSONDeruloXx
xXJSONDeruloXx commented on Jul 7
xXJSONDeruloXx
on Jul 7
Right, the bundled zip has fakenvapi, the dlss3-to-fsr3 DLL, Nvidia sdk extracted DLL auto renamed in the workflow, and FSR 4 DLL extracted from AMD sdk in build.

The main thing you'll need to do is extract all those files to the game execution path (not just the root of the game folder in most cases, like where Steam takes you when you choose "open game files")

Everything else is renamed and in its right place except the OptiScaler.DLL which you'll want to set to one of 8 renames, most typically dxgi.DLL

Also, might want to sed a few things in the OptiScaler.ini file, if you really want high automation. Though this could easily be considered out of scope. Main one you'd need to edit in ini that you can't from the ui in game is the enable of fsr4 on rdna3 which also requires mesa git built from source at least till the august release of 25.2

I also have a repo to pull and hook to mesa-git if you're interested in automating that too do lmk!

Vysp3r
Vysp3r commented on Jul 7
Vysp3r
on Jul 7
Owner
Author
I will just wait for that mesa version to release and add that then.

I'll open another issue for that to keep it in mind.

So if I understand properly here's what I need to do:

Download your bundle
Extract in where the game exec is located
Rename OptiScaler.dll to one of the 8 possible choices (see image 1)
Image 1:
Image

xXJSONDeruloXx
xXJSONDeruloXx commented on Jul 7
xXJSONDeruloXx
on Jul 7 · edited by xXJSONDeruloXx
yes thats the gist! heres what the BUNDLED_ version currently looks like for context

➜  BUNDLED_OptiScaler_v0.7.7-pre12_20250702 tree
.
├── amd_fidelityfx_dx12.dll      # might replace a game included dll, in which case rename game's with .dll.b to backup 
├── amd_fidelityfx_vk.dll          # might replace a game included dll, in which case rename game's with .dll.b to backup
├── amdxcffx64.dll                    # this is FSR 4 DLL (I believe 4.0.1, though 4.0.0 performs way better on RDNA3, cant find where to build from source though ): 
├── D3D12_Optiscaler
│   └── D3D12Core.dll
├── dlssg_to_fsr3_amd_is_better.dll   # DLSSG-To-FSR3 aka Nukems mod. Lets AMD turn DLSS menu options into AMD equivalents
├── DlssOverrides
│   ├── DisableSignatureOverride.reg
│   └── EnableSignatureOverride.reg
├── fakenvapi.ini                                         # config for fakenvapi, which exposes the diss options on AMD, for nukems mod mainly
├── libxess_dx11.dll
├── libxess.dll
├── Licenses
│   ├── DirectX_LICENSE.txt
│   ├── FidelityFX_LICENSE.md
│   └── XeSS_LICENSE.txt
├── nvapi64.dll                               # the dll for fakenvapi, to expose diss options in game so nukems can turn to amd equivalents
├── nvngx.dll                              # already renamed Nvidia dll extracted from their official sdk, needed for fakenvapi and nukems
├── OptiScaler.dll                   # this is what you will rename one of those other filetypes
├── OptiScaler.ini
├── setup_linux.sh
└── setup_windows.bat

4 directories, 19 files
➜  BUNDLED_OptiScaler_v0.7.7-pre12_20250702 




## Decisions Summary (Resolved from Open Questions)
Default Source: Bleeding-edge bundled release (latest).
State Handling: JSON persistence file (hash, injection dll, backup flag, original launch options, override applied) under XDG data dir now active.
Launch Options Modification: Inject WINEDLLOVERRIDES immediately left of %command% if present; else append; idempotent merge (implemented).
Scope (Initial UI): Steam games only; other launchers deferred.
Testing Approach: Start with pure-string utilities (override merge) then add tests for ini spoof + backup/restore (pending).

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

## Progress Update (Aug 25 2025 – refreshed after Phase 1b commit)
Legend: [x] done, [~] partial/in progress, [ ] pending.

Core Foundations:
- [x] Decisions captured (bleeding-edge default, Steam-only scope for Phase 1, simple on-disk detection, launch override merge rules, TDD for pure logic).
- [x] `OptiScalerManager` implemented with detection heuristic.
- [x] Launch options merge utility (`Utils.LaunchOptions.ensure_override`) + unit test (idempotent merge verified).
- [x] Minimal install workflow: GitHub latest bleeding-edge release fetch → JSON asset parse → download → extract via existing filesystem helper → deploy core files (`OptiScaler.dll` renamed to injection target + `OptiScaler.ini`).
- [x] Backup & restore logic for existing injection target (renames to `.b` and restores on removal) with heuristic to skip if already OptiScaler.
- [x] Removal workflow: delete injection + ini, restore backup if present.
- [x] UI dialog (`OptiScalerDialog`) now with install/remove, injection filename dropdown, spoof toggle, preserve INI toggle, launch override toggle, error label.
- [x] Menu item integration & diagnostic verification (temporary debug output since removed).
- [x] Launch options auto-apply integration (applies and records original for rollback; reverts on removal).
- [x] State persistence (JSON file with per‑game entry).
- [x] INI spoof toggle application (Dxgi=false when disabled).
- [x] Alternate injection filename selection UI (dropdown).
- [~] Hash capture (dll SHA256 stored) – version still null; no conflict hash comparison yet.
- [ ] Advanced detection (version extraction, Unreal exe scan, conflict detection) – pending.
- [ ] Support file deployment beyond core dll + ini (supporting libs & directories) – deferred.

Technical Debt / TODOs:
- Version extraction (use release tag) & store in state.
- Add Unreal exe path detection + store exe_dir (currently just installdir).
- Conflict detection: compare existing injection dll hash vs stored.
- Support libs deployment (libxess, nvapi64, etc.) + selective cleanup on removal.
- Improve error reporting (structured codes surfaced in dialog, not only toast).
- Deployment validation (expected file sizes / existence checks for optional libs).
- Unit tests: backup/restore, removal idempotence, ini spoof edit, state round‑trip.
- Reduce warnings (unreachable catch clauses, const discard) in new code.
- Consider making override cleanup smarter (remove only our pair from WINEDLLOVERRIDES if safe).

Risk Notes (Updated):
- Potential misclassification still until version/conflict detection added.
- Limited user feedback on specific failure cause (only one-line error label).
- Lack of supporting libs deployment may reduce effectiveness for some games.
- Override rollback logic assumes original_launch_options hasn't changed externally.

Next Immediate Steps (Phase 1c):
1. Executable path heuristics (Unreal, launcher rewrites) + persist exe_dir. [ ]
2. Version/tag extraction from release JSON stored in state (update existing entries). [ ]
3. Support file deployment & restoration (libs + dll list) with cautious pattern-based removal. [ ]
4. Conflict / foreign mod detection using stored hash vs current; surface warning + force install option. [ ]
5. Unit tests for ini spoof, backup/restore, override rollback. [ ]
6. Error reporting improvements (structured last_error codes + UI detail). [ ]
7. Warning cleanup (remove unreachable catches, adjust property mutability). [ ]

Planned Later (Phase 2+):
- Expand detection heuristics (Unreal exe scan) + per-game exe selection.
- Advanced conflict detection (hash other mod dll; warn user).
- Support file deployment for additional bundled libs and cleanup logic on removal.
- Rich error surface (detail label in dialog) + retry button.

Quality Gates Status (Current):
- Build: Passing (warnings: unhandled GLib.Error in dialog install/remove calls, unreachable catch clauses in manager—safe but to clean up).
- Tests: Launch options test passing; no new tests yet for install/remove.

Open Items (Active):
- User-facing messaging for backup creation (toast vs inline note) – pending.
- Game running detection pre-check (optional) – evaluate.
- Force install UX for conflicts – design.
- Override cleanup strategy upon removal when user changed launch options since install.

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
Phase 2 (completed): Launch options automation + INI spoof toggle + state & UI enhancements.
Phase 3 (in progress planning): Advanced detection heuristics (Unreal exe scanning) + status icon + update flow + support libs.
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

