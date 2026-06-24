# Avalonia XAML Playground Snap

A learning project for packaging a sample [.NET](https://dotnet.microsoft.com/) /
[Avalonia](https://avaloniaui.net/) application as a [snap](https://snapcraft.io/).

This repository wraps the upstream
[AvaloniaUI/XamlPlayground](https://github.com/AvaloniaUI/XamlPlayground) project
in a `snapcraft.yaml` so it can be built, installed, and run as a confined snap on
any Linux distribution that supports `snapd`.

> **Disclaimer**
> This snap is **not** endorsed by the Avalonia project or its maintainers.
> It is a personal project created to learn how to build snaps and to experiment
> with packaging .NET / Avalonia applications.

## About the upstream project

[XamlPlayground](https://github.com/AvaloniaUI/XamlPlayground) is an interactive
playground for [Avalonia](https://avaloniaui.net/) XAML. It lets you write XAML
(and optional C# code-behind) and see the rendered result live. The upstream
project is written in C# and is licensed under the
[MIT license](https://github.com/AvaloniaUI/XamlPlayground/blob/main/LICENSE.md).

## Goals

This repo is primarily a **teaching/learning sandbox**. The objectives are to:

- Learn the structure of a `snapcraft.yaml` file (`parts`, `apps`, `plugs`).
- Build a .NET / Avalonia application inside a snap with `dotnet publish`.
- Understand `build-packages` vs `stage-packages`.
- Discover missing runtime libraries methodically (`apt-file`, `ldd`).
- Move from `devmode` to `strict` confinement.
- Add desktop integration (`.desktop` entry + icon).
- Practice the full build → install → run → iterate workflow with `snapcraft`.

## Prerequisites

Before you start, make sure you have the following installed:

- A Linux system (or VM) with [`snapd`](https://snapcraft.io/docs/installing-snapd).
- [Snapcraft](https://snapcraft.io/docs/snapcraft-overview):

  ```sh
  sudo snap install snapcraft --classic
  ```

- A build backend for `snapcraft`. In this case:
  - [LXD](https://snapcraft.io/docs/build-options):

    ```sh
    sudo snap install lxd
    sudo lxd init --auto
    sudo usermod -aG lxd "$USER"   # then re-login
    ```

## Repository structure

```text
.
├── README.md                                       # This file
├── .gitignore
└── snap/
    ├── snapcraft.yaml                              # The snap recipe
    └── gui/
        ├── icon.png                               # App icon (256x256)
        └── rinconjr-avalonia-xaml-playground.desktop  # Desktop menu entry
```

> Anything placed under `snap/gui/` is automatically copied to `meta/gui/`
> inside the snap and picked up by `snapd` for desktop integration, no extra
> configuration in `snapcraft.yaml` is required.

## Building the snap

From the root of this repository, run:

```sh
snapcraft
```

This produces a `.snap` file in the current directory, for example:

```text
rinconjr-avalonia-xaml-playground_0.1_amd64.snap
```

> **Tip**
> Use `snapcraft --verbose` for detailed build output, and
> `snapcraft clean` to start from a clean build environment if something goes wrong.

## Installing the snap

The snap now uses `confinement: strict`, so install it with just the
`--dangerous` flag (required for locally built, unsigned snaps):

```sh
sudo snap install ./rinconjr-avalonia-xaml-playground_0.1_amd64.snap --dangerous
```

> While developing, you may have used `--devmode` to disable confinement.
> Once you move to `strict`, drop `--devmode` so the real interface rules apply.

After installing, you can review which interfaces are connected:

```sh
snap connections rinconjr-avalonia-xaml-playground
```

## Running the snap

Launch it by its command name:

```sh
rinconjr-avalonia-xaml-playground
```

Or find **Avalonia XAML Playground** in your desktop application menu (the
`.desktop` entry and icon are installed automatically).

> **App Center note:** a locally installed, unsigned snap may show a generic
> placeholder icon in App Center because it has no Store metadata. The real
> icon still appears in the application menu and on the running window.

## How the build works

Because `core26` does not ship the .NET SDK (and the Canonical `dotnet-sdk` snap
only goes up to .NET 8 and is a `classic` snap), the recipe downloads the
official **.NET 10 SDK** from Microsoft during the build and runs
`dotnet publish` as a **self-contained** app, so the .NET runtime is bundled
inside the snap and the user does not need .NET installed.

The publish step maps the snap's target architecture to a .NET Runtime
Identifier (RID), so the same recipe works for both `amd64` and `arm64`:

| `platforms` arch | `$CRAFT_ARCH_BUILD_FOR` | .NET RID     |
| ---------------- | ----------------------- | ------------ |
| `amd64`          | `amd64`                 | `linux-x64`  |
| `arm64`          | `arm64`                 | `linux-arm64`|

## Confinement and status

- `grade: devel` - not yet marked for release to `candidate`/`stable`.
- `confinement: strict` - enforced confinement. The app can only access what its
  declared [interfaces](https://snapcraft.io/docs/supported-interfaces) allow:
  - `desktop`, `desktop-legacy`
  - `wayland`, `x11`
  - `opengl`
  - `network`, `network-bind`
  - `home`

> **Why declare these plugs manually instead of using the `gnome` extension?**
> The `gnome` extension would normally wire up the desktop interfaces (including
> `desktop` and `desktop-legacy`), fonts and themes automatically. However, per
> the official docs the extension is *"compatible with the **core22 and core24**
> bases"* only, it does **not** support `core26`. Trying to use it on `core26`
> fails with:
>
> ```text
> Extension 'gnome' does not support base: 'core26'
> ```
>
> So on `core26` the `desktop`, `desktop-legacy`, `wayland`, `x11` and `opengl`
> plugs are declared by hand instead.
> Source: [GNOME extension - Snapcraft docs](https://documentation.ubuntu.com/snapcraft/stable/reference/extensions/gnome-extension/).

## Finding the runtime library dependencies

A `.NET` desktop app pulls in native libraries (SkiaSharp, X11, etc.). Inside a
confined snap those libraries must be bundled via `stage-packages`, the host's
copies are **not** visible at runtime. The reliable method to discover them is:

1. **Run the app** and read the first `cannot open libXXX.so` error.
2. **Find the providing package**:

   ```sh
   apt-file search libXXX.so
   ```

3. **Add that package** to `stage-packages`, rebuild, run again, and repeat.

> **IMPORTANT:** running `ldd` on the host can *lie*, since it resolves libraries using the
> host's paths, so it may report "all found" even when a library is missing
> *inside* the snap. To check the truth, run `ldd` from within the snap's
> environment (`snap run --shell <name>`), or simply trust the app's own runtime
> error message.

To inspect dependencies *from inside the snap* (the reliable way), scan **all**
binaries and libraries at once instead of checking one file by name:

```sh
# Open a shell inside the confined snap environment
snap run --shell rinconjr-avalonia-xaml-playground

# $SNAP points to the snap's root. For this snap, `dotnet publish` puts the
# executable and all native .so files under $SNAP/bin, so scan that whole folder
# and list every missing library across all of them, de-duplicated:
find "$SNAP/bin" -type f \( -name "*.so*" -o -perm -u+x \) -exec ldd {} \; 2>/dev/null \
  | grep "not found" | sort -u
# e.g. ->  libfontconfig.so.1 => not found
#          libX11.so.6 => not found

exit
```

Each line reported as `not found` is a library you still need to add to
`stage-packages`. Map any of them back to a package with:

```sh
apt-file search <lib>
```

> **Where do the files live?** It depends on the build. This snap installs into
> `$SNAP/bin` because the recipe runs `dotnet publish --output "$CRAFT_PART_INSTALL/bin"`
> (`$CRAFT_PART_INSTALL` becomes the snap root). Other plugins/recipes may place
> binaries under `$SNAP/usr/bin`, `$SNAP/usr/lib`, etc. If unsure, scan the whole
> snap: replace `"$SNAP/bin"` with `"$SNAP"` in the command above.

Following this loop, the libraries discovered for this app were:

| Missing `.so`        | Package          | Used by              |
| -------------------- | ---------------- | -------------------- |
| `libicu*.so`         | `libicu78`       | .NET globalization   |
| `libfontconfig.so.1` | `libfontconfig1` | SkiaSharp (renderer) |
| `libX11.so.6`        | `libx11-6`       | Avalonia X11 backend |
| `libICE.so.6`        | `libice6`        | Avalonia X11 ICELib  |
| `libSM.so.6`         | `libsm6`         | Avalonia X11 SMlib   |

> Note: `libicu78` is also added to `build-packages`, because the `dotnet` CLI
> itself needs ICU to run during the build.

## Useful commands

| Command | Description |
| --- | --- |
| `snapcraft` / `snapcraft pack` | Build the snap |
| `snapcraft --verbose` | Build with detailed logs |
| `snapcraft clean` | Clean the build environment |
| `snap install ./*.snap --dangerous` | Install the locally built (strict) snap |
| `snap connections rinconjr-avalonia-xaml-playground` | List interface connections |
| `snap run rinconjr-avalonia-xaml-playground` | Run the snap |
| `snap run --shell rinconjr-avalonia-xaml-playground` | Open a shell inside the snap (debugging) |
| `snap remove rinconjr-avalonia-xaml-playground` | Uninstall the snap |
| `snap logs rinconjr-avalonia-xaml-playground` | View the snap's logs |
| `apt-file search libXXX.so` | Find the package providing a missing library |

## Troubleshooting build environment (LXD)

If a build is interrupted, the LXD instance can get stuck in a `create`
operation and block `snapcraft clean`. To recover:

```sh
# Clear the stuck operation
sudo systemctl restart snap.lxd.daemon

# If orphaned rsync processes remain, kill them, then delete the instance
lxc --project snapcraft delete -f <instance-name>
```

## Resources

- [Snapcraft documentation](https://snapcraft.io/docs)
- [Crafting a .NET snap](https://snapcraft.io/docs/dotnet-apps)
- [Avalonia UI](https://avaloniaui.net/)
- [AvaloniaUI/XamlPlayground](https://github.com/AvaloniaUI/XamlPlayground)

## License

This packaging repository is provided for learning purposes. The upstream
XamlPlayground application is licensed under the
[MIT license](https://github.com/AvaloniaUI/XamlPlayground/blob/main/LICENSE.md).
