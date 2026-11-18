export class Soundscape {
  constructor() {
    this.volume = 0.7;
    this.threat = false;
    this.music = new Audio(`${import.meta.env.BASE_URL}assets/ambience.mp3`);
    this.music.loop = true;
    this.music.preload = 'none';
    this.ctx = null;
    this.lastStep = 0;
    this.lastMonster = 0;
    this.updateMusic();
  }
  unlock() {
    try {
      this.ctx ||= new (window.AudioContext || window.webkitAudioContext)();
      if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
      this.music.play().catch(() => {});
    } catch { /* WebAudio unavailable */ }
  }
  setVolume(v) {
    this.volume = Math.max(0, Math.min(1, Number(v) || 0));
    this.updateMusic();
  }
  setThreat(active) { this.threat = !!active; this.updateMusic(); }
  updateMusic() { this.music.volume = this.volume * (this.threat ? 0.48 : 0.3); }
  sample(file, gainValue = 1, pan = 0) {
    if (!this.volume) return;
    const audio = new Audio(`${import.meta.env.BASE_URL}assets/${file}.mp3`);
    audio.volume = Math.min(1, this.volume * gainValue);
    if (this.ctx && typeof this.ctx.createStereoPanner === 'function') {
      try {
        const source = this.ctx.createMediaElementSource(audio);
        const panner = this.ctx.createStereoPanner();
        panner.pan.value = Math.max(-1, Math.min(1, pan));
        source.connect(panner).connect(this.ctx.destination);
        audio.addEventListener('ended', () => { source.disconnect(); panner.disconnect(); }, { once: true });
      } catch { /* standard audio fallback */ }
    }
    audio.play().catch(() => {});
  }
  cue(name, pan = 0) {
    const now = performance.now();
    if (name === 'step') {
      if (now - this.lastStep < 300) return;
      this.lastStep = now;
      this.sample('footstep', 0.36, pan);
    } else if (name === 'monster' || name === 'alert') {
      if (now - this.lastMonster < 4500) return;
      this.lastMonster = now;
      this.sample('monster', 0.62, pan);
    } else if (name === 'switch' || name === 'pickup' || name === 'interact') {
      this.sample('switch', 0.48, pan);
    }
  }
  stop() { this.music.pause(); }
}
