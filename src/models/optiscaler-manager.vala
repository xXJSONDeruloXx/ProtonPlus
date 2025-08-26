// OptiScaler Manager - Phase 1 skeleton
// Handles detection + (future) install/remove logic for OptiScaler per game.
// NOTE: Keep initial implementation minimal; expand in later phases.

namespace ProtonPlus.Models {
    public class OptiScalerManager : Object {
        private static OptiScalerManager? _instance;
        public static OptiScalerManager instance {
            get {
                if (_instance == null) {
                    _instance = new OptiScalerManager();
                }
                return _instance;
            }
        }

        // Planned install options structure (expand later when UI implemented)
        public class InstallOptions : Object {
            public string injection_name { get; set; } // without .dll
            public bool disable_spoofing { get; set; }
            public bool use_bleeding_edge { get; set; }

            public InstallOptions () {
                injection_name = "dxgi";
                disable_spoofing = false;
                use_bleeding_edge = true;
            }
        }

        // Lightweight detection result
        public class State : Object {
            public bool installed { get; set; }
            public string? injection_file { get; set; }
            public string? version { get; set; }
        }

        private OptiScalerManager() {}

    // Tracks whether the last install operation created a backup (ephemeral – TODO: persist in state file later)
    private bool last_backup_created = false;

        // Detect whether OptiScaler appears installed for a given game (Steam only initially)
    public State detect(Game game) {
            var state = new State();
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                state.installed = false;
                return state;
            }
            string install_dir = steam_game.installdir;
            if (install_dir == "") {
                state.installed = false;
                return state;
            }
            // Check for known injection dlls in install dir root (initial heuristic only)
            string[] names = {"dxgi.dll", "winmm.dll", "d3d12.dll", "dbghelp.dll", "version.dll", "wininet.dll", "winhttp.dll"};
            foreach (var name in names) {
                var path = Path.build_filename(install_dir, name);
                if (FileUtils.test(path, FileTest.IS_REGULAR)) {
                    // Minimal heuristic: presence of OptiScaler.ini alongside dll suggests install
                    var ini = Path.build_filename(install_dir, "OptiScaler.ini");
                    if (FileUtils.test(ini, FileTest.IS_REGULAR)) {
                        state.installed = true;
                        state.injection_file = name;
                        // Placeholder: version extraction could parse ini later
                        state.version = null;
                        return state;
                    }
                }
            }
            state.installed = false;
            return state;
        }

        // Minimal constants for Phase 1 (bleeding-edge bundle only)
        private const string BLEEDING_EDGE_REPO_API = "https://api.github.com/repos/xXJSONDeruloXx/OptiScaler-Bleeding-Edge/releases/latest";
        private const string CACHE_DIR_NAME = "optiscaler";

        private string get_cache_dir() {
            string base_dir = Environment.get_user_cache_dir();
            string dir = Path.build_filename(base_dir, Globals.APP_NAME, CACHE_DIR_NAME);
            if (!FileUtils.test(dir, FileTest.IS_DIR)) {
                try { DirUtils.create(dir, 0755); } catch (Error e) { message(e.message); }
            }
            return dir;
        }

        private string? find_bundle_asset_url(string json) {
            // Very lightweight parse: look for browser_download_url lines containing BUNDLED_OptiScaler
            // TODO: Replace with proper JSON-GLib parsing + asset selection if multiple present.
            string pattern = "\"browser_download_url\"";
            string[] lines = json.split("\n");
            foreach (var line in lines) {
                if (line.index_of(pattern) >= 0 && line.index_of("BUNDLED_OptiScaler_") >= 0) {
                    int first_quote = line.index_of("http");
                    if (first_quote >= 0) {
                        int end_quote = line.index_of_char('"', first_quote);
                        if (end_quote > first_quote) {
                            return line.substring(first_quote, end_quote - first_quote);
                        }
                    }
                }
            }
            return null;
        }

        private async string? download_bundle(string url) {
            string cache = get_cache_dir();
            // Derive filename from url tail
            string fname = "bundle.7z";
            int slash = url.last_index_of_char('/');
            if (slash >= 0 && slash + 1 < url.length) fname = url.substring(slash + 1);
            string path = Path.build_filename(cache, fname);
            bool ok = yield ProtonPlus.Utils.Web.Download(url, path);
            if (!ok) return null;
            return path;
        }

        private async string? extract_bundle(string archive_path) {
            // Reuse existing libarchive helper via Utils.Filesystem.extract expecting pattern (install_location + tool_name + extension)
            // For now, copy/rename into expected structure: we need tool_name + extension split.
            string dir = Path.get_dirname(archive_path);
            string base_name = Path.get_basename(archive_path); // e.g. BUNDLED_OptiScaler_xxx.7z
            string tool_name = base_name;
            string extension = "";
            int dot = base_name.last_index_of_char('.');
            if (dot > 0) {
                tool_name = base_name.substring(0, dot);
                extension = base_name.substring(dot); // includes .
            }
            // Utils.Filesystem.extract wants (install_location, tool_name, extension, cancel_cb)
            string install_location = dir + Path.DIR_SEPARATOR_S; // ensure trailing slash for concatenation inside extract
            string result = yield ProtonPlus.Utils.Filesystem.extract(install_location, tool_name, extension, () => { return false; });
            return result; // path to extracted top-level directory
        }

        private bool ensure_backup_if_needed(string game_dir, string injection_filename) {
            string target = Path.build_filename(game_dir, injection_filename);
            last_backup_created = false;
            if (!FileUtils.test(target, FileTest.IS_REGULAR)) {
                return true; // nothing to backup
            }
            // Heuristic: if OptiScaler.ini is present we assume it's already ours (update scenario) → skip backup
            string ini = Path.build_filename(game_dir, "OptiScaler.ini");
            if (FileUtils.test(ini, FileTest.IS_REGULAR)) {
                return true; // treat as ours
            }
            string backup = target + ".b";
            if (FileUtils.test(backup, FileTest.IS_REGULAR)) {
                // Backup already exists – assume previously created.
                return true;
            }
            // Attempt atomic rename to create backup.
            if (FileUtils.rename(target, backup) != 0) {
                message("OptiScaler: failed to create backup for %s".printf(target));
                return false; // fail to avoid overwriting foreign mod silently
            }
            last_backup_created = true; // TODO: persist this info in future state JSON
            return true;
        }

        private bool deploy_minimal(string extracted_root, string game_dir, string injection_name) {
            // Minimal deployment: Look for OptiScaler.dll and OptiScaler.ini; copy into game_dir as <injection_name>.dll + OptiScaler.ini
            // TODO: Support advanced file set + spoof toggle edits + hash/version recording.
            string dll_source = Path.build_filename(extracted_root, "OptiScaler.dll");
            string ini_source = Path.build_filename(extracted_root, "OptiScaler.ini");
            if (!FileUtils.test(dll_source, FileTest.IS_REGULAR) || !FileUtils.test(ini_source, FileTest.IS_REGULAR)) {
                message("OptiScaler bundle missing core files");
                return false;
            }
            string injection_filename = injection_name + ".dll";
            if (!ensure_backup_if_needed(game_dir, injection_filename)) {
                message("OptiScaler deploy aborted: could not backup existing %s".printf(injection_filename));
                return false;
            }
            string dll_target = Path.build_filename(game_dir, injection_filename);
            string ini_target = Path.build_filename(game_dir, "OptiScaler.ini");
            try {
                File dll_src = File.new_for_path(dll_source);
                File dll_dst = File.new_for_path(dll_target);
                if (dll_dst.query_exists()) dll_dst.delete(); // safe after backup
                dll_src.copy(dll_dst, FileCopyFlags.OVERWRITE);

                File ini_src = File.new_for_path(ini_source);
                File ini_dst = File.new_for_path(ini_target);
                if (ini_dst.query_exists()) ini_dst.delete();
                ini_src.copy(ini_dst, FileCopyFlags.OVERWRITE);
            } catch (Error e) {
                message(e.message);
                return false;
            }
            // TODO: compute and store hash/version for future detection/persistence.
            return true;
        }

        // Phase 1 minimal install: download bleeding-edge bundle & deploy core files. Returns true on success.
        public async bool install(Game game, InstallOptions opts) throws Error {
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                message("OptiScaler install: non-Steam game unsupported in Phase 1");
                return false;
            }
            string game_dir = steam_game.installdir;
            if (game_dir == "") {
                message("OptiScaler install: empty game directory");
                return false;
            }
            // 1. Fetch latest bleeding-edge release JSON
            string? json = yield ProtonPlus.Utils.Web.GET(BLEEDING_EDGE_REPO_API);
            if (json == null) { message("Failed to fetch release info"); return false; }
            // 2. Find bundle asset URL
            string? asset_url = find_bundle_asset_url(json);
            if (asset_url == null) { message("No bundle asset found in release"); return false; }
            // 3. Download bundle
            string? archive_path = yield download_bundle(asset_url);
            if (archive_path == null) { message("Download failed"); return false; }
            // 4. Extract bundle
            string? extracted_root = yield extract_bundle(archive_path);
            if (extracted_root == null || extracted_root == "") { message("Extraction failed"); return false; }
            // 5. Deploy minimal set (injection name currently only dxgi by default)
            if (!deploy_minimal(extracted_root, game_dir, opts.injection_name)) {
                message("Deploy failed");
                return false;
            }
            // TODO: Launch options override (ensure_override) – later step.
            // TODO: INI spoof toggle editing.
            // TODO: State persistence.
            return true;
        }

        public async bool remove(Game game) throws Error {
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                message("OptiScaler remove: non-Steam game unsupported in Phase 1");
                return false;
            }
            string game_dir = steam_game.installdir;
            if (game_dir == "") {
                message("OptiScaler remove: empty game directory");
                return false;
            }
            var state = detect(game);
            if (!state.installed || state.injection_file == null) {
                // Nothing to remove; treat as success (idempotent)
                return true;
            }
            string injection_path = Path.build_filename(game_dir, state.injection_file);
            string ini_path = Path.build_filename(game_dir, "OptiScaler.ini");
            string backup_path = injection_path + ".b";
            bool ok = true;
            try {
                if (FileUtils.test(injection_path, FileTest.IS_REGULAR)) {
                    if (!ProtonPlus.Utils.Filesystem.delete_file(injection_path)) {
                        message("OptiScaler remove: failed to delete injection file");
                        ok = false;
                    }
                }
                if (FileUtils.test(ini_path, FileTest.IS_REGULAR)) {
                    if (!ProtonPlus.Utils.Filesystem.delete_file(ini_path)) {
                        message("OptiScaler remove: failed to delete ini file");
                        ok = false;
                    }
                }
                // Restore backup if present and original now gone
                if (FileUtils.test(backup_path, FileTest.IS_REGULAR) && !FileUtils.test(injection_path, FileTest.IS_REGULAR)) {
                    if (FileUtils.rename(backup_path, injection_path) != 0) {
                        message("OptiScaler remove: failed to restore backup");
                        ok = false;
                    }
                }
            } catch (Error e) {
                message(e.message);
                ok = false;
            }
            // TODO: Remove state persistence entry when implemented.
            return ok;
        }
    }
}
