// Launch Options utility helpers for OptiScaler integration.
// Focus: safe insertion/merge of WINEDLLOVERRIDES for injection dll.

namespace Utils {
    public class LaunchOptions {
        // Insert or merge WINEDLLOVERRIDES for an injection target.
        // Rules:
        // 1. If existing WINEDLLOVERRIDES variable present, merge injection=n,b without duplication.
        // 2. If absent, create new WINEDLLOVERRIDES=entry immediately left of %command% if present, else append at end.
        // 3. Preserve any existing overrides ordering; our injection is appended within the variable list.
        public static string ensure_override(string current, string injection_basename) {
        string needle = "WINEDLLOVERRIDES=";
        string pair = injection_basename + "=n,b"; // Typical override semantics for local native + builtin fallback

        int idx = current.index_of(needle);
        if (idx >= 0) {
            // Extract until first space following the variable or end of string
            int space = current.index_of(" ", idx);
            string prefix;
            string tail;
            if (space < 0) {
                prefix = current.substring(0, current.length);
                tail = "";
            } else {
                prefix = current.substring(0, space);
                tail = current.substring(space + 1);
            }

            // prefix contains e.g. '... WINEDLLOVERRIDES=foo=n,b;bar=n'
            int eq = prefix.index_of(needle) + needle.length;
            string list = prefix.substring(eq);
            // Avoid adding if already present (match injection name followed by =)
            Regex r;
            try { r = new Regex("(^|;|:)" + Regex.escape_string(injection_basename) + "="); }
            catch (Error e) { return current; }
            if (r.match(list)) {
                return current; // already present
            }
            // Append with semicolon separator (Steam typically accepts both ; and :) ; keep using ;
            if (list.length > 0 && !list.has_suffix(";")) {
                list += ";";
            }
            list += pair;
            var rebuilt = prefix.substring(0, eq) + list;
            return (space < 0) ? rebuilt : rebuilt + " " + tail;
        } else {
            // No existing variable
            string insertion = needle + pair;
            int cmd = current.index_of("%command%");
            if (cmd >= 0) {
                // Insert before %command% (with trailing space if needed)
                // Find start of %command% token (could be quoted or preceded by space)
                return current.substring(0, cmd) + insertion + " " + current.substring(cmd);
            } else if (current.strip().length == 0) {
                return insertion + " %command%"; // create canonical form
            } else {
                // Append at end
                string current_str = current;
                if (!current_str.has_suffix(" ")) current_str = current_str + " ";
                return current_str + insertion;
            }
        }
        }
    }
}
