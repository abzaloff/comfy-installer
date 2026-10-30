# ComfyUI UV Installer

A Windows batch installer for a fresh [ComfyUI](https://github.com/Comfy-Org/ComfyUI) installation. It uses [uv](https://docs.astral.sh/uv/) to create a Python environment and install packages, then sets up [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) to use uv for custom-node dependencies too.

## What it installs

- Python 3.13 in `ComfyUI\venv`.
- PyTorch, torchvision, and torchaudio using the PyTorch CUDA 13.0 (`cu130`) package index. Exact package versions are not pinned.
- ComfyUI and its requirements.
- ComfyUI-Manager and its requirements, plus `manager_requirements.txt` from ComfyUI.
- `matrix-nio`, `triton-windows`, and `sageattention`.

Git and uv are installed if missing. The installer tries `winget` first and offers a direct-download fallback when `winget` is unavailable. An internet connection is needed to clone repositories and download packages. The CUDA build is intended for an NVIDIA GPU with a compatible driver.

Repository clones use `git clone --depth 1` to download only the latest history, reducing the amount of data transferred during installation.

## Install

1. Put `install_comfyui_uv.bat` in the folder where you want the `ComfyUI` folder to be created.
2. Run `install_comfyui_uv.bat` and confirm the prompt.
3. Wait for the installer to finish. It stops with an error if a `ComfyUI` folder already exists in that location; it does not update an existing installation.
4. Run the generated `run_comfyui.bat` to start ComfyUI.

The launcher starts `ComfyUI\venv\Scripts\python.exe`, waits for `http://127.0.0.1:8188` to respond, and opens that address in your browser. uv manages the environment and package installation; ComfyUI itself runs with the Python executable in that environment.

## ComfyUI-Manager and uv

During installation, the script writes `use_uv = True` to `ComfyUI\user\__manager\config.ini`. This tells ComfyUI-Manager to use uv when it installs Python dependencies for custom nodes. It is a Manager setting, not a ComfyUI command-line flag. uv must remain available on `PATH` for future Manager operations.

## Generated helper files

The installer creates these helper files beside itself. It creates `custom_nodes.txt` near the beginning if the file is absent; the other helpers are written after the package installation succeeds.

| File | Purpose |
| --- | --- |
| `run_comfyui.bat` | Start ComfyUI and open its web interface. |
| `update_comfyui.bat` | Run `git pull` in the ComfyUI repository. |
| `update_requirements.bat` | Install the current ComfyUI and Manager core requirement files with uv. |
| `install_dependency.bat` | Prompt for a Python package name and install it into the ComfyUI environment with uv. |
| `install_custom_nodes.bat` | Clone or update repositories listed in `custom_nodes.txt` and install each node's `requirements.txt` with uv. |
| `venv_reinstall.bat` | Delete and recreate `ComfyUI\venv`, then restore the same Python package set as the initial installation, including CUDA 13.0 PyTorch, Manager requirements, Triton Windows, and SageAttention. The existing ComfyUI and Manager repositories remain in place. |
| `custom_nodes.txt` | List of custom-node Git URLs, one per line. Created only if it does not already exist. Blank lines and lines beginning with `#` are ignored. |

The generated helpers and the installed `ComfyUI` folder are local files and are excluded from this repository by `.gitignore`.
