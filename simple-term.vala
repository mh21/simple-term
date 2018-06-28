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
// - proper dnd behavior for multiple file names

class TerminalWindow : Gtk.Window
{
    private Vte.Terminal terminal;
    private Pid pid;

    private const string link_expr = "(((file|http|ftp|https)://)|(www|ftp)[-A-Za-z0-9]*\\.)[-A-Za-z0-9\\.]+(:[0-9]*)?(/[-A-Za-z0-9_\\$\\.\\+\\!\\*\\(\\),;:@&=\\?/~\\#\\%]*[^]'\\.}>\\) ,\\\"])?";
    private int link_tag;

    public TerminalWindow(Gtk.Application app, string[] command, string? title)
    {
        Object(application: app);

        this.title = title != null ? title : string.joinv(" ", command);

        terminal = new Vte.Terminal();
        add(terminal);

        terminal.child_exited.connect(() => { destroy(); });
        terminal.decrease_font_size.connect(decrease_font_size_cb);
        terminal.increase_font_size.connect(increase_font_size_cb);
        terminal.char_size_changed.connect(char_size_changed_cb);
        terminal.window_title_changed.connect(window_title_changed_cb);
        terminal.realize.connect(realize_cb);
        terminal.key_press_event.connect(key_press_event_cb);
        terminal.button_press_event.connect(button_press_event_cb);
        terminal.drag_data_received.connect(drag_data_received_cb);

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
            var regex = new GLib.Regex(link_expr,
                    GLib.RegexCompileFlags.OPTIMIZE |
                    GLib.RegexCompileFlags.MULTILINE,
                    0);
            link_tag = terminal.match_add_gregex(regex, 0);
            terminal.match_set_cursor_type(link_tag, Gdk.CursorType.HAND1);
        } catch (Error e) {
            printerr("Failed to compile regex \"%s\": %s\n", link_expr, e.message);
            // ignored
        }

        Gtk.drag_dest_set(terminal, Gtk.DestDefaults.ALL, {}, Gdk.DragAction.COPY);
        Gtk.drag_dest_add_uri_targets(terminal); // prefer URIs to text
        Gtk.drag_dest_add_text_targets(terminal);

        try {
            terminal.spawn_sync(Vte.PtyFlags.DEFAULT,
                    null, /* working directory */
                    command,
                    null, /* environment */
                    GLib.SpawnFlags.SEARCH_PATH,
                    null, /* child setup */
                    out pid, /* child pid */
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

    private static string convert_uris(string[] uris)
    {
        for (var i = 0; i < uris.length; ++i) {
            var path = File.new_for_uri(uris[i]).get_path();
            if (path != null)
                uris[i] = Shell.quote(path);
        }
        return string.joinv(" ", uris);
    }

    private void update_geometry()
    {
        if (!terminal.get_realized())
            return;
        terminal.set_geometry_hints_for_window(this);
    }

    private void edit_contents()
    {
        try {
            FileIOStream iostream;
            var file = GLib.File.new_tmp("console-output-XXXXXX.txt", out iostream);
            OutputStream ostream = iostream.output_stream;
            terminal.write_contents_sync(ostream, Vte.WriteFlags.DEFAULT, null);
            var editor = Environment.get_variable("EDITOR");
            if (editor == null || editor[0] == '\0')
                editor = "vi";
            new TerminalWindow(this.get_application(), { editor, file.get_path() }, null);
            // after 10 seconds the editor should have opened the file, remove
            // it from the filesystem again
            Timeout.add_seconds(10, () => { file.delete_async.begin(); return false; });
        } catch (Error e) {
            printerr("Error: %s\n", e.message);
            // ignored
        }
    }

    public override bool delete_event(Gdk.EventAny event)
    {
        var pty = terminal.get_pty();
        if (pty == null)
            return false;
        var fd = pty.get_fd();
        if (fd == -1)
            return false;
        var fgpid = Posix.tcgetpgrp(fd);
        if (fgpid == -1 || fgpid == pid)
            return false;

        Gtk.MessageDialog dialog = new Gtk.MessageDialog(this,
            0, Gtk.MessageType.WARNING,
            Gtk.ButtonsType.CANCEL, "Running processes, close nevertheless?");
        dialog.add_button("_Close", Gtk.ResponseType.ACCEPT);
        dialog.set_default_response(Gtk.ResponseType.ACCEPT);

        var result = dialog.run();
        dialog.destroy();
        return result != Gtk.ResponseType.ACCEPT;
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

    private bool button_press_event_cb(Gdk.EventButton event)
    {
        if (event.state == Gdk.ModifierType.CONTROL_MASK && event.button == 1) {
            int tag;
            var match = terminal.match_check_event(event, out tag);
            if (match != null && tag == link_tag) {
                try {
                    Gtk.show_uri(get_screen(), match, Gtk.get_current_event_time());
                } catch (Error e) {
                    printerr("Error: %s\n", e.message);
                    // ignored
                }
            }
            return false;
        }
        return false;
    }

    private bool key_press_event_cb(Gdk.EventKey event)
    {
        if ((event.state & Gdk.ModifierType.MODIFIER_MASK) ==
            (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) {
            switch (event.keyval) {
            case Gdk.Key.C:
                terminal.copy_clipboard();
                return true;
            case Gdk.Key.V:
                terminal.paste_clipboard();
                return true;
            case Gdk.Key.S:
                edit_contents();
                return true;
            }
        }
        if ((event.state & Gdk.ModifierType.MODIFIER_MASK & ~Gdk.ModifierType.SHIFT_MASK) ==
            Gdk.ModifierType.CONTROL_MASK) {
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

    private void drag_data_received_cb(Gtk.Widget widget, Gdk.DragContext context,
            int x, int y, Gtk.SelectionData selection_data, uint target_type, uint time)
    {
        // this is the only way to get a usable target list
        Gdk.Atom[] targets = { selection_data.get_target() };
        if (Gtk.targets_include_text(targets)) {
            terminal.feed_child(selection_data.get_text().to_utf8());
        } else if (Gtk.targets_include_uri(targets)) {
            terminal.feed_child(convert_uris(selection_data.get_uris()).to_utf8());
        }
        Gtk.drag_finish(context, true, false, time);
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
        string title = null;

        for (int i = 1; i < argv.length; ++i) {
            if (argv[i] == "-display" || argv[i] == "-name" ||
                argv[i] == "-geometry" || argv[i] == "-fn" ||
                argv[i] == "-fg" || argv[i] == "-bg" || argv[i] == "-tn") {
                ++i;
            } else if (argv[i] == "-T" || argv[i] == "-title") {
                title = argv[i + 1];
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

        new TerminalWindow(this, command, title);
        return 0;
    }

    public static int main(string[] argv)
    {
        Environment.set_prgname("simple-term");
        Environment.set_application_name("Terminal");
        return new Application().run(argv);
    }
}
