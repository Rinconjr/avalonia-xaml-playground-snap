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

- Learn the structure of a `snapcraft.yaml` file.
- Understand how to build a .NET / Avalonia application inside a snap.
- Explore confinement, plugs, and slots needed for a desktop GUI application.
- Practice the full build → install → run → iterate workflow with `snapcraft`.

## Prerequisites

Before you start, make sure you have the following installed:

- A Linux system (or VM) with [`snapd`](https://snapcraft.io/docs/installing-snapd).
- [Snapcraft](https://snapcraft.io/docs/snapcraft-overview):

  ```sh
  sudo snap install snapcraft --classic
  ```

- A build backend for `snapcraft`. Either:
  - [LXD](https://snapcraft.io/docs/build-options) (recommended):

    ```sh
    sudo snap install lxd
    sudo lxd init --auto
    sudo usermod -aG lxd "$USER"   # then re-login
    ```

  - or [Multipass](https://multipass.run/).

## Repository structure

```text
.
├── README.md            # This file
└── snap/
    └── snapcraft.yaml   # The snap recipe
```

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

Because the snap is currently built in `devmode` (see
[Confinement](#confinement-and-status) below), install it with the
`--devmode` and `--dangerous` flags (the latter is required for locally built,
unsigned snaps):

```sh
sudo snap install ./rinconjr-avalonia-xaml-playground_0.1_amd64.snap \
  --devmode --dangerous
```

## Running the snap

Once installed, launch it by its command name:

```sh
rinconjr-avalonia-xaml-playground
```

## Confinement and status

The current `snapcraft.yaml` is configured for development:

- `grade: devel` — not yet ready for release to the `candidate`/`stable` channels.
- `confinement: devmode` — runs without enforced confinement, which is convenient
  while learning and debugging.

Once the application builds and runs correctly, the next learning step is to move
to `confinement: strict` and add the appropriate
[interfaces](https://snapcraft.io/docs/supported-interfaces) (plugs/slots) that a
desktop GUI app needs, such as:

- `desktop`, `desktop-legacy`
- `wayland`, `x11`
- `opengl`
- `network` (if fetching gists/remote content)

## Useful commands

| Command | Description |
| --- | --- |
| `snapcraft` | Build the snap |
| `snapcraft --verbose` | Build with detailed logs |
| `snapcraft clean` | Clean the build environment |
| `snap install ./*.snap --devmode --dangerous` | Install the locally built snap |
| `snap run rinconjr-avalonia-xaml-playground` | Run the snap |
| `snap remove rinconjr-avalonia-xaml-playground` | Uninstall the snap |
| `snap logs rinconjr-avalonia-xaml-playground` | View the snap's logs |

## Resources

- [Snapcraft documentation](https://snapcraft.io/docs)
- [Crafting a .NET snap](https://snapcraft.io/docs/dotnet-apps)
- [Avalonia UI](https://avaloniaui.net/)
- [AvaloniaUI/XamlPlayground](https://github.com/AvaloniaUI/XamlPlayground)

## License

This packaging repository is provided for learning purposes. The upstream
XamlPlayground application is licensed under the
[MIT license](https://github.com/AvaloniaUI/XamlPlayground/blob/main/LICENSE.md).
