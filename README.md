# simple-term

Simple vte-based terminal

## Shortcuts

- Ctrl-Shift-C: Copy
- Ctrl-Shift-V: Paste
- Ctrl-Shift-S: Copy console output to a temporary file, open in $EDITOR
- Ctrl-+: Increase font size
- Ctrl--: Decrease font size

## Other features

- drop text
- drop filenames from a file manager and get them formatted as command line
  arguments
- warn when closing terminal windows with running subprocesses
- ctrl-click on links to open them in a webbrowser
- xterm-compatible command line interface

## Packages for Fedora Linux

Packages for all current versions of Fedora Linux can be found in
[Copr][copr-simple-term]:

```shell
sudo dnf copr enable mh21/simple-term
sudo dnf install simple-term
```

[copr-simple-term]: https://copr.fedorainfracloud.org/coprs/mh21/simple-term/
