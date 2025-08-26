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
            public bool apply_launch_override { get; set; }
            public bool preserve_ini { get; set; }

            public InstallOptions () {
                injection_name = "dxgi";
                disable_spoofing = false;
                use_bleeding_edge = true;
                apply_launch_override = true;
                preserve_ini = false;
            }
        }

        // Lightweight detection result
        public class State : Object {
            public bool installed { get; set; }
            public string? injection_file { get; set; }
            public string? version { get; set; }
        }

        // Persistent state entry (saved to JSON)
        private class StateEntry : Object {
            public string injection { get; set; }
            public string? version { get; set; }
            public string? hash { get; set; }
            public bool backup_created { get; set; }
            public string? original_launch_options { get; set; }
            public bool applied_override { get; set; }
            public string? exe_dir { get; set; }
        }

        private Gee.HashMap<string,StateEntry> saved_state = new Gee.HashMap<string,StateEntry>();
        public string? last_error { get; private set; }

        private OptiScalerManager() {
            load_state();
        }

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
    private const string STATE_FILE_NAME = "state.json";

        private string get_cache_dir() {
            string base_dir = Environment.get_user_cache_dir();
            string dir = Path.build_filename(base_dir, Globals.APP_NAME, CACHE_DIR_NAME);
            if (!FileUtils.test(dir, FileTest.IS_DIR)) {
                try { DirUtils.create(dir, 0755); } catch (Error e) { message(e.message); }
            }
            return dir;
        }

        private string? find_bundle_asset_url(string json) {
            try {
                var parser = new Json.Parser();
                parser.load_from_data(json, -1);
                var root = parser.get_root();
                if (root == null) return null;
                var obj = root.get_object();
                if (obj == null) return null;
                if (!obj.has_member("assets")) return null;
                var assets = obj.get_array_member("assets");
                if (assets == null) return null;
                for (uint i = 0; i < assets.get_length(); i++) {
                    var asset = assets.get_object_element(i);
                    if (asset.has_member("browser_download_url")) {
                        string url = asset.get_string_member("browser_download_url");
                        if (url.index_of("BUNDLED_OptiScaler_") >= 0 && (url.has_suffix(".7z") || url.has_suffix(".zip"))) {
                            return url;
                        }
                    }
                }
            } catch (Error e) {
                message("OptiScaler JSON parse error: %s".printf(e.message));
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

        private bool deploy_minimal(string extracted_root, string game_dir, string injection_name, bool preserve_ini, bool disable_spoofing, out string? deployed_hash) {
            // Minimal deployment: Look for OptiScaler.dll and OptiScaler.ini; copy into game_dir as <injection_name>.dll + OptiScaler.ini
            // TODO: Support advanced file set + spoof toggle edits + hash/version recording.
            string dll_source = Path.build_filename(extracted_root, "OptiScaler.dll");
            string ini_source = Path.build_filename(extracted_root, "OptiScaler.ini");
            if (!FileUtils.test(dll_source, FileTest.IS_REGULAR) || !FileUtils.test(ini_source, FileTest.IS_REGULAR)) {
                message("OptiScaler bundle missing core files");
                deployed_hash = null;
                return false;
            }
            string injection_filename = injection_name + ".dll";
            if (!ensure_backup_if_needed(game_dir, injection_filename)) {
                message("OptiScaler deploy aborted: could not backup existing %s".printf(injection_filename));
                deployed_hash = null;
                return false;
            }
            string dll_target = Path.build_filename(game_dir, injection_filename);
            string ini_target = Path.build_filename(game_dir, "OptiScaler.ini");
            try {
                File dll_src = File.new_for_path(dll_source);
                File dll_dst = File.new_for_path(dll_target);
                if (dll_dst.query_exists()) dll_dst.delete(); // safe after backup
                dll_src.copy(dll_dst, FileCopyFlags.OVERWRITE);
                if (!preserve_ini || !FileUtils.test(ini_target, FileTest.IS_REGULAR)) {
                    File ini_src = File.new_for_path(ini_source);
                    File ini_dst = File.new_for_path(ini_target);
                    if (ini_dst.query_exists()) ini_dst.delete();
                    ini_src.copy(ini_dst, FileCopyFlags.OVERWRITE);
                }
                if (disable_spoofing) {
                    apply_ini_spoof_toggle(ini_target, true);
                }
            } catch (Error e) {
                message(e.message);
                deployed_hash = null;
                return false;
            }
            // compute hash
            deployed_hash = compute_sha256(dll_target);
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
            string? dll_hash;
            if (!deploy_minimal(extracted_root, game_dir, opts.injection_name, opts.preserve_ini, opts.disable_spoofing, out dll_hash)) {
                message("Deploy failed");
                return false;
            }
            // Launch options override
            string? original_launch_options = null;
            bool applied_override = false;
            if (opts.apply_launch_override) {
                var steam_launcher = steam_game.launcher as ProtonPlus.Models.Launchers.Steam;
                if (steam_launcher != null) {
                    original_launch_options = steam_game.launch_options;
                    string merged = ProtonPlus.Utils.LaunchOptions.ensure_override(original_launch_options, opts.injection_name);
                    if (merged != original_launch_options) {
                        bool ok = steam_game.change_launch_options(merged, steam_launcher.profile.localconfig_path);
                        applied_override = ok && merged != original_launch_options;
                        if (!ok) {
                            last_error = _("Failed to update launch options");
                        }
                    }
                }
            }
            // Persist state
            var entry = new StateEntry();
            entry.injection = opts.injection_name + ".dll";
            entry.version = null; // placeholder until version extraction
            entry.hash = dll_hash;
            entry.backup_created = last_backup_created;
            entry.original_launch_options = original_launch_options;
            entry.applied_override = applied_override;
            entry.exe_dir = game_dir; // currently same as installdir; future exe scan may differ
            saved_state.set("steam:" + steam_game.appid.to_string(), entry);
            save_state();
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
            // Launch options cleanup (conservative): only if we recorded we applied and can safely revert to original
            var key = "steam:" + steam_game.appid.to_string();
            StateEntry? entry = saved_state.get(key);
            if (entry != null && entry.applied_override && entry.original_launch_options != null) {
                var steam_launcher = steam_game.launcher as ProtonPlus.Models.Launchers.Steam;
                if (steam_launcher != null) {
                    steam_game.change_launch_options(entry.original_launch_options, steam_launcher.profile.localconfig_path);
                }
            }
            if (entry != null) {
                saved_state.unset(key);
                save_state();
            }
            return ok;
        }

        /* ===== Helpers: persistence, hashing, ini editing ===== */
        private string get_state_dir() {
            string base_dir = Environment.get_user_data_dir();
            string dir = Path.build_filename(base_dir, Globals.APP_NAME, CACHE_DIR_NAME);
            if (!FileUtils.test(dir, FileTest.IS_DIR)) {
                try { DirUtils.create_with_parents(dir, 0755); } catch (Error e) { message(e.message); }
            }
            return dir;
        }

        private string get_state_file() {
            return Path.build_filename(get_state_dir(), STATE_FILE_NAME);
        }

        private void load_state() {
            string path = get_state_file();
            if (!FileUtils.test(path, FileTest.IS_REGULAR)) return;
            try {
                var content = ProtonPlus.Utils.Filesystem.get_file_content(path);
                var parser = new Json.Parser();
                parser.load_from_data(content, -1);
                var root = parser.get_root();
                if (root == null) return;
                var obj = root.get_object();
                if (obj == null) return;
                foreach (string key in obj.get_members()) {
                    var entry_obj = obj.get_object_member(key);
                    var e = new StateEntry();
                    e.injection = entry_obj.get_string_member("injection");
                    if (entry_obj.has_member("version")) e.version = entry_obj.get_string_member("version");
                    if (entry_obj.has_member("hash")) e.hash = entry_obj.get_string_member("hash");
                    if (entry_obj.has_member("backup_created")) e.backup_created = entry_obj.get_boolean_member("backup_created");
                    if (entry_obj.has_member("original_launch_options")) e.original_launch_options = entry_obj.get_string_member("original_launch_options");
                    if (entry_obj.has_member("applied_override")) e.applied_override = entry_obj.get_boolean_member("applied_override");
                    if (entry_obj.has_member("exe_dir")) e.exe_dir = entry_obj.get_string_member("exe_dir");
                    saved_state.set(key, e);
                }
            } catch (Error e) { message("OptiScaler state load failed: %s".printf(e.message)); }
        }

        private void save_state() {
            try {
                var builder = new Json.Builder();
                builder.begin_object();
                foreach (var key in saved_state.keys) {
                    var e = saved_state.get(key);
                    builder.set_member_name(key);
                    builder.begin_object();
                    builder.set_member_name("injection"); builder.add_string_value(e.injection);
                    if (e.version != null) { builder.set_member_name("version"); builder.add_string_value(e.version); }
                    if (e.hash != null) { builder.set_member_name("hash"); builder.add_string_value(e.hash); }
                    builder.set_member_name("backup_created"); builder.add_boolean_value(e.backup_created);
                    if (e.original_launch_options != null) { builder.set_member_name("original_launch_options"); builder.add_string_value(e.original_launch_options); }
                    builder.set_member_name("applied_override"); builder.add_boolean_value(e.applied_override);
                    if (e.exe_dir != null) { builder.set_member_name("exe_dir"); builder.add_string_value(e.exe_dir); }
                    builder.end_object();
                }
                builder.end_object();
                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                string data = gen.to_data(null);
                ProtonPlus.Utils.Filesystem.atomic_write(get_state_file(), data);
            } catch (Error e) { message("OptiScaler state save failed: %s".printf(e.message)); }
        }

        private string? compute_sha256(string path) {
            try {
                FileStream fs = FileStream.open(path, "rb");
                if (fs == null) return null;
                var checksum = new Checksum(ChecksumType.SHA256);
                uint8[] buf = new uint8[8192];
                size_t r = 0;
                while ((r = fs.read(buf)) > 0) {
                    checksum.update(buf, r);
                }
                // FileStream will be closed when going out of scope
                return checksum.get_string();
            } catch (Error e) { message(e.message); return null; }
        }

        private bool apply_ini_spoof_toggle(string ini_path, bool disable) {
            if (!FileUtils.test(ini_path, FileTest.IS_REGULAR)) return false;
            try {
                var content = ProtonPlus.Utils.Filesystem.get_file_content(ini_path);
                string[] lines = content.split("\n");
                bool found = false;
                for (int i = 0; i < lines.length; i++) {
                    var l = lines[i].strip();
                    if (l.has_prefix("Dxgi=")) {
                        lines[i] = "Dxgi=" + (disable ? "false" : "auto");
                        found = true;
                        break;
                    }
                }
                if (!found && disable) {
                    content = content + "\nDxgi=false\n";
                } else if (found) {
                    content = string.joinv("\n", lines);
                }
                ProtonPlus.Utils.Filesystem.modify_file(ini_path, content);
                return true;
            } catch (Error e) { message(e.message); return false; }
        }
    }
}
