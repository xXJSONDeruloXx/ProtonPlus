// Duplicate of production Utils.LaunchOptions.ensure_override for isolated unit testing.
// TODO: Replace with direct import once test build path issue resolved.
namespace Utils {
    public class LaunchOptionsTestCopy {
        public static string ensure_override(string current, string injection_basename) {
            string needle = "WINEDLLOVERRIDES=";
            string pair = injection_basename + "=n,b";
            int idx = current.index_of(needle);
            if (idx >= 0) {
                int space = current.index_of(" ", idx);
                string prefix;
                string tail;
                if (space < 0) { prefix = current; tail = ""; } else { prefix = current.substring(0, space); tail = current.substring(space + 1); }
                int eq = prefix.index_of(needle) + needle.length;
                string list = prefix.substring(eq);
                Regex r; try { r = new Regex("(^|;|:)" + Regex.escape_string(injection_basename) + "="); } catch (Error e) { return current; }
                if (r.match(list)) return current;
                if (list.length > 0 && !list.has_suffix(";")) list += ";";
                list += pair;
                var rebuilt = prefix.substring(0, eq) + list;
                return (space < 0) ? rebuilt : rebuilt + " " + tail;
            } else {
                string insertion = needle + pair;
                int cmd = current.index_of("%command%");
                if (cmd >= 0) return current.substring(0, cmd) + insertion + " " + current.substring(cmd);
                else if (current.strip().length == 0) return insertion + " %command%";
                else { string cs = current; if (!cs.has_suffix(" ")) cs += " "; return cs + insertion; }
            }
        }
    }
}
