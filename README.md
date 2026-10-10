# Ascension

Installs DLSS5 via a Vulkan Layer onto your system. It NEVER runs in any game's folder or changes game files. 100% Anti-Cheat Safe!
Works for Nvidia Series 20, 30, 40 and 50 Cards.

Go to https://ascension-dlss5.grok.me/ for easy setup and Downloads.

## Install:
1. Download the DLSSNR.dll from the link
2. Download the Ascension Appimage
3. Double-click [Ascension-x86_64.AppImage](public/Ascension-x86_64.AppImage), tick the installed games, quit Steam once, then launch those games from Steam. Each ticked game gets a launch option only. Unticked games are left alone.

All it adds is a launch command to Steam. You can then also just freely copy that command into any other game of your liking.

This is not an anti-cheat bypass. It does not disable, hide from, or patch anti-cheat. The Vulkan layer still loads in the game process. Keeping the files out of the game directory is the whole trick, and it is not a promise that a protected game will allow it.

Once you are ingame, open a terminal on linux and type "dlssnr-gui" that opens the GUI for the Neural Rendering.
**_THIS WILL NOT CREATE A RESHADE OVERLAY!_**

## What it installs

Everything Ascension writes lives under your home directory.

| Piece | Where it comes from | Where it lands |
|---|---|---|
| DLSS5VKLayer 0.3.1-2 | Bundled. Upstream is [bmitch87/DLSS5VKLayer](https://github.com/bmitch87/DLSS5VKLayer/tree/0.3.1-2), release `dlssnr-0.3.1-2-linux-x86_64.tar.gz`, sha256 `43fd001720a3e15704c1bb8ea03c768b406e058c8eb2859ab0ebc8b3cd48f955` | `~/.local` (helper, implicit Vulkan layer, `dlssnr-helper`, `dlssnr-gui`) |
| `nvngx_dlssnr.dll` | You. Not in this repo and not downloaded. See link on https://ascension-dlss5.grok.me/ | Copied into `~/.local/share/dlssnr/binaries/`, never next to the game |
| Launch option | Written by Ascension | Steam `localconfig.vdf` only: `VKLayer_DLSS5=1 VK_ADD_LAYER_PATH=… %command%` |

The layer is the open-source Vulkan implicit layer. Your game keeps using Proton. The layer hands frames to `dlssnr-helper`, which is a small Windows program run by Proton-GE, Proton-CachyOS, Wine-GE, or system Wine. The helper is the thing that loads `nvngx_dlssnr.dll`.

The implicit layer is not pinned for every Vulkan process. Only games you tick receive the launch option, so other games stay untouched.

## The DLL

`nvngx_dlssnr.dll` is NVIDIA's neural-rendering library. Lecram's build is a modified copy of that file. NVIDIA does not offer it on the public driver-update server, due to legal reasons I won't add it to the repo.

Lecram posts his build in the [RenoDX Discord](https://discord.com/invite/renodx), in the DLSS 5 channel. If you want a newer version.

- RTX 50 can use NVIDIA's signed 310.8 build if a game you own already shipped it.
- RTX 20, 30, and 40 need Lecram's build. The signed 50-series file does not run the neural pass on those cards.

Put the file in either of these places, then run Ascension again:

```
~/.local/share/ascension/import/nvngx_dlssnr.dll
~/Downloads/nvngx_dlssnr.dll
```

## Use

Linux x86_64. Python 3 is required (the game list and the Steam config edit). Steam must be installed. Quit Steam before the launch options are written. If Steam is open, Ascension waits and can re-apply after it exits.

```
./Ascension-x86_64.AppImage            # window of installed games, then install
./Ascension-x86_64.AppImage --dry-run  # print the plan, change nothing
./Ascension-x86_64.AppImage --remove   # take the launch option off the ticked games
./Ascension-x86_64.AppImage --purge    # --remove, then uninstall the layer
```

If the file browser will not start the AppImage, mark it executable once (`chmod +x`).

There is no in-game ReShade menu. Settings are the separate `dlssnr-gui` window. Leave it open and alt-tab to it.
Make sure the game runs in Borderless Windowed mode so you can have the GUI open and the game in the background to see the changes.

A terminal build of the same installer is [src/installer/ascension.sh](src/installer/ascension.sh). The game picker is [src/installer/picker.py](src/installer/picker.py) (X11). With no display it falls back to a numbered list, or to `ASCENSION_GAMES=3393110,220` if you already know the app ids.

## What is not in the AppImage

NVIDIA NGX binaries are not included. That covers `nvngx_dlssnr.dll` and Lecram's build of it. They are not free to redistribute.

DXVK pieces inside the upstream layer tarball keep the license that tarball already ships (`dxvk-license.txt`).

## License of the layer

DLSS5VKLayer is GNU Affero General Public License v3.0. Ascension bundles that release unmodified.

- License text: [payload/DLSS5VKLayer-LICENSE.txt](payload/DLSS5VKLayer-LICENSE.txt)
- Notice and source offer: [payload/NOTICE](payload/NOTICE)
- Corresponding source: https://github.com/bmitch87/DLSS5VKLayer/tree/0.3.1-2
