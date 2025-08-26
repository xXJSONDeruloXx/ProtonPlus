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

        // Placeholder async install/remove (Phase 1 will flesh out install path)
    public async bool install(Game game, InstallOptions opts) throws Error {
            // TODO: implement download + extract + deploy
            return false; // not yet implemented
        }

    public async bool remove(Game game) throws Error {
            // TODO: implement removal logic
            return false;
        }
    }
}
