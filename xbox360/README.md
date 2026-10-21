# VEYAORA 360 — CPU Lab (Phase 01)

This folder is separate from the existing VEYAORA Arcade launcher.

## What this prototype does

- Implements a tiny, incomplete PowerPC-style instruction interpreter in C++.
- Compiles the C++ core to WebAssembly with Emscripten.
- Includes a browser UI to load and step through a built-in test program.
- Uses 64 KiB of emulated memory and 32 general-purpose 32-bit registers.
- Runs locally in the browser after the page and WebAssembly files load. It does not stream gameplay.

The built-in program puts 5 in R3, puts 7 in R4, adds them into R5, and stores 12 at memory address 0x100. The final stop marker is a prototype convention, not an actual PowerPC instruction.

## Important limitation

This is an educational CPU-core proof of concept, not an Xbox 360 emulator. The Xbox 360 Xenon CPU has PowerPC-derived cores plus specialized vector instructions, and a functional console emulator also needs extensive system APIs, memory/peripheral behavior, GPU command translation, audio, storage, and other components. This subset will not boot the Xbox 360 dashboard or run commercial games.

## Build

The workflow at .github/workflows/build-xbox360-wasm.yml compiles cpu.cpp using Emscripten and commits generated cpu.js and cpu.wasm into this folder. Once the workflow succeeds and GitHub Pages publishes the updated repository, open:

https://coolboy8297.github.io/idk/xbox360/

If testing locally, serve the repository over HTTP rather than opening the HTML with file:// so the browser can fetch the WebAssembly binary.

## Implemented instruction subset

- addi, addis
- ori, oris, andi.
- lwz, stw
- b and limited bc condition handling
- add and subf XO-form operations

Anything outside this subset stops with an unsupported-instruction status. This list is intentionally small for the first test.
