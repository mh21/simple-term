/******************************************************************************
 * Copyright (C) 2017  Michael Hofmann <mh21@mh21.de>                         *
 *                                                                            *
 * This program is free software; you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by       *
 * the Free Software Foundation; either version 3 of the License, or          *
 * (at your option) any later version.                                        *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License along    *
 * with this program; if not, write to the Free Software Foundation, Inc.,    *
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.                *
 ******************************************************************************/

// TODO:
// - ctrl-click to open link in browser
// - allow dnd drop of filenames

class TerminalWindow : Gtk.Window
{
    private Vte.Terminal terminal;

    private const string match_expr = "(((file|http|ftp|https)://)|(www|ftp)[-A-Za-z0-9]*\\.)[-A-Za-z0-9\\.]+(:[0-9]*)?(/[-A-Za-z0-9_\\$\\.\\+\\!\\*\\(\\),;:@&=\\?/~\\#\\%]*[^]'\\.}>\\) ,\\\"])?";

    public TerminalWindow(Application app, string[] command)
    {
        Object(application: app);

        title = "Terminal";

        terminal = new Vte.Terminal();
        add(terminal);

        terminal.child_exited.connect(() => { destroy(); });
        terminal.decrease_font_size.connect(decrease_font_size_cb);
        terminal.increase_font_size.connect(increase_font_size_cb);
        terminal.char_size_changed.connect(char_size_changed_cb);
        terminal.window_title_changed.connect(window_title_changed_cb);
        terminal.realize.connect(realize_cb);
        terminal.key_press_event.connect(key_press_event_cb);

        terminal.set_audible_bell(false);
        terminal.set_cursor_blink_mode(Vte.CursorBlinkMode.SYSTEM);
        terminal.set_cursor_shape(Vte.CursorShape.BLOCK);
        terminal.set_mouse_autohide(true);
        terminal.set_rewrap_on_resize(true);
        terminal.set_scroll_on_output(false);
        terminal.set_scroll_on_keystroke(true);
        terminal.set_scrollback_lines(-1);

        terminal.set_colors(get_color("black"), get_color("#ffffdd"), {
                get_color("#000000"), get_color("#aa0000"),
                get_color("#00aa00"), get_color("#aa5400"),
                get_color("#0000aa"), get_color("#aa00aa"),
                get_color("#00aaaa"), get_color("#aaaaaa"),
                get_color("#545454"), get_color("#ff5454"),
                get_color("#54ff54"), get_color("#ffff54"),
                get_color("#5454ff"), get_color("#ff54ff"),
                get_color("#54ffff"), get_color("#ffffff") });

        try {
            var regex = new GLib.Regex(match_expr,
                    GLib.RegexCompileFlags.OPTIMIZE |
                    GLib.RegexCompileFlags.MULTILINE,
                    0);
            var tag = terminal.match_add_gregex(regex, 0);
            terminal.match_set_cursor_type(tag, Gdk.CursorType.HAND1);
        } catch (Error e) {
            printerr("Failed to compile regex \"%s\": %s\n", match_expr, e.message);
        }

        try {
            terminal.spawn_sync(Vte.PtyFlags.DEFAULT,
                    null, /* working directory */
                    command,
                    null, /* environment */
                    GLib.SpawnFlags.SEARCH_PATH,
                    null, /* child setup */
                    null, /* child pid */
                    null /* cancellable */);
        } catch (Error e) {
            printerr("Error: %s\n", e.message);
            Idle.add(() => { destroy(); return false; });
        }

        show_all();
    }

    private static Gdk.RGBA? get_color(string str)
    {
        var color = Gdk.RGBA();
        if (!color.parse(str)) {
            printerr("Failed to parse \"%s\" as color.\n", str);
            return null;
        }
        return color;
    }

    private void update_geometry()
    {
        if (!terminal.get_realized())
            return;
        terminal.set_geometry_hints_for_window(this);
    }

    private void char_size_changed_cb()
    {
        update_geometry();
    }

    private void decrease_font_size_cb()
    {
        terminal.set_font_scale(terminal.get_font_scale() / 1.2);
        update_geometry();
    }

    private void increase_font_size_cb()
    {
        terminal.set_font_scale(terminal.get_font_scale() * 1.2);
        update_geometry();
    }

    private void realize_cb(Gtk.Widget widget)
    {
        update_geometry();
    }

    private void window_title_changed_cb()
    {
        set_title(terminal.get_window_title());
    }

    private bool key_press_event_cb(Gdk.EventKey event)
    {
        if (event.state == (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) {
            switch (event.keyval) {
            case Gdk.Key.C:
                terminal.copy_clipboard();
                return true;
            case Gdk.Key.V:
                terminal.paste_clipboard();
                return true;
            }
        }
        if ((event.state & ~Gdk.ModifierType.SHIFT_MASK) == Gdk.ModifierType.CONTROL_MASK) {
            switch (event.keyval) {
            case Gdk.Key.plus:
                increase_font_size_cb();
                return true;
            case Gdk.Key.minus:
                decrease_font_size_cb();
                return true;
            }
        }
        return false;
    }
}

class Application: Gtk.Application
{
    public Application()
    {
        Object(application_id: "de.mh21.simple-term",
                flags: ApplicationFlags.HANDLES_COMMAND_LINE);
    }

    public override int command_line(GLib.ApplicationCommandLine command_line)
    {
        var argv = command_line.get_arguments();
        string[]? command = null;

        for (int i = 1; i < argv.length; ++i) {
            if (argv[i] == "-display" || argv[i] == "-name" ||
                argv[i] == "-T" || argv[i] == "-title" ||
                argv[i] == "-geometry" || argv[i] == "-fn" ||
                argv[i] == "-fg" || argv[i] == "-bg" || argv[i] == "-tn") {
                ++i;
            } else if (argv[i] == "-e") {
                command = argv[i + 1:argv.length];
                i = argv.length - 1;
            }
        }

        if (command.length == 0) {
                string shell = Vte.get_user_shell();
            if (shell == null || shell[0] == '\0')
                shell = Environment.get_variable("SHELL");
            if (shell == null || shell[0] == '\0')
                shell = "/bin/sh";
            command = { shell };
        }

        new TerminalWindow(this, command);
        return 0;
    }

    public static int main(string[] argv)
    {
        Intl.setlocale(LocaleCategory.ALL, "");

        Environment.set_application_name("Terminal");

        var app = new Application();

        return app.run(argv);
    }
}
