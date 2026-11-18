import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// All dimensions and interactive positions are in the server's world space.
const TARGETS = [
  { id: 'fuse', x: -6, z: 10, label: 'Take the fuse', detail: 'A replacement for the maintenance generator.' },
  { id: 'generator', x: -6, z: 0, label: 'Restore the generator', detail: 'Insert the fuse to bring the facility back online.' },
  { id: 'key', x: 6, z: -5, label: 'Take the archive key', detail: 'The key cabinet needs power.' },
  { id: 'archive', x: 0, z: -12, label: 'Unlock the archive', detail: 'The archive key opens this security door.' },
  { id: 'note1', x: 5, z: -17, label: 'Collect recording 01', detail: 'A fragment of the last transmission.' },
  { id: 'note2', x: -5, z: -22, label: 'Collect recording 02', detail: 'A fragment of the last transmission.' },
  { id: 'note3', x: 5, z: -27, label: 'Collect recording 03', detail: 'A fragment of the last transmission.' },
  { id: 'exit', x: 0, z: -32, label: 'Open the exit', detail: 'Bring all three recordings to the exit.' },
];
const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
const finite = (n, fallback = 0) => Number.isFinite(Number(n)) ? Number(n) : fallback;
const lerpAngle = (a, b, t) => a + Math.atan2(Math.sin(b - a), Math.cos(b - a)) * t;

export function createGame({ canvas, onInteract = () => {}, onPose = () => {}, onHint = () => {}, onSound = () => {}, onBattery = () => {} }) {
  if (!canvas) throw new Error('createGame requires a canvas');
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.8;
  renderer.setClearColor(0x090f13);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x090f13);
  scene.fog = new THREE.FogExp2(0x0b1114, 0.034);
  const camera = new THREE.PerspectiveCamera(68, 1, 0.055, 75);
  camera.rotation.order = 'YXZ';
  scene.add(camera);
  const ambient = new THREE.HemisphereLight(0x91a9aa, 0x303936, 2.2);
  scene.add(ambient);
  scene.add(new THREE.AmbientLight(0x768078, 0.65));

  const state = {
    snapshot: null, running: false, disposed: false, x: 0, z: 16, yaw: 0, pitch: 0,
    crouch: false, sprint: false, flashlight: true, battery: 1, seq: Date.now(),
    moveX: 0, moveY: 0, keys: new Set(), sensitivity: 1, resolution: 1, quality: 'medium',
    frame: 0, previous: 0, poseTime: 0, stepTime: 0, batteryReport: 0, elapsed: 0, hint: '', selfId: null, monsterSoundTime: -10,
    ownPositionInitialized: false, gamepadButtons: [], touchCrouch: false, touchSprint: false,
  };
  const resources = new Set();
  const addResource = resource => { resources.add(resource); return resource; };
  const mat = (color, options = {}) => addResource(new THREE.MeshStandardMaterial({ color, roughness: 0.9, ...options }));
  const paint = mat(0x596463);
  const darkPaint = mat(0x273431);
  const metal = mat(0x424d49, { metalness: 0.65, roughness: 0.57 });
  const black = mat(0x131c1d, { metalness: 0.35 });
  const rust = mat(0x5e4234, { metalness: 0.28, roughness: 0.95 });
  const brass = mat(0x9b7950, { metalness: 0.65, roughness: 0.45 });
  const paper = mat(0xb6a98a);
  const red = mat(0x92352b, { emissive: 0x44140e, emissiveIntensity: 0.4 });
  const glow = mat(0xb0cdb8, { emissive: 0x6d9d84, emissiveIntensity: 0.65 });
  const dimGlow = mat(0x8b9b83, { emissive: 0x5a7866, emissiveIntensity: 0.5 });
  const glass = mat(0x48625f, { metalness: 0.35, roughness: 0.24, transparent: true, opacity: 0.45 });
  const unitBox = addResource(new THREE.BoxGeometry(1, 1, 1));
  const unitCylinder = addResource(new THREE.CylinderGeometry(0.5, 0.5, 1, 10));
  const sphere = addResource(new THREE.SphereGeometry(0.5, 12, 8));
  const detailGroup = new THREE.Group();
  scene.add(detailGroup);
  const colliders = [];
  const interactiveVisuals = {};
  const overheadLights = [];
  const animated = [];

  function box(x, y, z, w, h, d, material, parent = scene) {
    const m = new THREE.Mesh(unitBox, material);
    m.position.set(x, y, z); m.scale.set(w, h, d);
    m.castShadow = true; m.receiveShadow = true;
    parent.add(m); return m;
  }
  function cylinder(x, y, z, radius, height, material, parent = scene) {
    const m = new THREE.Mesh(unitCylinder, material);
    m.position.set(x, y, z); m.scale.set(radius * 2, height, radius * 2);
    m.castShadow = true; m.receiveShadow = true;
    parent.add(m); return m;
  }
  function ball(x, y, z, rx, ry, rz, material, parent = scene) {
    const m = new THREE.Mesh(sphere, material);
    m.position.set(x, y, z); m.scale.set(rx * 2, ry * 2, rz * 2); parent.add(m); return m;
  }
  function obstacle(x, z, w, d) { colliders.push({ minX: x - w / 2, maxX: x + w / 2, minZ: z - d / 2, maxZ: z + d / 2 }); }

  // Repeating, hand-dirtied textures: inexpensive and self-contained, without downloaded assets.
  function texture(kind) {
    const c = document.createElement('canvas'); c.width = c.height = 512;
    const ctx = c.getContext('2d');
    let seed = kind === 'floor' ? 1297 : 943;
    const rand = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
    ctx.fillStyle = kind === 'floor' ? '#59605b' : '#66706b'; ctx.fillRect(0, 0, 512, 512);
    for (let i = 0; i < 7000; i++) {
      const v = Math.floor(rand() * 45);
      ctx.fillStyle = `rgba(${v},${v + 3},${v + 1},${0.025 + rand() * 0.12})`;
      ctx.fillRect(rand() * 512, rand() * 512, 1 + rand() * 3, 1 + rand() * 3);
    }
    if (kind === 'floor') {
      ctx.strokeStyle = 'rgba(15,22,20,.38)'; ctx.lineWidth = 4;
      for (let p = 0; p <= 512; p += 128) { ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, 512); ctx.stroke(); ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(512, p); ctx.stroke(); }
      for (let i = 0; i < 24; i++) { ctx.strokeStyle = `rgba(24,30,25,${0.05 + rand() * 0.12})`; ctx.lineWidth = 0.5 + rand() * 2; ctx.beginPath(); const x = rand() * 512, y = rand() * 512; ctx.moveTo(x, y); ctx.lineTo(x + rand() * 70 - 35, y + rand() * 50); ctx.stroke(); }
    } else {
      for (let i = 0; i < 90; i++) { const x = rand() * 512; ctx.fillStyle = `rgba(32,36,28,${0.025 + rand() * 0.07})`; ctx.fillRect(x, rand() * 512, 1 + rand() * 5, 25 + rand() * 135); }
      ctx.strokeStyle = 'rgba(15,24,19,.18)'; ctx.lineWidth = 2; ctx.strokeRect(2, 2, 508, 508);
    }
    const t = addResource(new THREE.CanvasTexture(c)); t.colorSpace = THREE.SRGBColorSpace;
    t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(kind === 'floor' ? 5 : 2, kind === 'floor' ? 15 : 1);
    t.anisotropy = 1; return t;
  }
  const floorMat = mat(0x8d9690, { map: texture('floor'), metalness: 0.08, roughness: 0.92 });
  const wallMat = mat(0x858f87, { map: texture('wall'), roughness: 0.95 });
  box(0, -0.14, -7, 18.4, 0.28, 54.4, floorMat);
  box(0, 4.05, -7, 18.4, 0.2, 54.4, darkPaint);
  // Shell, deliberately open within each sector so every authored target is navigable.
  box(-9.1, 2, -7, 0.2, 4, 54.4, wallMat); box(9.1, 2, -7, 0.2, 4, 54.4, wallMat);
  box(0, 2, 20.1, 18.4, 4, 0.2, wallMat); box(0, 2, -34.1, 18.4, 4, 0.2, wallMat);
  for (const x of [-9, 9]) {
    box(x, 0.18, -7, 0.17, 0.25, 54, black);
    box(x, 2.95, -7, 0.16, 0.1, 54, metal);
    for (let z = -32; z <= 18; z += 4) {
      box(x, 1.95, z, 0.13, 3.8, 0.12, darkPaint, detailGroup);
      box(x > 0 ? 8.88 : -8.88, 1.0, z - 1.8, 0.13, 0.06, 3.55, metal, detailGroup);
    }
  }
  // Section partitions, each with a generous central opening.
  function partition(z, opening) {
    const w = (18 - opening) / 2;
    for (const sign of [-1, 1]) {
      const x = sign * (opening / 2 + w / 2);
      box(x, 2, z, w, 4, 0.3, wallMat); obstacle(x, z, w, 0.3);
      box(sign * (opening / 2 + 0.06), 1.75, z, 0.18, 3.5, 0.48, metal);
    }
    box(0, 3.65, z, opening, 0.7, 0.3, wallMat);
    box(0, 3.32, z, opening, 0.15, 0.48, metal);
  }
  partition(4, 6.6); partition(-12, 4.5);

  // Surface-mounted pipes, conduits and ceiling service channels.
  for (const x of [-7.9, 7.9]) {
    for (const z of [-25, -13, -1, 11]) {
      const pipe = cylinder(x, 3.7, z, 0.075, 11.8, metal, detailGroup); pipe.rotation.x = Math.PI / 2;
      for (const offset of [-4, 0, 4]) box(x, 3.72, z + offset, 0.32, 0.18, 0.1, rust, detailGroup);
    }
  }
  for (let z = -30; z <= 18; z += 6) {
    box(0, 3.87, z, 17.8, 0.14, 0.15, metal, detailGroup);
    for (const x of [-4.4, 4.4]) box(x, 3.83, z, 0.13, 0.13, 5.8, black, detailGroup);
  }
  function sign(text, x, y, z, width, height, rotY = 0, subtitle = '') {
    const c = document.createElement('canvas'); c.width = 768; c.height = 256;
    const ctx = c.getContext('2d'); ctx.fillStyle = '#1e2b28'; ctx.fillRect(0, 0, 768, 256);
    ctx.strokeStyle = '#88988a'; ctx.lineWidth = 8; ctx.strokeRect(12, 12, 744, 232);
    ctx.fillStyle = '#bdc5ab'; ctx.font = 'bold 74px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(text, 384, subtitle ? 116 : 148);
    if (subtitle) { ctx.fillStyle = '#87988a'; ctx.font = '30px monospace'; ctx.fillText(subtitle, 384, 183); }
    const t = addResource(new THREE.CanvasTexture(c)); t.colorSpace = THREE.SRGBColorSpace;
    const m = mat(0xffffff, { map: t, emissive: 0x1b2722, emissiveIntensity: 0.3 });
    const panel = new THREE.Mesh(addResource(new THREE.PlaneGeometry(width, height)), m);
    panel.position.set(x, y, z); panel.rotation.y = rotY; scene.add(panel); return panel;
  }
  sign('RECEPTION', 0, 2.85, 19.98, 3.9, 1, Math.PI, 'NORTHWING COMMUNICATIONS');
  sign('MAINTENANCE', 0, 3.72, 4.19, 4.2, 0.55, 0, 'AUTHORIZED PERSONNEL ONLY');
  sign('ARCHIVE', 0, 3.76, -11.79, 3.2, 0.48, 0, 'RESTRICTED ACCESS');
  sign('EMERGENCY EXIT', 0, 3.4, -33.96, 3.4, 0.75, 0, 'KEEP ROUTE CLEAR');
  sign('NO SIGNAL', -8.97, 2.1, 15, 2.3, 0.85, Math.PI / 2, 'DO NOT LEAVE THIS AREA');
  sign('POWER / AUX', -8.97, 2.2, 0, 2.3, 0.8, Math.PI / 2, 'GENERATOR ACCESS');

  function ceilingFixture(z, color = 0xa8c8b1, intensity = 0.7) {
    box(0, 3.86, z, 2.0, 0.15, 0.65, black);
    box(0, 3.75, z, 1.58, 0.07, 0.22, glow);
    for (const x of [-0.76, 0, 0.76]) box(x, 3.7, z, 0.04, 0.1, 0.55, metal, detailGroup);
    const light = new THREE.PointLight(color, intensity, 12, 1.8); light.position.set(0, 3.45, z); scene.add(light); overheadLights.push(light);
  }
  for (const z of [17, 9, 1, -7, -16, -23, -30]) ceilingFixture(z, z < -12 ? 0x8daca0 : 0xb5c5a6, z < -12 ? 0.52 : 0.72);
  const emergencyLight = new THREE.PointLight(0xa53021, 1.1, 7); emergencyLight.position.set(0, 2.8, -12); scene.add(emergencyLight);
  box(2.2, 2.6, -11.77, 0.14, 0.3, 0.08, red);

  // Reception: windowed desk, documents, cabinets, a dead terminal and fuse box.
  box(-4.65, 0.53, 14.1, 5.2, 1.06, 0.72, darkPaint); obstacle(-4.65, 14.1, 5.2, 0.72);
  box(-4.65, 1.1, 14.1, 5.4, 0.1, 0.95, metal);
  for (let x = -6.8; x <= -2.6; x += 1.05) box(x, 0.55, 14.49, 0.025, 0.92, 0.025, brass, detailGroup);
  box(-5.1, 1.5, 14.05, 1.0, 0.65, 0.12, black); box(-5.1, 1.5, 13.97, 0.84, 0.5, 0.02, glass);
  box(-5.1, 1.18, 14.05, 0.14, 0.15, 0.25, metal); box(-5.1, 1.12, 14.05, 0.5, 0.05, 0.35, metal);
  for (const x of [-6.4, -3.1]) { const page = box(x, 1.17, 13.98, 0.55, 0.018, 0.38, paper, detailGroup); page.rotation.y = x; }
  for (let i = 0; i < 3; i++) {
    const x = 6.2 + i * 0.8; box(x, 1.0, 17.4, 0.72, 2, 0.65, darkPaint); box(x, 1.05, 17.04, 0.6, 1.7, 0.03, metal);
    for (let k = 0; k < 4; k++) box(x, 1.65 - k * 0.09, 17.01, 0.33, 0.025, 0.02, black, detailGroup);
    box(x + 0.2, 0.95, 16.99, 0.04, 0.24, 0.04, brass, detailGroup);
  }
  obstacle(7, 17.4, 2.4, 0.65);
  box(-6, 0.45, 10, 1.05, 0.9, 0.7, rust); box(-6, 0.93, 10, 1.16, 0.08, 0.8, metal); obstacle(-6, 10, 1.05, 0.7);
  const fuseGroup = new THREE.Group(); fuseGroup.position.set(-6, 1.06, 10); scene.add(fuseGroup); interactiveVisuals.fuse = fuseGroup;
  const fuseBody = cylinder(0, 0.12, 0, 0.095, 0.46, glow, fuseGroup); fuseBody.rotation.z = Math.PI / 2;
  for (const x of [-0.23, 0.23]) { const end = cylinder(x, 0.12, 0, 0.11, 0.1, brass, fuseGroup); end.rotation.z = Math.PI / 2; }

  // Maintenance: a physically layered generator, cable runs, control gauges, and tool storage.
  box(-6.15, 0.7, 0, 2.5, 1.4, 1.35, darkPaint); obstacle(-6.15, 0, 2.5, 1.35);
  box(-6.15, 1.45, 0, 2.65, 0.1, 1.5, metal); box(-6.15, 0.7, 0.72, 2.2, 1.1, 0.08, metal);
  for (let i = 0; i < 8; i++) box(-7.05 + i * 0.25, 0.62, 0.77, 0.11, 0.65, 0.025, black, detailGroup);
  for (const x of [-6.85, -6.15, -5.45]) { const gauge = cylinder(x, 1.16, 0.79, 0.15, 0.035, black); gauge.rotation.x = Math.PI / 2; const face = cylinder(x, 1.16, 0.82, 0.11, 0.02, paper); face.rotation.x = Math.PI / 2; }
  const generatorLamp = ball(-5.2, 1.3, 0.8, 0.075, 0.075, 0.04, red);
  box(-8.8, 0.65, -3.5, 0.25, 1.25, 5, metal, detailGroup);
  for (let i = 0; i < 4; i++) { box(7.9, 0.55 + i * 0.62, 0, 1.4, 0.06, 3.2, metal, detailGroup); }
  for (const z of [-1.45, 1.45]) box(7.9, 1.3, z, 0.12, 2.6, 0.12, metal, detailGroup);
  for (let i = 0; i < 5; i++) { box(7.8, 0.78 + (i % 3) * 0.62, -1.05 + i * 0.5, 0.65, 0.35, 0.4, i % 2 ? rust : darkPaint, detailGroup); }
  obstacle(7.9, 0, 1.4, 3.2);
  // Powered key cabinet.
  box(6, 1.15, -5, 1.25, 2.3, 0.62, darkPaint); obstacle(6, -5, 1.25, 0.62);
  box(6, 1.37, -4.66, 1.05, 1.53, 0.05, metal); box(6, 1.37, -4.62, 0.75, 1.18, 0.035, black);
  const keyGroup = new THREE.Group(); keyGroup.position.set(6, 1.4, -4.57); scene.add(keyGroup); interactiveVisuals.key = keyGroup;
  const keyRing = new THREE.Mesh(addResource(new THREE.TorusGeometry(0.10, 0.025, 6, 12)), brass); keyRing.position.y = 0.1; keyGroup.add(keyRing);
  box(0, -0.14, 0, 0.04, 0.32, 0.04, brass, keyGroup); box(0.08, -0.25, 0, 0.18, 0.04, 0.04, brass, keyGroup);

  // Archive door panels retract sideways on unlock. Blocking collision follows the same snapshot.
  const doorLeft = new THREE.Group(); const doorRight = new THREE.Group();
  scene.add(doorLeft, doorRight); doorLeft.position.set(-1.1, 0, -12); doorRight.position.set(1.1, 0, -12);
  for (const door of [doorLeft, doorRight]) {
    box(0, 1.62, 0, 2.18, 3.24, 0.22, darkPaint, door);
    box(0, 1.65, 0.14, 1.85, 2.8, 0.04, metal, door);
    for (const y of [0.55, 1.35, 2.15]) box(0, y, 0.18, 1.55, 0.045, 0.03, black, door);
    box(0, 2.65, 0.18, 1.35, 0.4, 0.03, black, door);
  }
  const archiveCollider = { minX: -2.25, maxX: 2.25, minZ: -12.18, maxZ: -11.82 };
  const archiveIndicator = ball(2.1, 1.8, -11.72, 0.07, 0.07, 0.05, red);
  // Shelves hug the walls rather than making an impassable maze.
  for (const side of [-1, 1]) for (const z of [-17, -22, -27]) {
    const x = side * 7.8;
    for (const level of [0.18, 0.85, 1.52, 2.2, 2.87]) box(x, level, z, 1.7, 0.08, 3.0, metal);
    for (const dz of [-1.4, 1.4]) for (const dx of [-0.78, 0.78]) box(x + dx, 1.53, z + dz, 0.09, 3.0, 0.09, metal, detailGroup);
    for (let i = 0; i < 5; i++) for (const y of [0.57, 1.24, 1.91]) {
      const b = box(x, y, z - 1.15 + i * 0.55, 0.75, 0.43, 0.45, (i + z) % 2 ? darkPaint : rust, detailGroup);
      box(x - side * 0.4, y + 0.05, b.position.z, 0.025, 0.12, 0.24, paper, detailGroup);
    }
    obstacle(x, z, 1.7, 3.0);
  }
  for (let i = 0; i < 3; i++) {
    const target = TARGETS[4 + i]; const x = target.x, z = target.z;
    box(x, 0.55, z, 1.35, 1.1, 0.95, darkPaint); box(x, 1.13, z, 1.45, 0.09, 1.04, metal); obstacle(x, z, 1.35, 0.95);
    const note = new THREE.Group(); note.position.set(x, 1.19, z); scene.add(note); interactiveVisuals[target.id] = note;
    box(0, 0.025, 0, 0.67, 0.05, 0.48, paper, note);
    for (let k = 0; k < 4; k++) box(0, 0.055, -0.14 + k * 0.08, 0.48 - k * 0.035, 0.006, 0.015, black, note);
    box(0.24, 0.06, 0.13, 0.14, 0.035, 0.09, red, note);
  }
  box(0, 1.6, -33.84, 3.2, 3.2, 0.3, darkPaint);
  for (const x of [-0.78, 0.78]) { box(x, 1.6, -33.64, 1.48, 2.9, 0.1, metal); box(x, 2.0, -33.56, 0.9, 0.55, 0.04, black); box(x + 0.45, 1.1, -33.53, 0.05, 0.4, 0.05, brass); }
  // These local props are optional; the procedural facility remains complete if they are absent.
  const loader = new GLTFLoader();
  function optionalProp(path, position, rotation = [0, 0, 0]) {
    const base = import.meta.env?.BASE_URL || './';
    loader.load(`${base}assets/models/${path}`, gltf => {
      gltf.scene.traverse(child => {
        if (child.geometry) resources.add(child.geometry);
        const materials = child.material ? (Array.isArray(child.material) ? child.material : [child.material]) : [];
        for (const material of materials) {
          resources.add(material);
          for (const value of Object.values(material)) if (value?.isTexture) resources.add(value);
        }
      });
      if (state.disposed) { for (const resource of resources) resource.dispose?.(); return; }
      gltf.scene.position.set(...position); gltf.scene.rotation.set(...rotation); detailGroup.add(gltf.scene);
    }, undefined, () => {});
  }
  optionalProp('propane_tank/propane_tank_1k.gltf', [8.1, 0, -3.5]);
  optionalProp('crowbar_01/crowbar_01_1k.gltf', [-6.1, 1.53, 0], [0, 0, Math.PI / 2]);
  // Debris and stains are decorative only; no hidden navigation blockers.
  for (let i = 0; i < 28; i++) {
    const x = Math.sin(i * 14.7) * 7.8, z = 18 - i * 1.8;
    const scrap = box(x, 0.018, z, 0.25 + (i % 4) * 0.08, 0.015, 0.18 + (i % 3) * 0.08, i % 3 ? paper : rust, detailGroup);
    scrap.rotation.y = i * 1.7;
  }
  // A flashlight follows the camera. Depletion is client-side and recharges slowly when switched off.
  const flashlight = new THREE.SpotLight(0xe3f0cb, 48, 24, Math.PI / 8, 0.55, 1.4);
  flashlight.castShadow = true;
  flashlight.shadow.mapSize.set(512, 512);
  flashlight.shadow.bias = -0.0002;
  flashlight.shadow.camera.near = 0.1;
  flashlight.shadow.camera.far = 24;
  flashlight.position.set(0.12, -0.08, 0); const flashlightTarget = new THREE.Object3D(); flashlightTarget.position.set(0, -0.04, -12);
  camera.add(flashlight, flashlightTarget); flashlight.target = flashlightTarget;
  const beamFill = new THREE.PointLight(0xd5e6bf, 0.35, 4.5); beamFill.position.set(0, -0.15, -0.4); camera.add(beamFill);

  function makePerson(monster = false) {
    const root = new THREE.Group(); const body = new THREE.Group(); root.add(body);
    const cloth = monster ? mat(0x222621, { roughness: 1 }) : mat(0x3e504a);
    const skin = monster ? mat(0x60635a) : mat(0x908978);
    const pants = monster ? black : mat(0x242f2e);
    const torso = box(0, monster ? 1.39 : 1.12, 0, monster ? 0.59 : 0.55, monster ? 1.06 : 0.7, 0.3, cloth, body);
    torso.rotation.z = monster ? 0.07 : 0;
    ball(0, monster ? 2.03 : 1.66, 0, monster ? 0.19 : 0.2, monster ? 0.27 : 0.23, 0.18, skin, body);
    if (monster) {
      for (const x of [-0.09, 0.09]) ball(x, 2.07, -0.17, 0.034, 0.032, 0.018, red, body);
      for (let i = 0; i < 5; i++) box(0, 1.14 + i * 0.14, -0.17, 0.43 - i * 0.02, 0.025, 0.02, skin, body);
    } else {
      box(0, 1.25, 0.18, 0.43, 0.48, 0.14, darkPaint, body);
      box(0, 1.48, -0.16, 0.31, 0.06, 0.03, brass, body);
    }
    const arms = [], legs = [];
    for (const side of [-1, 1]) {
      const arm = new THREE.Group(); arm.position.set(side * (monster ? 0.36 : 0.33), monster ? 1.75 : 1.42, 0); body.add(arm);
      box(0, monster ? -0.44 : -0.31, 0, monster ? 0.13 : 0.16, monster ? 0.91 : 0.62, 0.17, cloth, arm);
      ball(0, monster ? -0.94 : -0.66, 0, 0.1, 0.1, 0.09, skin, arm); arms.push(arm);
      const leg = new THREE.Group(); leg.position.set(side * 0.16, monster ? 0.91 : 0.81, 0); body.add(leg);
      box(0, monster ? -0.42 : -0.36, 0, 0.19, monster ? 0.82 : 0.72, 0.2, pants, leg);
      box(0, monster ? -0.84 : -0.72, -0.07, 0.2, 0.14, 0.36, black, leg); legs.push(leg);
    }
    let torchLight = null;
    if (!monster) {
      const torch = cylinder(0.34, 0.79, -0.1, 0.055, 0.28, black, body); torch.rotation.x = Math.PI / 2;
      ball(0.34, 0.79, -0.25, 0.05, 0.05, 0.02, glow, body);
      torchLight = new THREE.PointLight(0xd3e6c0, 2, 4, 2); torchLight.position.set(0.34, 0.8, -0.45); body.add(torchLight);
    }
    root.userData = { body, arms, legs, torchLight, moving: false, phase: Math.random() * Math.PI * 2, target: new THREE.Vector3(), yaw: 0 };
    scene.add(root); return root;
  }
  const monster = makePerson(true); monster.position.set(0, 0, -24); monster.userData.target.set(0, 0, -24);
  // A licensed skinned character replaces the geometric safety fallback after loading.
  loader.load(`${import.meta.env?.BASE_URL || './'}assets/models/quaternius_zombie/Zombie_PolyPizza.glb`, gltf => {
    if (state.disposed) return;
    const visual = gltf.scene;
    visual.traverse(child => {
      if (child.geometry) resources.add(child.geometry);
      for (const material of child.material ? (Array.isArray(child.material) ? child.material : [child.material]) : []) {
        resources.add(material);
        for (const value of Object.values(material)) if (value?.isTexture) resources.add(value);
      }
    });
    const bounds = new THREE.Box3().setFromObject(visual);
    const height = Math.max(0.001, bounds.max.y - bounds.min.y);
    const size = 2.05 / height;
    const center = bounds.getCenter(new THREE.Vector3());
    visual.scale.setScalar(size);
    visual.position.set(-center.x * size, -bounds.min.y * size, -center.z * size);
    const facing = new THREE.Group();
    facing.rotation.y = Math.PI;
    facing.add(visual); monster.add(facing);
    monster.userData.body.visible = false;
    const mixer = new THREE.AnimationMixer(visual);
    const find = name => gltf.animations.find(clip => clip.name.toLowerCase() === name.toLowerCase());
    const idle = find('Idle'); const walk = find('Walk') || find('Run');
    monster.userData.gltfMixer = mixer;
    monster.userData.gltfIdle = idle ? mixer.clipAction(idle) : null;
    monster.userData.gltfWalk = walk ? mixer.clipAction(walk) : null;
    monster.userData.gltfCurrent = null;
  }, undefined, () => {});
  const remotePlayers = new Map();

  function canMoveTo(x, z) {
    const radius = 0.34;
    if (x < -9 + radius || x > 9 - radius || z < -34 + radius || z > 20 - radius) return false;
    const world = state.snapshot?.world || {};
    const all = world.archive ? colliders : [...colliders, archiveCollider];
    for (const b of all) if (x + radius > b.minX && x - radius < b.maxX && z + radius > b.minZ && z - radius < b.maxZ) return false;
    return true;
  }
  function targetAvailable(t) {
    const w = state.snapshot?.world || {};
    if (t.id === 'fuse') return !w.fuse && !w.generator;
    if (t.id === 'generator') return !w.generator;
    if (t.id === 'key') return !w.key;
    if (t.id === 'archive') return !w.archive;
    if (t.id.startsWith('note')) return !!w.archive && !w.notes?.[Number(t.id.slice(-1)) - 1];
    if (t.id === 'exit') return !w.completed && !w.exit;
    return false;
  }
  function nearestTarget() {
    if (!state.running || state.snapshot?.phase !== 'playing') return null;
    let nearest = null, dist = 2.55;
    for (const t of TARGETS) {
      if (!targetAvailable(t)) continue;
      const d = Math.hypot(state.x - t.x, state.z - t.z);
      if (d < dist) { dist = d; nearest = t; }
    }
    return nearest;
  }
  function updateHint() {
    const t = nearestTarget();
    const key = t?.id || '';
    if (key !== state.hint) { state.hint = key; onHint(t ? { target: t.id, label: t.label, detail: t.detail } : null); }
  }
  function interact() {
    if (!state.running || state.snapshot?.phase !== 'playing') return;
    const t = nearestTarget();
    if (t) { onInteract(t.id); onSound('pickup'); }
  }
  function toggleFlashlight() {
    if (!state.running || state.snapshot?.phase !== 'playing') return;
    if (!state.flashlight && state.battery < 0.03) { onSound('alert'); return; }
    state.flashlight = !state.flashlight; onSound('switch'); onBattery({ level: state.battery, flashlight: state.flashlight });
  }
  function setLook(dx, dy) {
    if (!state.running || state.snapshot?.phase !== 'playing') return;
    state.yaw -= finite(dx) * 0.0024 * state.sensitivity;
    state.pitch = clamp(state.pitch - finite(dy) * 0.0024 * state.sensitivity, -1.35, 1.35);
  }
  function setMove(x, y) { state.moveX = clamp(finite(x), -1, 1); state.moveY = clamp(finite(y), -1, 1); }
  function setTouchAction(action, pressed) {
    if (action === 'crouch') state.touchCrouch = !!pressed;
    if (action === 'sprint') state.touchSprint = !!pressed;
  }
  function updateSnapshot(snapshot, selfId) {
    if (!snapshot || typeof snapshot !== 'object') return;
    const oldPhase = state.snapshot?.phase;
    state.snapshot = snapshot;
    // selfId is an optional client-only annotation; the wire protocol's welcome contains the id.
    state.selfId = selfId ?? snapshot.selfId ?? snapshot.localPlayerId ?? state.selfId;
    const players = Array.isArray(snapshot.players) ? snapshot.players : [];
    const self = players.find(p => p.id === state.selfId || p.isLocal === true) || (players.length === 1 ? players[0] : null);
    if (self && Number.isFinite(Number(self.x)) && Number.isFinite(Number(self.z))) {
      const distance = Math.hypot(state.x - Number(self.x), state.z - Number(self.z));
      if (!state.ownPositionInitialized || distance > 2.5) { state.x = Number(self.x); state.z = Number(self.z); state.ownPositionInitialized = true; }
    }
    const present = new Set();
    for (const p of players) {
      if (!p?.id || p.id === state.selfId || p.isLocal === true || (players.length === 1 && p === self)) continue;
      present.add(p.id);
      let model = remotePlayers.get(p.id);
      if (!model) { model = makePerson(false); model.position.set(finite(p.x), 0, finite(p.z)); remotePlayers.set(p.id, model); }
      model.userData.target.set(finite(p.x), 0, finite(p.z)); model.userData.yaw = finite(p.yaw);
      model.userData.moving = !!p.sprint || model.position.distanceTo(model.userData.target) > 0.04;
      model.userData.crouch = !!p.crouch; model.userData.connected = p.connected !== false;
      model.userData.torchLight.visible = p.flashlight !== false;
    }
    for (const [id, model] of remotePlayers) if (!present.has(id)) { scene.remove(model); remotePlayers.delete(id); }
    if (snapshot.monster) {
      monster.userData.target.set(finite(snapshot.monster.x), 0, finite(snapshot.monster.z, -24));
      monster.userData.yaw = finite(snapshot.monster.yaw) + Math.PI; monster.userData.moving = monster.position.distanceTo(monster.userData.target) > 0.04;
      monster.visible = snapshot.phase === 'playing';
    }
    const world = snapshot.world || {};
    interactiveVisuals.fuse.visible = !world.fuse && !world.generator;
    interactiveVisuals.key.visible = !world.key;
    for (let i = 0; i < 3; i++) interactiveVisuals[`note${i + 1}`].visible = !world.notes?.[i];
    generatorLamp.material = world.generator ? glow : red;
    archiveIndicator.material = world.archive ? glow : red;
    if (oldPhase !== snapshot.phase && snapshot.phase !== 'playing') { state.keys.clear(); state.moveX = state.moveY = 0; }
    updateHint();
  }
  function resize() {
    const width = canvas.clientWidth || canvas.parentElement?.clientWidth || window.innerWidth || 1;
    const height = canvas.clientHeight || canvas.parentElement?.clientHeight || window.innerHeight || 1;
    const caps = { low: 1, medium: 1.25, high: 1.5, ultra: 2 };
    const ratio = Math.min(window.devicePixelRatio || 1, caps[state.quality]) * state.resolution;
    renderer.setPixelRatio(ratio); renderer.setSize(Math.max(1, width), Math.max(1, height), false);
    camera.aspect = width / Math.max(1, height); camera.updateProjectionMatrix();
  }
  function setSettings(settings = {}) {
    if (['low', 'medium', 'high', 'ultra'].includes(settings.quality)) state.quality = settings.quality;
    if (settings.resolution != null) state.resolution = clamp(finite(settings.resolution, 1), 0.5, 1);
    if (settings.mouseSensitivity != null) state.sensitivity = clamp(finite(settings.mouseSensitivity, 1), 0.1, 4);
    detailGroup.visible = state.quality !== 'low';
    // The two lighter presets deliberately avoid expensive shadow-map passes.
    renderer.shadowMap.enabled = state.quality === 'high' || state.quality === 'ultra';
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    resize();
  }
  function handleKeyDown(e) {
    if (/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || '') || e.metaKey || e.altKey) return;
    if (!state.running || state.snapshot?.phase !== 'playing') return;
    state.keys.add(e.code);
    if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'ControlLeft', 'ControlRight'].includes(e.code)) e.preventDefault();
    if (!e.repeat && e.code === 'KeyE') interact();
    if (!e.repeat && e.code === 'KeyF') toggleFlashlight();
  }
  function handleKeyUp(e) { state.keys.delete(e.code); }
  function handleMouse(e) { if (document.pointerLockElement === canvas) setLook(e.movementX, e.movementY); }
  function lockPointer() { if (state.running && state.snapshot?.phase === 'playing' && document.pointerLockElement !== canvas && canvas.requestPointerLock) { try { const result = canvas.requestPointerLock(); result?.catch?.(() => {}); } catch { /* unavailable on touch browsers */ } } }
  function clearInput() { state.keys.clear(); state.moveX = state.moveY = 0; state.gamepadButtons = []; state.touchCrouch = state.touchSprint = false; }
  window.addEventListener('keydown', handleKeyDown); window.addEventListener('keyup', handleKeyUp);
  document.addEventListener('mousemove', handleMouse); canvas.addEventListener('click', lockPointer);
  window.addEventListener('blur', clearInput); window.addEventListener('resize', resize);
  const resizeObserver = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(resize) : null; resizeObserver?.observe(canvas);
  setSettings({});

  function gamepadInput(dt) {
    if (typeof navigator.getGamepads !== 'function') return null;
    const pad = Array.from(navigator.getGamepads() || []).find(Boolean); if (!pad) { state.gamepadButtons = []; return null; }
    const dead = n => Math.abs(n || 0) > 0.16 ? n : 0;
    const b = i => !!pad.buttons[i]?.pressed;
    if (b(0) && !state.gamepadButtons[0]) interact();
    if (b(2) && !state.gamepadButtons[2]) toggleFlashlight();
    state.gamepadButtons = pad.buttons.map(v => !!v.pressed);
    setLook(dead(pad.axes[2]) * dt * 650, dead(pad.axes[3]) * dt * 650);
    return { x: dead(pad.axes[0]), y: dead(pad.axes[1]), sprint: b(10) || b(7), crouch: b(1) || b(11) };
  }
  function animateActor(model, dt) {
    const u = model.userData; const alpha = 1 - Math.exp(-dt * 8);
    const distance = model.position.distanceTo(u.target); model.position.lerp(u.target, alpha);
    model.rotation.y = lerpAngle(model.rotation.y, u.yaw, alpha);
    u.phase += dt * (u.moving || distance > 0.06 ? 7 : 1);
    const swing = Math.sin(u.phase) * (u.moving || distance > 0.06 ? 0.5 : 0.035);
    u.arms[0].rotation.x = swing; u.arms[1].rotation.x = -swing;
    u.legs[0].rotation.x = -swing; u.legs[1].rotation.x = swing;
    u.body.position.y = u.crouch ? -0.42 : 0;
    if (u.gltfMixer) {
      const next = (u.moving || distance > 0.06 ? u.gltfWalk : u.gltfIdle) || u.gltfWalk || u.gltfIdle;
      if (next && next !== u.gltfCurrent) {
        u.gltfCurrent?.fadeOut(0.2);
        next.reset().fadeIn(0.2).play();
        u.gltfCurrent = next;
      }
      u.gltfMixer.update(dt);
    }
    model.visible = u.connected !== false && (model === monster || state.selfId || Math.hypot(model.position.x - state.x, model.position.z - state.z) > 0.8);
  }
  function tick(now) {
    if (!state.running || state.disposed) return;
    state.frame = requestAnimationFrame(tick);
    const dt = Math.min(0.05, Math.max(0, (now - (state.previous || now)) / 1000)); state.previous = now; state.elapsed += dt;
    const playing = state.snapshot?.phase === 'playing';
    let moving = false;
    if (playing) {
      const pad = gamepadInput(dt);
      let x = (state.keys.has('KeyD') || state.keys.has('ArrowRight') ? 1 : 0) - (state.keys.has('KeyA') || state.keys.has('ArrowLeft') ? 1 : 0) + state.moveX + (pad?.x || 0);
      let y = (state.keys.has('KeyS') || state.keys.has('ArrowDown') ? 1 : 0) - (state.keys.has('KeyW') || state.keys.has('ArrowUp') ? 1 : 0) + state.moveY + (pad?.y || 0);
      const length = Math.hypot(x, y); if (length > 1) { x /= length; y /= length; }
      state.crouch = state.keys.has('ControlLeft') || state.keys.has('ControlRight') || state.keys.has('KeyC') || state.touchCrouch || !!pad?.crouch;
      state.sprint = !state.crouch && (state.keys.has('ShiftLeft') || state.keys.has('ShiftRight') || state.touchSprint || !!pad?.sprint) && length > 0.1;
      const speed = state.crouch ? 1.7 : state.sprint ? 4.5 : 2.8;
      const dx = (x * Math.cos(state.yaw) + y * Math.sin(state.yaw)) * speed * dt;
      const dz = (-x * Math.sin(state.yaw) + y * Math.cos(state.yaw)) * speed * dt;
      if (canMoveTo(state.x + dx, state.z)) state.x += dx;
      if (canMoveTo(state.x, state.z + dz)) state.z += dz;
      moving = length > 0.12 && (Math.abs(dx) + Math.abs(dz) > 0.0001);
      if (moving) { state.stepTime -= dt; if (state.stepTime <= 0) { onSound('step'); state.stepTime = state.sprint ? 0.32 : state.crouch ? 0.8 : 0.55; } }
      if (state.flashlight) { state.battery = Math.max(0, state.battery - dt / 240); if (state.battery === 0) { state.flashlight = false; onSound('alert'); } }
      else state.battery = Math.min(1, state.battery + dt / 480);
      state.batteryReport += dt;
      if (state.batteryReport >= 1) { state.batteryReport %= 1; onBattery({ level: state.battery, flashlight: state.flashlight }); }
      state.poseTime += dt;
      if (state.poseTime >= 0.05) {
        state.poseTime %= 0.05;
        onPose({ x: state.x, z: state.z, yaw: state.yaw, crouch: state.crouch, sprint: state.sprint, flashlight: state.flashlight, seq: ++state.seq });
      }
    } else { state.crouch = false; state.sprint = false; }
    const eyeHeight = state.crouch ? 1.05 : 1.64;
    camera.position.set(state.x, THREE.MathUtils.lerp(camera.position.y || eyeHeight, eyeHeight + (moving ? Math.sin(state.elapsed * (state.sprint ? 13 : 9)) * 0.025 : 0), 1 - Math.exp(-dt * 10)), state.z);
    camera.rotation.set(state.pitch, state.yaw, 0, 'YXZ');
    flashlight.visible = state.flashlight && playing; beamFill.visible = flashlight.visible;
    flashlight.intensity = 48 * (0.3 + 0.7 * Math.min(1, state.battery * 4));
    const opened = !!state.snapshot?.world?.archive;
    doorLeft.position.x = THREE.MathUtils.lerp(doorLeft.position.x, opened ? -3.25 : -1.1, 1 - Math.exp(-dt * 3));
    doorRight.position.x = THREE.MathUtils.lerp(doorRight.position.x, opened ? 3.25 : 1.1, 1 - Math.exp(-dt * 3));
    const powered = !!state.snapshot?.world?.generator;
    for (let i = 0; i < overheadLights.length; i++) {
      const flicker = i === 2 && Math.sin(state.elapsed * 10) > 0.92 ? 0.5 : 1;
      overheadLights[i].intensity = (powered ? 18 : (i === 0 || i === 4 ? 10 : 4)) * flicker;
    }
    emergencyLight.intensity = opened ? 0.15 : 0.65 + Math.sin(state.elapsed * 2) * 0.15;
    for (const model of remotePlayers.values()) animateActor(model, dt);
    if (state.snapshot?.monster && playing) animateActor(monster, dt); else monster.visible = false;
    if (playing && state.snapshot?.monster) {
      const mx = monster.position.x - state.x, mz = monster.position.z - state.z;
      if (Math.hypot(mx, mz) < 10 && state.elapsed - state.monsterSoundTime > 7) {
        const pan = clamp((mx * Math.cos(state.yaw) - mz * Math.sin(state.yaw)) / 10, -1, 1);
        onSound('monster', pan); state.monsterSoundTime = state.elapsed;
      }
    }
    updateHint(); renderer.render(scene, camera);
  }
  function start() { if (state.disposed || state.running) return; state.running = true; state.previous = 0; onBattery({ level: state.battery, flashlight: state.flashlight }); state.frame = requestAnimationFrame(tick); }
  function stop() {
    if (!state.running) return; state.running = false; cancelAnimationFrame(state.frame); state.previous = 0; clearInput();
    if (document.pointerLockElement === canvas) document.exitPointerLock?.();
    if (state.hint) { state.hint = ''; onHint(null); }
  }
  function reset() {
    stop();
    state.snapshot = null; state.selfId = null; state.ownPositionInitialized = false;
    state.x = 0; state.z = 16; state.yaw = 0; state.pitch = 0;
    state.crouch = state.sprint = false; state.flashlight = true; state.battery = 1;
    state.poseTime = 0; state.stepTime = 0; state.batteryReport = 0;
    for (const model of remotePlayers.values()) scene.remove(model);
    remotePlayers.clear();
    onBattery({ level: state.battery, flashlight: state.flashlight });
  }
  function dispose() {
    if (state.disposed) return; stop(); state.disposed = true;
    window.removeEventListener('keydown', handleKeyDown); window.removeEventListener('keyup', handleKeyUp);
    document.removeEventListener('mousemove', handleMouse); canvas.removeEventListener('click', lockPointer);
    window.removeEventListener('blur', clearInput); window.removeEventListener('resize', resize); resizeObserver?.disconnect();
    for (const resource of resources) resource.dispose?.(); renderer.dispose();
  }
  return { start, stop, reset, setSnapshot: updateSnapshot, setSettings, interact, toggleFlashlight, setMove, setLook, setTouchAction, dispose };
}
