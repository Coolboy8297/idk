# VEYAORA Xbox Lab

This folder is the experimental browser frontend for original Xbox and Xbox 360 work.

## What works here now

- Local selection and basic signature inspection of an ISO/XISO file. The file is not uploaded by this page.
- First-pass XDVDFS root-directory listing for supported original Xbox XISO images.
- Keyboard remapping and mouse-capture input test.
- A tiny PowerPC instruction interpreter used only as a diagnostic. It is **not** an Xbox 360 CPU emulator.
- A link from the page to [FractumSeraph/OpenCE](https://github.com/FractumSeraph/OpenCE), which publishes a WebAssembly browser port of Halo: Combat Evolved. This is a port of one game, not a general-purpose Xbox emulator.

## Original Xbox

The reference full-system emulator is [xemu](https://github.com/xemu-project/xemu), which currently targets desktop operating systems. Porting it to a browser would require adapting its CPU/JIT, graphics, audio, storage, threading, and platform dependencies for WebAssembly and browser APIs.

The OpenCE browser port is a practical browser-playable route for Halo CE specifically. It does not make this page a universal Xbox ISO emulator.

## Xbox 360

[Xenia](https://github.com/xenia-project/xenia) is the reference Xbox 360 emulator. It is a separate, substantial project and is not a browser-ready module. A browser port would require a major WebAssembly/platform port, including CPU translation, GPU translation, audio, file access, threading, and graphics API changes. Adding a script tag or ISO picker alone cannot make games run.

## GitHub Pages limitations

GitHub Pages serves static files. It does not provide a server process to run a desktop emulator, and this repository currently has no verified WebAssembly build of xemu or Xenia. Do not label the diagnostic interpreter as a playable emulator until a real core has been built, connected to browser graphics/audio/input/storage APIs, and tested with a game.

## Next engineering milestones

1. Keep disc inspection and input mapping as frontend utilities.
2. Define a stable browser-core interface for boot, pause, reset, frame output, audio, input, and save data.
3. Integrate a real browser-compatible core for one target first; test it independently before connecting it to the launcher.
4. Treat original Xbox and Xbox 360 as separate backends, with separate compatibility and system-file requirements.
5. Show a clear error when a core or required user-supplied system files are missing.

No BIOS, firmware, or commercial game data is bundled by this project.
