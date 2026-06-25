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
playground for [Avalonia](https://avaloniaui.net/) XAML. It lets you write XAML and see the rendered result live. The upstream
project is written in C# and is licensed under the
[MIT license](https://github.com/AvaloniaUI/XamlPlayground/blob/main/LICENSE.md).

## Goals

This repo is primarily a **teaching/learning sandbox**. The objectives are to:

- Learn the structure of a `snapcraft.yaml` file (`parts`, `apps`, `plugs`).
- Build a .NET / Avalonia application inside a snap with the `dotnet` plugin.
- Understand the difference between plugins, extensions, and `stage-packages`.
- Use the `gnome` extension on `core24` to wire up desktop interfaces.
- Discover missing runtime libraries methodically (`apt-file`, `ldd`).
- Move from `devmode` to `strict` confinement.
- Add desktop integration (`.desktop` entry + icon).
- Handle benign library-linter warnings with `lint: ignore`.
- Practice the full build -> install -> run -> iterate workflow with `snapcraft`.

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
snapcraft pack
```

This produces a `.snap` file in the current directory, for example:

```text
rinconjr-avalonia-xaml-playground_0.1_amd64.snap
```

> **Tip**
> Use `snapcraft pack --verbose` for detailed build output, and
> `snapcraft clean` to start from a clean build environment if something goes wrong.

## Installing the snap

The snap now uses `confinement: strict`, so install it with just the
`--dangerous` flag (required for locally built, unsigned snaps):

```sh
sudo snap install ./rinconjr-avalonia-xaml-playground_0.1_amd64.snap --dangerous
```

> During early development you can temporarily use `--devmode` to disable
> confinement while debugging. With `confinement: strict`, install without it so
> the real interface rules apply.

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

The recipe is built on `base: core24` and uses two main helpers:

1. The **.NET plugin (v2)** (`plugin: dotnet`), which runs
   `dotnet restore` -> `dotnet build` -> `dotnet publish` automatically. Setting
   `dotnet-version: "10.0"` makes the plugin fetch the official Canonical **.NET 10
   SDK content snap** (`dotnet-sdk-100`) during the build, so there is no need to
   download the SDK manually.

2. The **`gnome` extension** (`extensions: [gnome]`) in the app entry. It wires up
   the desktop interfaces (`desktop`, `desktop-legacy`, `wayland`, `x11`,
   `opengl`), pulls in the GNOME platform content snap for fonts and themes, and
   adds the standard desktop launch wrapper.

The relevant part keys are:

| Key | Value | Purpose |
| --- | --- | --- |
| `plugin` | `dotnet` | Use the .NET plugin (v2) |
| `dotnet-version` | `"10.0"` | Provision the .NET 10 SDK content snap |
| `dotnet-project` | `src/.../XamlPlayground.NetCore.csproj` | Which project to build |
| `dotnet-self-contained` | `true` | Bundle the runtime; auto-selects the RID |

With `dotnet-self-contained: true`, the plugin picks the .NET Runtime Identifier
(RID) automatically from `$CRAFT_BUILD_FOR`, so the same recipe works for both
`amd64` and `arm64`:

| `$CRAFT_BUILD_FOR` | .NET RID      |
| ------------------ | ------------- |
| `amd64`            | `linux-x64`   |
| `arm64`            | `linux-arm64` |

> Docs: [.NET plugin (v2)](https://documentation.ubuntu.com/snapcraft/9.0/common/craft-parts/reference/plugins/dotnet_v2_plugin/).

> **Earlier approach:** the first iteration of this recipe used `base: core26` and
> declared the desktop plugs (`desktop`, `wayland`, `x11`, `opengl`, etc.) by hand
> because the `gnome` extension did not support `core26`. The current recipe uses
> `core24` so the `gnome` extension can handle the desktop plumbing automatically.
>
> **Earlier approach (manual build):** before switching to the `dotnet` plugin, this
> recipe used `plugin: nil` with an `override-build` that ran `dotnet-install.sh`
> and `dotnet publish` by hand, mapping the architecture to a RID with a `case`
> statement. The plugin replaces all of that boilerplate.

## Confinement and status

- `base: core24` - built on the Ubuntu 24.04 base snap.
- `grade: devel` - not yet marked for release to `candidate`/`stable`.
- `confinement: strict` - enforced confinement. The app can only access what its
  declared [interfaces](https://snapcraft.io/docs/supported-interfaces) allow.
  The app entry uses the `gnome` extension, which injects:
  - `desktop`, `desktop-legacy`
  - `wayland`, `x11`
  - `opengl`
  - `gsettings`
  - GNOME platform content snap (fonts, themes)
  - standard desktop launch wrapper

  Only the non-desktop plugs are declared explicitly:
  - `network`, `network-bind`
  - `home`

> **Why the `gnome` extension?** It bundles the GNOME platform (fonts, themes,
> and common libraries) and wires up the desktop interfaces automatically. This
> avoids having to declare `desktop`, `wayland`, `x11`, `opengl`, and related
> `stage-packages` by hand. The extension is available for `core22` and `core24`;
> this recipe uses `core24` to take advantage of it.
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

# $SNAP points to the snap's root. The dotnet plugin publishes the executable
# and all native .so files into the snap root, so scan the whole snap and list
# every missing library across all binaries, de-duplicated:
find "$SNAP" -type f \( -name "*.so*" -o -perm -u+x \) -exec ldd {} \; 2>/dev/null \
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

> **Where do the files live?** It depends on the build. With the `dotnet` plugin
> (used here), `dotnet publish` places the executable and the native `.so` files
> directly in the **snap root** (`$SNAP/`). Other plugins/recipes may place
> binaries under `$SNAP/usr/bin`, `$SNAP/usr/lib`, etc. The command above scans
> the whole snap (`"$SNAP"`), so it works regardless of layout.

Following this loop, the libraries that still had to be staged for this app on
`core24` were:

| Missing `.so`        | Package          | Used by              |
| -------------------- | ---------------- | -------------------- |
| `libicu*.so`         | `libicu74`       | .NET globalization   |
| `libz.so.1`          | `zlib1g`         | SkiaSharp (compression) |
| `libfontconfig.so.1` | `libfontconfig1` | SkiaSharp (renderer) |

The X11 stack (`libX11.so.6`, `libICE.so.6`, `libSM.so.6`, etc.) is provided by
the GNOME platform content snap that the `gnome` extension pulls in, so those
packages no longer need to be listed in `stage-packages`.

> Note: these go in `stage-packages` only. The build-time .NET SDK (including its
> own ICU dependency) is provided by the `dotnet` plugin via the
> `dotnet-sdk-100` content snap, so there is no `build-packages` section.

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
| `snapcraft register --private rinconjr-avalonia-xaml-playground` | Register the snap name privately |
| `snapcraft upload --release=edge rinconjr-avalonia-xaml-playground_0.1_amd64.snap` | Upload to the edge channel |
| `sudo snap install rinconjr-avalonia-xaml-playground --edge` | Install from the Snap Store |

## Troubleshooting build environment (LXD)

If a build is interrupted, the LXD instance can get stuck in a `create`
operation and block `snapcraft clean`. To recover:

```sh
# Clear the stuck operation
sudo systemctl restart snap.lxd.daemon

# If orphaned rsync processes remain, kill them, then delete the instance
lxc --project snapcraft delete -f <instance-name>
```

## Publishing to the Snap Store (private)

To publish this snap privately for testing:

1. Register the name:

   ```sh
   snapcraft register --private rinconjr-avalonia-xaml-playground
   ```

2. Upload a revision to the `edge` channel:

   ```sh
   snapcraft upload --release=edge rinconjr-avalonia-xaml-playground_0.1_amd64.snap
   ```

3. Install it from the store (private snaps require the installing user to be
   logged in with an authorized Ubuntu One account):

   ```sh
   snap login your-email@example.com
   sudo snap install rinconjr-avalonia-xaml-playground --edge
   ```

Private snaps are only visible to you and collaborators you invite in the store
settings.

## Resources

- [Snapcraft documentation](https://snapcraft.io/docs)
- [.NET plugin (v2)](https://documentation.ubuntu.com/snapcraft/9.0/common/craft-parts/reference/plugins/dotnet_v2_plugin/)
- [GNOME extension (supported bases)](https://documentation.ubuntu.com/snapcraft/stable/reference/extensions/gnome-extension/)
- [Crafting a .NET snap](https://snapcraft.io/docs/dotnet-apps)
- [Avalonia UI](https://avaloniaui.net/)
- [AvaloniaUI/XamlPlayground](https://github.com/AvaloniaUI/XamlPlayground)

## License

This packaging repository is provided for learning purposes. The upstream
XamlPlayground application is licensed under the
[MIT license](https://github.com/AvaloniaUI/XamlPlayground/blob/main/LICENSE.md).
