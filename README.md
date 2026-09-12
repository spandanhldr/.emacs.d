# Portable Emacs configuration

Use Emacs 29.1 or newer and Git. Put this repository in your Emacs user directory
(`~/.emacs.d` on Unix; `~/.config/emacs` also works when selected by Emacs).
On Windows, use the directory reported by `user-emacs-directory`.
The first startup needs network access to install packages through Straight.
Do not copy Straight build artifacts or session files between operating systems.

The shared Ctrl shortcuts, editing commands, session restoration, 12-hour clock,
and rotating Pokemon, Beyblade and Bakugan welcome scenes use the same Lisp on
Windows, macOS, Linux and BSD. On macOS Control stays Control and Option is Meta.
Font selection uses the first installed family: Cascadia Code, DejaVu Sans Mono,
Menlo, Liberation Mono, then Monospace. Install the same font on each machine for
closer visual consistency. macOS imports the login-shell executable search path.

## Display requirements and limits

For the full interface use a graphical Emacs build with SVG support and child
frames. Native Windows dialogs use the included PowerShell helper; macOS and
Unix use Emacs' native file chooser. Linux/BSD should use a GTK build for modern
file dialogs. Dialog styling belongs to the OS/toolkit and cannot be identical
across operating systems. See the [Emacs manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Visiting.html).

Terminal or non-SVG builds retain a text welcome screen, clock and actions.
The command palette falls back to Vertico in the minibuffer where child frames
are unavailable. Terminals and desktop window managers may intercept shortcuts
or merge Ctrl+Shift keys; F1 also opens the palette. SVG animation uses native
Emacs SVG support, not GPU rendering or raster artwork.

Install `pylsp` or `pyright-langserver` for Python and `clangd` or `ccls` for C/C++
on PATH to enable automatic language-server features. Editing works without them.
Native compilation uses up to four background processes based on available CPUs.

## Validation

Run from this directory:

```sh
emacs --batch -Q -l vscode-keys-tests.el
emacs --batch -Q -l editor-session-tests.el
emacs --batch -Q -l welcome-tests.el
emacs --batch -Q -l portability-tests.el
emacs --batch -Q -l command-palette-tests.el
```

The palette tests require packages installed by the first startup. SVG rendering
tests require an SVG-capable build. Platform-routing tests simulate OS selection;
they do not certify native GUI behavior on a different operating system.
Validation for this revision was performed on Windows with Emacs 31.1;
macOS, Linux and BSD native GUI testing remains outstanding.

Session contents, history, generated caches and installed packages are ignored
by Git; only configuration, its dialog helper, documentation and tests are shared.
