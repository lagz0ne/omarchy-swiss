# omarchy-swiss

A Swiss-style look for [Omarchy](https://omarchy.org), from the bootloader to the desktop. Built for an ASUS Zenbook Duo (2880×1800 OLED), but nothing is tied to it.

Every screen shares one grid: a bottom-left type block (small tracked label, big Nimbus Sans Bold heading, one line of copy) on a 120px margin, with squircle keys and a hairline progress line. Everything is greyscale except one warm accent, `#de6145`.

| Screen | What you see |
|---|---|
| Limine boot menu | ZENBOOK DUO / Boot, Terminus menu font |
| Plymouth | ENCRYPTED DISK / Unlock, one squircle per typed key; Restoring session… on resume; SYSTEM / Power off or Restart at shutdown |
| SDDM | SESSION · USER / Sign in |
| Lock | date and time / Locked, face unlock or password |
| Polkit | ROOT ACCESS / Authorize, with the command being run |
| Screensaver | oversize squircle art on pure black (clock, field, tide, orbit), shuffled each time |

Three desktop themes:

- **Swiss**: dark, solid fills
- **Swiss Outline**: the same, with every fill drawn as a 1px outline
- **Swiss Light**: ink on warm paper

Each ships oversize squircle wallpapers, including a keyboard with S‑W‑I‑S‑S typed across it.

## Just a theme

Each theme also lives in its own repo, the usual Omarchy way:

```sh
omarchy-theme-install https://github.com/lagz0ne/omarchy-swiss-theme
omarchy-theme-install https://github.com/lagz0ne/omarchy-swiss-outline-theme
omarchy-theme-install https://github.com/lagz0ne/omarchy-swiss-light-theme
```

Those get you the colors, borders and wallpapers. The boot screens, lock screen, polkit prompt, screensaver and outline workspace tiles come from this bundle.

## Install everything

```sh
git clone https://github.com/lagz0ne/omarchy-swiss ~/Work/omarchy-swiss
cd ~/Work/omarchy-swiss
./install.sh --apply "Swiss"
```

- `./install.sh --user`: themes, wallpapers, shell plugins and menu entry, no root needed
- `./install.sh --boot`: Plymouth, SDDM and Limine (including building the menu font); asks for root once through pkexec and rebuilds the boot image
- Re-running is safe. The installer overwrites its own files and keeps your own backgrounds and settings. Whatever it replaces goes to `~/.cache/omarchy-swiss/backup-*`. The first Limine config backup is kept at `/boot/limine.conf.pre-swiss`.

Switch themes with `omarchy-theme-set "Swiss"`, `"Swiss Outline"` or `"Swiss Light"`.

### What the user part changes

- copies `themes/*` to `~/.config/omarchy/themes/`
- copies `plugins/lagz0ne.*` to `~/.config/omarchy/plugins/`, then in `shell.json`:
  - enables lock, idle (screensaver), polkit and bar-tokens, and disables `omarchy.lock`, `omarchy.idle` and `omarchy.polkit`
  - swaps the bar's `omarchy.workspaces` and `omarchy.indicators` for the Swiss ones
- adds a "Screensaver" override to `~/.config/omarchy/extensions/omarchy-menu.jsonc`

The plugins are clones of Omarchy's own. After an Omarchy update, check whether upstream changed `lock`, `idle` or `polkit`: a clone doesn't pick up upstream fixes.

## Layout

```
install.sh, install-boot.sh   installers (user / root)
themes/                       swiss, swiss-outline, swiss-light (Omarchy theme dirs)
plugins/                      lagz0ne.lock, idle, polkit, workspaces, indicators, bar-tokens
plymouth/, gen-plymouth.sh    Plymouth theme and its image generator
sddm/                         SDDM theme (shares KeyRow/Squircle/Hairline with the lock)
limine/                       header, wallpaper and font generators (gen-limine.sh, gen-font.py)
wallpaper/                    gen-wallpapers.py (field/tide/ripple/corner), gen-keyboard.py
tools/                        make-outline.py, make-light.py: derive the variants from themes/swiss
menu/                         Omarchy menu override
```

## Changing things

- **Theme colors or tokens:** edit `themes/swiss`, run `tools/make-outline.py` and `tools/make-light.py`, then `./install.sh --user`.
- **Wallpapers:** `wallpaper/gen-wallpapers.py <out-dir> <filled|outline> <colors.toml>`. The keyboard can type any word: `wallpaper/gen-keyboard.py out.png filled themes/swiss/colors.toml OMARCHY`.
- **Plymouth:** edit `gen-plymouth.sh` or `plymouth/swiss.script`, run `./gen-plymouth.sh plymouth`, then `./install.sh --boot`.
- **Limine:** edit `limine/limine-header.conf` or `limine/gen-limine.sh`, run `./limine/gen-limine.sh limine/swiss-boot.png`, then `./install.sh --boot`. Limine always centres its menu.
- **Screensaver scenes:** preview one with `omarchy-shell idle screensaverScene 0..3`, or run the normal shuffled version with `omarchy-shell idle screensaver`.

## Publishing the theme repos

`tools/publish-themes.sh` copies each `themes/<name>` into `omarchy-<name>-theme`, with the theme files at the repo root, and pushes it. Add `--create` the first time to create the GitHub repos.

## Requirements

Omarchy 4 with the Quickshell shell (`omarchy-shell`), Limine with `limine-mkinitcpio`, Plymouth, SDDM, ImageMagick, Python 3, `jq`, and `gsfonts` (Nimbus Sans). The bootloader menu font is built from kbd's `Lat2-Terminus16`.

## License

MIT, see [LICENSE](LICENSE). The plugins are modified clones of Omarchy's own and the theme started from Omarchy's Solitude theme; Omarchy is MIT, © David Heinemeier Hansson. The Limine menu font isn't shipped: `limine/gen-font.py` builds it during install from your system's Terminus console font, which keeps its own license.
