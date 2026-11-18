# Third-party 3D assets

The files listed below are licensed under [Creative Commons CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). CC0 allows copying, modification, commercial use, and redistribution without attribution, although credit is appreciated. The named creators and links are retained here for provenance. CC0 does not waive trademark or other non-copyright rights. [Poly Haven's asset license](https://polyhaven.com/license) expressly permits redistribution and use in commercial products. The [Quaternius Zombie Apocalypse Kit page](https://quaternius.com/packs/zombieapocalypsekit.html) identifies the kit as CC0 and permits personal and commercial use.

All paths below are relative to `public/assets/models/`. Sizes are the combined on-disk model and required dependencies, in decimal MB. Poly Haven's files were downloaded unchanged in the 1K glTF variant; each accompanying `.bin` and `textures/` directory is necessary. The triangle counts below were counted from the downloaded glTF geometry. No project code was changed.

## Modular Airduct Rectangular 01

- **Creator:** James Ray Cock; **source:** [Poly Haven model page](https://polyhaven.com/a/modular_airduct_rectangular_01), [1K glTF direct download](https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/modular_airduct_rectangular_01/modular_airduct_rectangular_01_1k.gltf), [official dependency manifest](https://api.polyhaven.com/files/modular_airduct_rectangular_01).
- **Load:** `/assets/models/modular_airduct_rectangular_01/modular_airduct_rectangular_01_1k.gltf`.
- **Files:** `modular_airduct_rectangular_01/modular_airduct_rectangular_01_1k.gltf`, `modular_airduct_rectangular_01/modular_airduct_rectangular_01.bin`, and `modular_airduct_rectangular_01/textures/` containing `modular_airduct_rectangular_01_parts01_diff_1k.jpg`, `modular_airduct_rectangular_01_parts01_nor_gl_1k.jpg`, `modular_airduct_rectangular_01_parts01_arm_1k.jpg`, `modular_airduct_rectangular_01_parts02_diff_1k.jpg`, `modular_airduct_rectangular_01_parts02_nor_gl_1k.jpg`, and `modular_airduct_rectangular_01_parts02_arm_1k.jpg`.
- **Details:** 2,766,753 bytes (2.77 MB) including dependencies; 45,090 triangles for the entire set. This is a collection of 18 named meshes, not one single air duct. Select and position individual mesh nodes such as `modular_airduct_rectangular_01_single_01`, `modular_airduct_rectangular_01_bend_01`, or `modular_airduct_rectangular_01_vent_01` instead of placing the complete laid-out set as a single duct. Static; no animation clips.

## Propane Tank

- **Creator:** Slinc; **source:** [Poly Haven model page](https://polyhaven.com/a/propane_tank), [1K glTF direct download](https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/propane_tank/propane_tank_1k.gltf), [official dependency manifest](https://api.polyhaven.com/files/propane_tank).
- **Load:** `/assets/models/propane_tank/propane_tank_1k.gltf`.
- **Files:** `propane_tank/propane_tank_1k.gltf`, `propane_tank/propane_tank.bin`, `propane_tank/textures/propane_tank_diff_1k.jpg`, `propane_tank/textures/propane_tank_nor_gl_1k.jpg`, and `propane_tank/textures/propane_tank_arm_1k.jpg`.
- **Details:** 2,214,101 bytes (2.21 MB) including dependencies; 5,238 triangles. Worn red gas cylinder, suitable as a maintenance-room prop. Static; no animation clips.

## Crowbar 01

- **Creator:** Alexander Otterbeck; **source:** [Poly Haven model page](https://polyhaven.com/a/crowbar_01), [1K glTF direct download](https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/crowbar_01/crowbar_01_1k.gltf), [official dependency manifest](https://api.polyhaven.com/files/crowbar_01).
- **Load:** `/assets/models/crowbar_01/crowbar_01_1k.gltf`.
- **Files:** `crowbar_01/crowbar_01_1k.gltf`, `crowbar_01/crowbar_01.bin`, `crowbar_01/textures/crowbar_01_diff_1k.jpg`, `crowbar_01/textures/crowbar_01_nor_gl_1k.jpg`, and `crowbar_01/textures/crowbar_01_arm_1k.jpg`.
- **Details:** 1,588,321 bytes (1.59 MB) including dependencies; 2,300 triangles. Weathered crowbar for an environmental or interactable prop. Static; no animation clips.

## Zombie, from Zombie Apocalypse Kit

- **Creator:** Quaternius; **source:** [official kit page and CC0 declaration](https://quaternius.com/packs/zombieapocalypsekit.html), [Poly Pizza model listing](https://poly.pizza/m/VlXjG0N8Eg), [direct GLB download](https://static.poly.pizza/c4002f69-6979-42e8-ad6e-2f4e14fc3a9d.glb). This GLB is the Poly Pizza-hosted version, not the original glTF download.
- **Load:** `/assets/models/quaternius_zombie/Zombie_PolyPizza.glb`.
- **Files:** `quaternius_zombie/Zombie_PolyPizza.glb`; the 512 × 512 texture and geometry are embedded.
- **Details:** 981,672 bytes (0.98 MB); 7,822 triangles. The character is stylized and cartoony, unlike the realistic Poly Haven props. The GLB contains 32 animation entries: 16 named clips and 16 corresponding `CharacterArmature|`-prefixed entries. Named examples include `Idle`, `Walk`, `Run`, `Run_Attack`, `Crawl`, `Punch`, `HitReact`, and `Death`. Playback depends on the runtime's glTF animation support and was not tested in this project.

## Runtime notes

Use a glTF 2.0-compatible loader. Serve each Poly Haven glTF together with its sibling `.bin` and `textures` files, preserving their relative locations; copying only the `.gltf` will omit geometry and materials. The GLB is self-contained. The downloaded files' external references, binary lengths, image decoding, triangle counts, and the zombie's animation entries were checked; a full in-game visual/performance test was not performed. Original Poly Haven downloads matched the official API's MD5 and byte-size metadata.
