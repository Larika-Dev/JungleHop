// The Billram (CLAUDE.md §14): ONSU's original ram-goat hybrid mascot — a stocky goat head with heavy
// curled ram horns, a jutting beard and a cheerful grimace. Drawn procedurally in palette colors.
import { css } from '../core/palette';

export function drawBillram(x: CanvasRenderingContext2D, cx: number, cy: number, s: number, mono = false) {
  const blue = mono ? css('ONSU_WHITE') : css('HEAVEN_BLUE'), navy = css('ONSU_NAVY'), white = css('ONSU_WHITE');
  x.save(); x.translate(cx, cy); x.scale(s / 100, s / 100);
  x.lineJoin = 'round'; x.lineWidth = 6; x.strokeStyle = navy;
  // curled ram horns (spirals)
  for (const sx of [-1, 1]) {
    x.beginPath();
    for (let i = 0; i <= 60; i++) { const t = i / 60, a = sx * (Math.PI * 0.2 + t * Math.PI * 2.2), r = 46 - t * 34; x.lineTo(sx * 28 + Math.cos(a) * r * sx, -30 + Math.sin(a) * r); }
    x.lineWidth = 16; x.strokeStyle = navy; x.stroke(); x.lineWidth = 9; x.strokeStyle = blue; x.stroke();
  }
  // head (long goat face)
  x.lineWidth = 6; x.strokeStyle = navy; x.fillStyle = white;
  x.beginPath(); x.moveTo(-30, -40); x.quadraticCurveTo(-40, 10, -18, 48); x.quadraticCurveTo(0, 62, 18, 48); x.quadraticCurveTo(40, 10, 30, -40); x.quadraticCurveTo(0, -58, -30, -40); x.fill(); x.stroke();
  // beard
  x.fillStyle = blue; x.beginPath(); x.moveTo(-12, 52); x.lineTo(0, 92); x.lineTo(12, 52); x.closePath(); x.fill(); x.stroke();
  // eyes (determined) + brow
  x.fillStyle = navy;
  for (const sx of [-1, 1]) { x.beginPath(); x.ellipse(sx * 14, -8, 6, 8, 0, 0, Math.PI * 2); x.fill(); x.beginPath(); x.moveTo(sx * 4, -22); x.lineTo(sx * 24, -16); x.stroke(); }
  // nose & grin
  x.beginPath(); x.ellipse(0, 30, 12, 7, 0, 0, Math.PI * 2); x.fill();
  x.beginPath(); x.moveTo(-14, 42); x.quadraticCurveTo(0, 50, 14, 42); x.stroke();
  // ears
  x.fillStyle = blue;
  for (const sx of [-1, 1]) { x.beginPath(); x.moveTo(sx * 32, -26); x.quadraticCurveTo(sx * 64, -18, sx * 60, -4); x.quadraticCurveTo(sx * 46, -6, sx * 30, -14); x.fill(); x.stroke(); }
  x.restore();
}
