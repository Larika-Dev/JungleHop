// Junior Varsity Cinema (CLAUDE.md §11): lobby, concession counter, 2 auditoriums with raked seating
// platforms (no seats — items later), projection booth on the mezzanine, marquee with bulbs.
import { C, boxC } from '../kits/common';
import { customPlan, stackStairs, uStairSize } from '../interiors/floorplan';
import { SHAFT } from '../interiors/finishes';
import { LANDMARK_HOOKS } from '../buildings/manager';

LANDMARK_HOOKS.set('cinema', {
  plan: (spec) => customPlan(spec, (pb, fl, W, D, t) => {
    const lobbyD = 900, sw = 112, across = 2 * sw + 10;
    const sd = uStairSize(Math.max(...fl.map((f) => f.ftf)), sw).along + sw + 30;
    for (const f of fl) {
      const F = f.floor;
      const st = pb.room(F, { x0: t, z0: t, x1: t + across + 30, z1: t + sd }, 'stair', 'Stair');
      pb.fireWall(st);
      const el = pb.room(F, { x0: t + across + 30, z0: t, x1: t + across + 30 + SHAFT.w + 60, z1: t + SHAFT.d + 60 }, 'elevator_lobby', 'Elevator');
      if (F === 0) {
        const lob = pb.room(F, { x0: t + across + 30, z0: t + SHAFT.d + 60, x1: W - t, z1: t + lobbyD }, 'lobby', 'Lobby & concessions');
        const lob2 = pb.room(F, { x0: el.rect.x1, z0: t, x1: W - t, z1: t + SHAFT.d + 60 }, 'lobby', 'Box office');
        const side = pb.room(F, { x0: t, z0: t + sd, x1: t + across + 30, z1: t + lobbyD }, 'restroom');
        pb.open(lob, lob2); pb.open(el, lob); pb.door(st, lob, 'start'); pb.door(lob, side, 'start');
        const a1 = pb.room(F, { x0: t, z0: t + lobbyD, x1: W / 2, z1: D - t }, 'theater', 'Auditorium 1');
        const a2 = pb.room(F, { x0: W / 2, z0: t + lobbyD, x1: W - t, z1: D - t }, 'theater', 'Auditorium 2');
        pb.door(lob, a1, 'mid', 183); pb.door(lob, a2, 'mid', 183);
        pb.extDoors.push({ floor: 0, side: 'front', at: Math.round(W / 2) - 91, w: 183, h: 213, style: 'storefront', y: 0 });
        pb.extDoors.push({ floor: 0, side: 'back', at: Math.round(W / 2) - 45, w: 91, h: 213, style: 'steel', y: 0 });
      } else {
        const booth = pb.room(F, { x0: el.rect.x1, z0: t, x1: W - t, z1: t + lobbyD }, 'projection', 'Projection booth');
        const off = pb.room(F, { x0: t, z0: t + sd, x1: el.rect.x1, z1: t + lobbyD }, 'office', 'Manager');
        pb.door(st, off, 'start'); pb.open(el, off); pb.door(off, booth, 'mid');
        pb.extDoors.push({ floor: F, side: 'back', at: 200, w: 91, h: 213, style: 'steel', y: f.y });
        // upper volume of the auditoriums (double-height)
        const v1 = pb.room(F, { x0: t, z0: t + lobbyD, x1: W / 2, z1: D - t }, 'theater', 'Auditorium 1 (upper)');
        const v2 = pb.room(F, { x0: W / 2, z0: t + lobbyD, x1: W - t, z1: D - t }, 'theater', 'Auditorium 2 (upper)');
        pb.open(v1, booth); pb.open(v2, booth);
        pb.hole(F, { x0: t, z0: t + lobbyD + 10, x1: W - t, z1: D - t });
      }
    }
    stackStairs(pb, fl, (rise) => ({ x0: t + 15, z0: t + sd - 15 - uStairSize(rise, sw).along, x1: t + 15 + across, z1: t + sd - 15 }), 'z+', sw, 'A');
    pb.shafts.push({ rect: { x0: t + across + 40, z0: t + 10, x1: t + across + 40 + SHAFT.w + 40, z1: t + 10 + SHAFT.d + 40 }, floors: fl.map((f) => f.floor), door: 'z1' });
  }),
  interior: (spec, plan, g) => {
    const f0 = plan.floors.find((f) => f.floor === 0)!;
    for (const r of f0.rooms.filter((r) => r.type === 'theater')) {
      // raked seating platforms rising away from the screen (screen at the back wall)
      const n = Math.floor((r.rect.z1 - r.rect.z0 - 500) / 100);
      for (let i = 0; i < n; i++) boxC(g, 'tex:carpet_inn', r.rect.x0, 0, r.rect.z0 + i * 100, r.rect.x1, 30 + (n - i) * 18, r.rect.z0 + (i + 1) * 100);
      boxC(g, 'paint:ONSU_WHITE', r.rect.x0 + 60, 140, r.rect.z1 - 3, r.rect.x1 - 60, 140 + (r.rect.x1 - r.rect.x0 - 120) * 0.42, r.rect.z1 - 1, 32); // screen
      boxC(g, 'tex:oak_floor', r.rect.x0, 0, r.rect.z1 - 400, r.rect.x1, 60, r.rect.z1 - 3); // stage apron
    }
    const lob = f0.rooms.find((r) => r.label === 'Lobby & concessions');
    if (lob) { boxC(g, 'paint:CINEMA_MAROON', lob.rect.x0 + 100, 0, lob.rect.z1 - 150, lob.rect.x1 - 100, 100, lob.rect.z1 - 80); boxC(g, 'tex:marble', lob.rect.x0 + 95, 100, lob.rect.z1 - 155, lob.rect.x1 - 95, 105, lob.rect.z1 - 75); }
    void spec; void C;
  },
  exterior: (spec, plan, out) => {
    // marquee: black box projecting over the sidewalk with three rows of bulbs
    const g = out.g, W = spec.w;
    boxC(g, 'paint:DOOR_BLACK', W * 0.1, 340, -250, W * 0.9, 470, -20);
    for (let x = W * 0.1 + 12; x < W * 0.9; x += 24) for (const y of [345, 465]) g.cylinder('glow:MARQUEE_BULB', C(3), C(y - 3), C(y + 3), 8, true, C(x), C(-251));
    for (let x = W * 0.1 + 12; x < W * 0.9; x += 24) g.cylinder('glow:MARQUEE_BULB', C(3), C(338), C(340), 8, true, C(x), C(-150));
    boxC(g, 'paint:MARQUEE_BULB', W * 0.12, 360, -252, W * 0.88, 450, -251); // letter board (titles in signage pass)
    // vertical blade sign
    boxC(g, 'paint:CINEMA_MAROON', W / 2 - 40, 480, -160, W / 2 + 40, plan.roofY + 200, -100);
    void plan;
  },
});
