namespace ProtonPlus.Widgets {
    // Minimal Phase 1 OptiScaler dialog: install/remove + state display.
    public class OptiScalerDialog : Adw.Dialog {
        private Models.Game game;
    private Gtk.Label status_label;
    private Gtk.Label detail_label;
    private Gtk.Button install_button;
        private Gtk.Button remove_button;
        private Gtk.Button close_button;
        private Gtk.Box button_box;
        private Gtk.Box root_box;
        private Gtk.Spinner spinner;
        private bool working = false;
    // New controls
    private Adw.ComboRow injection_row;
    private Adw.SwitchRow spoof_row;
    private Adw.SwitchRow override_row;
    private Adw.SwitchRow preserve_ini_row;
    private Adw.PreferencesGroup options_group;
    private Gtk.Label error_label;

        public OptiScalerDialog(Models.Game game) {
            this.game = game;
            title = _("OptiScaler");

            status_label = new Gtk.Label("");
            status_label.set_wrap(true);
            status_label.set_xalign(0.0f);
            detail_label = new Gtk.Label("");
            detail_label.set_wrap(true);
            detail_label.set_xalign(0.0f);

            spinner = new Gtk.Spinner();
            spinner.set_spinning(false);

            install_button = new Gtk.Button.with_label(_("Install"));
            install_button.clicked.connect(on_install_clicked);
            remove_button = new Gtk.Button.with_label(_("Remove"));
            remove_button.clicked.connect(on_remove_clicked);
            close_button = new Gtk.Button.with_label(_("Close"));
            close_button.clicked.connect(() => { close(); });

            button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            button_box.append(install_button);
            button_box.append(remove_button);
            button_box.append(close_button);

            root_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            root_box.set_margin_top(12);
            root_box.set_margin_bottom(12);
            root_box.set_margin_start(18);
            root_box.set_margin_end(18);
            root_box.append(status_label);
            root_box.append(detail_label);
            root_box.append(spinner);
            // Build options group
            options_group = new Adw.PreferencesGroup();
            injection_row = new Adw.ComboRow();
            injection_row.title = _("Injection DLL name");
            string[] injections = {"dxgi","winmm","d3d12","dbghelp","version","wininet","winhttp"};
            var model = new Gtk.StringList(null);
            foreach (var s in injections) model.append(s);
            injection_row.set_model(model);
            injection_row.selected = 0;

            spoof_row = new Adw.SwitchRow();
            spoof_row.title = _("Disable DLSS spoofing (set Dxgi=false)");
            spoof_row.active = false;

            override_row = new Adw.SwitchRow();
            override_row.title = _("Apply WINEDLLOVERRIDES automatically");
            override_row.active = true;

            preserve_ini_row = new Adw.SwitchRow();
            preserve_ini_row.title = _("Preserve existing OptiScaler.ini");
            preserve_ini_row.active = false;

            options_group.add(injection_row);
            options_group.add(spoof_row);
            options_group.add(override_row);
            options_group.add(preserve_ini_row);
            root_box.append(options_group);

            error_label = new Gtk.Label("");
            error_label.add_css_class("error");
            error_label.set_xalign(0.0f);
            root_box.append(error_label);
            root_box.append(button_box);

            set_child(root_box);

            update_state();
        }

        private void update_state() {
            var state = Models.OptiScalerManager.instance.detect(game);
            if (state.installed) {
                string ver = state.version != null ? state.version : _("unknown version");
                status_label.set_label(_("Status: Installed") + (state.injection_file != null ? " (" + state.injection_file + ")" : ""));
                var details = _("Version: ") + ver;
                if (state.exe_dir != null && state.exe_dir.length > 0) details += "\n" + _("Exe Dir: ") + state.exe_dir;
                if (state.conflict) details += "\n" + _("Warning: Hash mismatch (possible conflict)");
                detail_label.set_label(details);
                install_button.set_sensitive(false);
                remove_button.set_sensitive(true);
            } else {
                status_label.set_label(_("Status: Not Installed"));
                detail_label.set_label("");
                install_button.set_sensitive(true);
                remove_button.set_sensitive(false);
            }
            if (working) {
                install_button.set_sensitive(false);
                remove_button.set_sensitive(false);
                close_button.set_sensitive(false);
            } else {
                close_button.set_sensitive(true);
            }
        }

        private void set_working(bool value) {
            working = value;
            if (value) {
                spinner.set_spinning(true);
            } else {
                spinner.set_spinning(false);
            }
            update_state();
        }

        private async void do_install() {
            var opts = new Models.OptiScalerManager.InstallOptions();
            // Gather selections
            opts.injection_name = ((Gtk.StringList) injection_row.get_model()).get_string(injection_row.selected);
            opts.disable_spoofing = spoof_row.active;
            opts.apply_launch_override = override_row.active;
            opts.preserve_ini = preserve_ini_row.active;
            bool ok = yield Models.OptiScalerManager.instance.install(game, opts);
            if (!ok) {
                var err = Models.OptiScalerManager.instance.last_error;
                if (err != null && err.length > 0) error_label.set_label(err);
                Application.window.add_toast(new Adw.Toast(_("OptiScaler installation failed")));
            } else {
                error_label.set_label("");
                Application.window.add_toast(new Adw.Toast(_("OptiScaler installed")));
            }
            set_working(false);
            update_state();
        }

        private async void do_remove() {
            bool ok = yield Models.OptiScalerManager.instance.remove(game);
            if (!ok) {
                Application.window.add_toast(new Adw.Toast(_("OptiScaler removal failed")));
            } else {
                Application.window.add_toast(new Adw.Toast(_("OptiScaler removed")));
            }
            set_working(false);
            update_state();
        }

        private void on_install_clicked() {
            if (working) return;
            set_working(true);
            do_install.begin();
        }

        private void on_remove_clicked() {
            if (working) return;
            set_working(true);
            do_remove.begin();
        }
    }
}
