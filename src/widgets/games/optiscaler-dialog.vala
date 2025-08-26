namespace ProtonPlus.Widgets {
    // Minimal Phase 1 OptiScaler dialog: install/remove + state display.
    public class OptiScalerDialog : Adw.Dialog {
        private Models.Game game;
        private Gtk.Label status_label;
        private Gtk.Button install_button;
        private Gtk.Button remove_button;
        private Gtk.Button close_button;
        private Gtk.Box button_box;
        private Gtk.Box root_box;
        private Gtk.Spinner spinner;
        private bool working = false;

        public OptiScalerDialog(Models.Game game) {
            this.game = game;
            title = _("OptiScaler");

            status_label = new Gtk.Label("");
            status_label.set_wrap(true);
            status_label.set_xalign(0.0f);

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
            root_box.append(spinner);
            root_box.append(button_box);

            set_child(root_box);

            update_state();
        }

        private void update_state() {
            var state = Models.OptiScalerManager.instance.detect(game);
            if (state.installed) {
                status_label.set_label(_("Status: Installed") + (state.injection_file != null ? " (" + state.injection_file + ")" : ""));
                install_button.set_sensitive(false);
                remove_button.set_sensitive(true);
            } else {
                status_label.set_label(_("Status: Not Installed"));
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
            bool ok = yield Models.OptiScalerManager.instance.install(game, opts);
            if (!ok) {
                Application.window.add_toast(new Adw.Toast(_("OptiScaler installation failed")));
            } else {
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
