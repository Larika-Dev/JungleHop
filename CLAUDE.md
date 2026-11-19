# PROJECT: CATHEDRAL MOUNT
### A GTA-style fictional college town inspired by downtown Chapel Hill & UNC — built in Three.js, every building enterable, centimeter-level detail

---

## 0. Role & Mission

You are a senior environment artist, technical artist, and world designer building a hand-crafted open-world city in the tradition of Rockstar's GTA maps. Los Santos is not Los Angeles: it captures LA's feel, landmarks, and layout logic, then compresses, remixes, and invents. Do the same for downtown Chapel Hill, NC and the UNC-Chapel Hill campus.

The result is **CATHEDRAL MOUNT**, a fictional college town in the fictional **State of Pamlico**, home of **Old North State University (ONSU)**.

Everything is built in code with **Three.js** (no Blender, no external 3D software). The city runs in a web browser as a walkable first-person world.

**Three non-negotiables:**
1. **Centimeter precision.** Everything is authored on a 1 cm grid with real-world human-scale dimensions.
2. **Exact colors.** Every material uses the hex values defined in this file. Do not invent colors outside the palette without adding them to the palette file first.
3. **Every building has an interior.** Every building is a hollow but architecturally complete shell — rooms, floors, walls, stairs, doors, windows — with **no furniture or items**. Items are added in a later pass, so every room carries metadata slots for them.

---

## 1. Core Philosophy: Reference, Not Replica

- Real Chapel Hill is the reference for **feel, layout logic, architecture, materials, and landmarks**. It is NOT a survey target. Do not try to match GIS footprints, exact building counts, or exact street geometry.
- Freedom from fidelity is spent on **detail**: invented storefronts, alleys, courtyards, and interiors, all modeled with hero-asset density.
- **Keep what makes it recognizable:** a main street running along a ridge with the campus on its south side; Georgian brick-and-stone quads under giant oak canopies; low fieldstone walls; a brick bell tower as the skyline anchor; a stadium sunk into a pine-forest bowl; a hospital complex to the south; a funkier mill town to the west.
- **Compress, merge, invent:** shorten walks between landmarks, combine similar buildings into one better one, add alleys, rooftops, service yards, steam tunnels, and courtyards.

---

## 2. Scale, Units, Coordinates

- **1 Three.js unit = 1 meter.** All authored dimensions snap to **0.01 (1 cm)**. Store dimensions in code as integer centimeters and convert once (`cm(n) => n / 100`) to avoid float drift.
- **Axes:** +X = east, −Z = north, +Y = up (Three.js default). The origin (0,0,0) is the center of **The Summit** intersection (Hamilton St × Columbia St), at street-crown elevation.
- **Human-scale objects are always 1:1** (doors, stairs, bricks, furniture slots, vehicles, signs). Only distances between places are compressed.
- **Compression:** about 60% of real distances.
- **Map size:** dense playable core ≈ **1,600 m (E–W) × 1,400 m (N–S)** ≈ 2.2 km². Outer ring of low-detail forest, suburbs, and highway extends 1 km beyond on every side (total ≈ 3.6 × 3.4 km).
- **Tile grid:** 200 × 200 m tiles, named `T_{col}_{row}`, with col/row counted from the northwest corner of the total map.

---

## 3. Tech Stack & Project Structure

- **Three.js (latest stable) + Vite + TypeScript.** Node.js only; no other installs.
- Use `InstancedMesh` for bricks, stones, seats, trees, pavers, and clutter. Use `BatchedMesh` or merged `BufferGeometry` per building shell.
- Use `MeshStandardMaterial` / `MeshPhysicalMaterial` with textures **generated procedurally in code** (canvas or shader). Support optional texture packs in `/public/textures/` that override procedural textures when present.
- **Playwright** for automated screenshots; **Vitest** for dimension tests.

```
/cathedral-mount
  CLAUDE.md                     ← this file
  /src
    main.ts                     ← boot, renderer, loop
    /core        units.ts, palette.ts, rng.ts (seeded), tiles.ts, streaming.ts
    /terrain     heightfield.ts, ravine.ts, grass.ts
    /roads       network.ts, curbs.ts, sidewalks.ts, markings.ts
    /kits        brick.ts, stone.ts, window.ts, door.ts, cornice.ts, column.ts,
                 stair.ts, railing.ts, roof.ts, storefront.ts, awning.ts, curb.ts
    /interiors   floorplan.ts, rooms.ts, partitions.ts, stairs.ts, shafts.ts,
                 interiorMapping.ts (shader for far windows), roomMeta.ts
    /buildings   generic/ (procedural typologies) + landmarks/ (one file each)
    /districts   one file per district
    /vegetation  trees.ts, shrubs.ts, ivy.ts, leaves.ts
    /street      lamps.ts, benches.ts, signals.ts, signs.ts, hydrants.ts, ...
    /signage     parody.ts, fonts.ts, posters.ts, graffiti.ts
    /lighting    presets.ts, sky.ts, rain.ts
    /player      controls.ts, collision.ts, minimap.ts, doors.ts
    /debug       measure.ts, wireframe.ts, roomLabels.ts, perfHud.ts
  /data          buildings.json, rooms.json, parody-names.json, palette.json
  /tests         kits.test.ts, interiors.test.ts, palette.test.ts
  /screenshots   phase-N/...
  /public        textures/, fonts/
  /export        glTF output
```

**Determinism:** the city is generated from a seeded RNG (`seed = 1795`, the year UNC opened). Same seed, same city, every run.

---

## 4. MASTER COLOR PALETTE (exact hex, sRGB)

Implement as `palette.ts` and mirror it in `data/palette.json`. Every material references a palette key, never a raw hex in other files. Per-instance variation (bricks, stones, leaves) is applied as **±value/±hue jitter around these bases**, using the stated ranges only.

### 4.1 Masonry
| Key | Hex | Use |
|---|---|---|
| BRICK_CAMPUS_A | #8E3B2E | main campus field brick |
| BRICK_CAMPUS_B | #A04A35 | lighter campus stretchers |
| BRICK_CAMPUS_C | #7A3328 | darker campus stretchers |
| BRICK_HEADER_GLAZED | #4A2620 | Flemish-bond glazed headers (slight specular, roughness 0.45) |
| BRICK_DOWNTOWN_A | #9C5038 | downtown storefronts |
| BRICK_DOWNTOWN_B | #B0623F | orange-red downtown variant |
| BRICK_DOWNTOWN_C | #6E3A2C | dark downtown/paint-stripped |
| BRICK_PAINTED_WHITE | #E9E4D8 | painted brick (peeling reveals BRICK_DOWNTOWN_A) |
| BRICK_PAVER_A | #9A4F3A | sidewalk pavers |
| BRICK_PAVER_B | #8C4433 | sidewalk pavers, darker |
| MORTAR_HISTORIC | #CFC6B4 | lime mortar, campus |
| MORTAR_MODERN | #B9B5AC | portland mortar, downtown |
| EFFLORESCENCE | #E8E4DA | salt bloom overlay, max 15% opacity |

Brick jitter: value ±6%, hue ±3°, roughness 0.78–0.92.

### 4.2 Stone & Concrete
| Key | Hex | Use |
|---|---|---|
| FIELDSTONE_A | #8A8478 | gray fieldstone |
| FIELDSTONE_B | #6F6A60 | dark fieldstone |
| FIELDSTONE_C | #A39C8E | light fieldstone |
| FIELDSTONE_D | #7B6E5C | brown-iron-stained fieldstone |
| CAPSTONE | #9A958B | wall caps |
| GRANITE_CURB | #9E9E98 | campus curbs |
| LIMESTONE_TRIM | #D8D0BE | sills, keystones, column bases |
| MARBLE_WHITE | #ECE9E2 | library interiors, rotunda |
| CONCRETE_NEW | #BDB9B0 | new sidewalks, decks |
| CONCRETE_AGED | #A6A29A | old sidewalks |
| CONCRETE_BOARDFORM | #9C988F | brutalist library |
| MOSS | #4E5E2C | stone joints, north faces |
| LICHEN | #A9AE8C | stone surfaces, sparse |

### 4.3 Wood, Paint, Trim
| Key | Hex | Use |
|---|---|---|
| TRIM_WHITE | #F3F0E8 | window/door trim, cornices |
| TRIM_WHITE_AGED | #E6E0D2 | weathered trim |
| COLUMN_WHITE | #EFEBE1 | painted columns |
| SHUTTER_GREEN | #2F3F33 | campus shutters |
| SHUTTER_BLACK | #1E1F1F | downtown shutters |
| DOOR_RED | #6B1F1A | colonial doors |
| DOOR_BLACK | #18191A | colonial doors |
| DOOR_GREEN | #23382C | colonial doors |
| DOOR_HEAVENBLUE | #80B4D9 | school-spirit doors |
| BRASS | #B08D57 | hardware (metalness 1, roughness 0.35) |
| BRASS_WORN | #C9A86B | handle wear zones |
| OAK_FLOOR | #A47A4F | hardwood floors |
| HEART_PINE | #B5793E | historic floors |
| WALNUT_DARK | #4F3524 | wainscot, library millwork |

### 4.4 Roofs & Metal
| Key | Hex | Use |
|---|---|---|
| SLATE_A | #4B4F55 | slate roofs |
| SLATE_B | #5A5E63 | slate variation |
| COPPER_NEW | #B87333 | new flashing |
| COPPER_PATINA | #5E9C8C | domes, cupolas |
| STANDING_SEAM | #6C7378 | modern metal roofs |
| ASPHALT_SHINGLE | #3F3E3C | houses |
| TPO_ROOF | #D9D9D4 | flat commercial roofs |
| IRON_GREEN | #1F3A2E | fences, gates, lamp posts |
| IRON_BLACK | #1A1A1A | railings |
| GALV_STEEL | #8E9396 | HVAC, conduit, downspouts |
| ALUMINUM_STOREFRONT | #3A3C3E | dark-bronze storefront frames |

### 4.5 Ground, Roads, Markings
| Key | Hex | Use |
|---|---|---|
| ASPHALT_FRESH | #2E2F31 | new paving |
| ASPHALT_AGED | #4A4B4D | most roads |
| ASPHALT_PATCH | #3A3B3D | patches, crack seal |
| MARKING_WHITE | #EDEDE6 | lane lines, crosswalks |
| MARKING_YELLOW | #E8B923 | centerlines |
| BIKE_LANE_GREEN | #4F9A5A | bike lanes |
| CURB_PAINT_RED | #A8322A | no-parking curbs |
| RED_CLAY | #9B4A2C | NC clay, exposed soil |
| DIRT_PATH | #8A7B5E | worn shortcut paths |
| PINE_STRAW | #8C5A2B | mulch beds |
| GRASS_OCT | #5E7F3A | lawns, late October |
| GRASS_WORN | #7D8A4E | trampled quad grass |
| GRAVEL | #A39E93 | service yards |
| PUDDLE_TINT | #2A2C2E | rain puddles (high reflectance) |

### 4.6 Vegetation (late-October default)
| Key | Hex | Use |
|---|---|---|
| WILLOW_OAK_LEAF | #6B7A35 | blend toward #B08A2E for 30% of leaves |
| WHITE_OAK_LEAF | #8A5A2E | russet |
| RED_MAPLE_LEAF | #B23A26 | |
| SUGAR_MAPLE_LEAF | #D9822B | |
| DOGWOOD_LEAF | #8E2F2F | |
| GINKGO_LEAF | #E3C04D | |
| MAGNOLIA_LEAF | #2F4A2A | glossy, roughness 0.3 |
| LOBLOLLY_NEEDLE | #3E5A2F | |
| HOLLY_LEAF | #23402A | berries #B3201B |
| BOXWOOD | #3F5B2E | hedges |
| IVY | #31502A | campus walls |
| OAK_BARK | #5C5853 | |
| PINE_BARK | #5B4636 | |
| FALLEN_LEAF_MIX | #8A5A2E, #B08A2E, #6B4A2A | ground leaf litter |

### 4.7 School Identity & Signage
| Key | Hex | Use |
|---|---|---|
| HEAVEN_BLUE | #80B4D9 | ONSU primary |
| ONSU_NAVY | #142B4E | ONSU secondary |
| ONSU_WHITE | #FFFFFF | |
| EARL_BLUE | #0A2A8A | rival Earl University (posters, graffiti only) |
| SIGN_STREET_GREEN | #0B6B3A | street-name blades |
| SIGN_CAMPUS_NAVY | #142B4E | campus wayfinding |
| NEON_PINK | #FF4FA3 | bar neon |
| NEON_BLUE | #4FC3FF | bar neon |
| NEON_RED | #FF3B2F | "OPEN" signs |
| MARQUEE_BULB | #FFD27A | cinema bulbs |

### 4.8 Interior Finishes
| Key | Hex | Use |
|---|---|---|
| PLASTER_CAMPUS | #EFE8D8 | historic academic walls |
| PLASTER_IVORY | #F2EDE1 | inn, library |
| WAINSCOT_GREEN | #3E4E40 | historic halls, lower 110 cm |
| PAINT_DORM_BLOCK | #E9E6DD | painted CMU dorm walls |
| PAINT_OFFICE | #EDEDEA | modern offices |
| PAINT_HOSPITAL | #F4F5F2 | hospital walls |
| PAINT_HOSPITAL_ACCENT | #9CC7C2 | hospital wayfinding bands |
| PAINT_DINER | #D9E8E3 | diner walls |
| PAINT_BAR_DARK | #2B2422 | bars |
| PAINT_RETAIL | #F1EFEA | shops |
| CEILING_WHITE | #F7F7F4 | all ceilings |
| ACOUSTIC_TILE | #E8E6E0 | 61 × 61 cm grid, grid #DADAD6 |
| VCT_A / VCT_B | #D8D3C6 / #9E9A8F | checker vinyl floors (30.5 cm tiles) |
| TERRAZZO | #CFC8BA | flecks #8E8678, #F2EFE8, #6D6A63 |
| CARPET_INN | #5A2A2E | inn corridors |
| CARPET_OFFICE | #5F646A | offices |
| SEALED_CONCRETE | #9D9A93 | back-of-house, decks |
| TILE_WHITE_SUBWAY | #F4F2EC | 7.5 × 15 cm, grout #C9C6BF |
| HEX_TILE_WHITE | #F1F0EB | historic restrooms, grout #BDBAB2 |
| SPORTS_MAPLE | #D8B07A | arena court |
| RUBBER_FLOOR | #2F3133 | locker rooms, gyms |

### 4.9 Light Colors
| Key | Hex | Use |
|---|---|---|
| SUN_GOLDEN | #FFC98A | golden hour |
| SUN_NOON | #FFF4E5 | midday |
| SKY_GOLDEN_ZENITH | #7FA6CC | |
| SKY_GOLDEN_HORIZON | #F2C48D | |
| SKY_NIGHT | #0B1424 | |
| SKY_RAIN | #8D949B | |
| LAMP_SODIUM | #FFB765 | 2200 K, side streets |
| LAMP_LED | #EAF0FF | 4000 K, main streets/decks |
| LAMP_CAMPUS | #FFD9A8 | 2700 K, campus lanterns |
| INTERIOR_WARM | #FFD9A0 | shops, homes, inn |
| INTERIOR_COOL | #F2F6FF | offices, hospital, library stacks |

**Test:** `palette.test.ts` scans `/src` and fails if any hex literal appears outside `palette.ts`.

---

## 5. Centimeter Detail Standard

Anything within **15 m of a walkable surface** is modeled as real geometry at the dimensions below. Normal maps are only for 15–80 m.

### Masonry
- **Brick:** US modular 19.4 × 5.7 × 9.2 cm. Mortar joints 1.0 cm, recessed 0.4 cm (campus: concave; downtown: raked 0.6 cm). Chipped corners 0.2–0.8 cm on 12% of bricks.
- **Bonds:** Flemish bond on campus (alternating stretcher/glazed header); running bond downtown; 6-course common bond on side and rear walls; soldier courses over openings; rowlock sills.
- **Fieldstone walls:** individual stones 15–60 cm, mortar recess 2–4 cm, height 60–110 cm, width 45–60 cm, flat CAPSTONE caps 5–8 cm thick overhanging 2 cm. MOSS in north-facing joints.
- **Brick pavers:** 10 × 20 × 6 cm, herringbone (campus) or running bond (downtown), 0.3 cm sand joints. Tree roots heave pavers 2–6 cm within 3 m of trunks.

### Circulation
- **Exterior stairs:** risers 15–17 cm, treads 30–35 cm, 2.5 cm nosing. Old stone steps get 0.3–0.8 cm wear dips at center.
- **Interior stairs:** risers 17.8 cm max, treads 28 cm min, 2.5 cm nosing, landings ≥ stair width, width 112 cm (public) / 91 cm (residential).
- **Handrails:** 4 cm diameter, top at 86–97 cm, 4 cm wall clearance, 30 cm extensions at top and bottom.
- **Guardrails:** 107 cm high; balusters ≤ 10 cm clear spacing.
- **Ramps:** 1:12 max slope, 152 × 152 cm landings every 76 cm rise.
- **Curbs:** 15 cm high, 15 cm top, 2 cm chamfer. GRANITE_CURB on campus, CONCRETE_AGED downtown.
- **ADA curb ramps:** truncated-dome panel 61 cm deep, domes 2.3 cm base diameter, 0.5 cm high, 5.5 cm spacing, colored #B5873A.

### Openings
- **Exterior doors:** 91 × 213 cm standard, double doors 183 × 213 cm, historic doors 107 × 244 cm. Colonial 6-panel with 1.5 cm panel recess, frame 11 cm wide, 1.2 cm threshold, kick plate 25 cm, BRASS hardware with BRASS_WORN wear.
- **Interior doors:** 91 × 213 cm, 4.5 cm leaf, 2 cm-relief casing 9 cm wide. Every door is an openable, hinged object.
- **Historic windows:** double-hung 6-over-6, typical 91 × 183 cm. Muntins 2.2 cm, sash rails 5 cm, glass set back 10 cm from the brick face, stone sill projecting 4.5 cm, jack-arch or keystone lintel.
- **Modern windows:** fixed/awning, mullions 5 × 15 cm in ALUMINUM_STOREFRONT, glass set back 6 cm.
- **Storefronts:** 30–45 cm bulkhead, glass to 270 cm, 45–60 cm transom band, recessed entry 90–150 cm deep with tile floor.

### Ornament & Services
- **Ornament:** cornices modeled from profile curves; dentils 6 × 9 cm, spaced 12 cm; fluted columns with 24 flutes; quoins 30 × 20 cm alternating; keystones projecting 1.5 cm.
- **Rainwater:** gutters 13 cm K-style, downspouts 7.6 × 10 cm with straps every 180 cm, splash blocks.
- **Utility clutter (at least 4 per facade side):** gas meters, electric meters, hose bibs, conduit with straps, dryer vents, HVAC condensers with fins, security cameras, fire department connections, address numerals.

### Signage
- Raised channel letters 1–2 cm deep with 2.5 cm standoffs.
- Blade signs 60 × 90 cm on IRON_BLACK brackets.
- Street-name blades 15 × 76 cm SIGN_STREET_GREEN with MARKING_WHITE letters.

---

## 6. Modular Kit Catalog

Every kit piece is a TypeScript function returning geometry from cm dimensions, snapping to the 1 cm grid, with pivot at bottom-front-left. Write a unit test for every piece's bounding box (±0.5 cm).

| Kit | Pieces |
|---|---|
| Brick wall | straight, corner (in/out), opening frame, soldier course, rowlock sill, jack arch, segmental arch, pilaster, chimney stack |
| Stone wall | straight, curve (radius param), end post, gate pier 60 × 60 × 150 cm with cap |
| Window | 6/6 double-hung, 9/9, 2/2, arched fanlight, oculus, dormer, modern fixed, storefront bay, transom, basement hopper |
| Door | colonial 6-panel, double colonial with fanlight, storefront glass, service steel, garage roll-up, interior panel, interior glass |
| Cornice | box cornice, dentil cornice, bracketed Italianate, modern parapet coping |
| Column | Doric, Ionic, square pier, cast-iron storefront column |
| Stair | straight, L, U, spiral (tower), exterior stoop, stadium aisle steps |
| Railing | iron picket, wood colonial balustrade, glass modern, pipe rail |
| Roof | gable, hip, gambrel, flat with parapet, dome (radius param), cupola, belfry |
| Storefront | 1-bay, 2-bay, 3-bay, corner-entry, recessed entry |
| Awning | fabric shed (color param), fabric dome, metal canopy |
| Curb/sidewalk | straight, corner radius, ramp, driveway apron, tree pit with grate 120 × 120 cm |
| Interior | partition, door opening, corridor segment, stair core, elevator shaft, restroom block, ceiling grid |

---

## 7. INTERIOR STANDARD — every building, hollow, items later

**Rule:** every building in the city, landmark or generic, has a fully modeled architectural interior on **every floor**, including basements and attics where the building type has them.

**Interiors include only architecture and permanent built-ins:**
- floors, ceilings, exterior wall inner faces, interior partitions
- door openings with working doors; windows (glass visible from inside)
- stairs, landings, railings; elevator shafts (empty, doors on each floor); ramps
- columns, beams, fireplaces and mantels, built-in niches, wainscoting, crown molding, baseboards
- **Built-ins that define circulation:** service counters, bar counters, stage platforms, fixed seating tiers (stadium, arena, cinema, planetarium) as stepped platforms — **no individual seats**, which are items later
- restroom rooms with stall partitions omitted (items later)
- ceiling light panels as emissive surfaces (fixtures are items later)

**Exclude (items pass, later):** furniture, seats, fixtures, appliances, plumbing fixtures, shelving, books, décor, signage inside rooms, people, vehicles.

### 7.1 Construction Dimensions
| Element | Dimension |
|---|---|
| Historic masonry exterior wall | 45 cm (ground), 35 cm (upper) |
| Modern exterior wall (veneer + stud + drywall) | 30 cm |
| Interior partition | 12 cm |
| Fire/party wall | 20 cm |
| Floor slab / floor assembly | 30 cm (modern), 35 cm (historic timber) |
| Elevator shaft | 213 × 203 cm interior, doors 107 × 213 cm |
| Corridor width | 183 cm (academic), 152 cm (residential), 244 cm (hospital) |

### 7.2 Floor-to-Floor Heights
| Building type | Ground | Upper |
|---|---|---|
| Historic academic | 480 cm | 420 cm |
| Downtown commercial | 450 cm | 330 cm (offices/apartments above) |
| Residence hall (historic) | 360 cm | 340 cm |
| Residence hall (high-rise) | 300 cm | 290 cm |
| Modern office/lab | 420 cm | 400 cm |
| Hospital | 480 cm | 430 cm |
| House | 290 cm | 275 cm |
| Parking deck | 330 cm | 300 cm (sloped ramps 5% max) |

Ceiling height = floor-to-floor − slab − 60 cm plenum (modern) or − slab only (historic, exposed ceilings).

### 7.3 Floor Plans
- Generate floor plans procedurally per typology (`floorplan.ts`): double-loaded corridor, single-loaded corridor, open plan + core, shotgun commercial, center-hall house, atrium.
- Landmarks get hand-authored plans (Section 10).
- Every plan must pass these tests:
  - every room reachable from an exterior door
  - every floor reachable by stairs
  - buildings of 3+ floors (and every public building) have an elevator
  - no door opens into a stair landing's walking path
  - two exits per floor for buildings over 2 floors

### 7.4 Room Metadata (for the later items pass)
Every room is a named `Object3D` (`CM_{BuildingId}_F{floor}_R{index}`) with `userData`:
```ts
{
  roomId: string, buildingId: string, floor: number,
  roomType: 'office'|'classroom'|'lecture'|'dorm_double'|'dorm_single'|'corridor'|'stair'|'restroom'|
            'lobby'|'retail_floor'|'stockroom'|'kitchen'|'dining'|'bar'|'reading_room'|'stacks'|
            'ward'|'exam'|'or'|'mechanical'|'storage'|'apartment_living'|'apartment_bed'|'locker'|
            'auditorium'|'chapel'|'ballroom'|'guest_room'|'parking'|... ,
  areaM2: number, ceilingCm: number,
  floorFinish: PaletteKey, wallFinish: PaletteKey, ceilingFinish: PaletteKey,
  lightingKey: 'INTERIOR_WARM'|'INTERIOR_COOL',
  itemSlots: [],                // empty array; filled in items pass
  anchorWalls: [{ start, end, normal }],   // usable wall runs for future furniture
  openings: [{ type: 'door'|'window', position, widthCm }]
}
```
Also export all rooms to `data/rooms.json`.

### 7.5 Interior Finish Rules by Building Type
| Type | Walls | Floor | Ceiling |
|---|---|---|---|
| Historic academic | PLASTER_CAMPUS over WAINSCOT_GREEN (lower 110 cm), crown molding 15 cm | HEART_PINE (classrooms), TERRAZZO (halls) | CEILING_WHITE plaster |
| Modern academic | PAINT_OFFICE | VCT_A/VCT_B or CARPET_OFFICE | ACOUSTIC_TILE |
| Residence hall | PAINT_DORM_BLOCK (CMU coursing 20 × 40 cm visible) | VCT_A | CEILING_WHITE |
| Downtown retail | PAINT_RETAIL, exposed brick on party walls | OAK_FLOOR | pressed-tin pattern (relief 0.6 cm) in pre-1940 shops, CEILING_WHITE |
| Bar | PAINT_BAR_DARK, exposed brick | SEALED_CONCRETE or OAK_FLOOR | exposed joists |
| Diner | PAINT_DINER | VCT checker | CEILING_WHITE |
| Hospital | PAINT_HOSPITAL with PAINT_HOSPITAL_ACCENT band at 100–115 cm | TERRAZZO (lobby), sheet vinyl #DCDAD2 (wards) | ACOUSTIC_TILE |
| Inn | PLASTER_IVORY, WALNUT_DARK wainscot | CARPET_INN (corridors), OAK_FLOOR (rooms) | CEILING_WHITE with crown |
| Library | PLASTER_IVORY, WALNUT_DARK millwork | MARBLE_WHITE (rotunda), CARPET_OFFICE (stacks) | coffered plaster |
| Restrooms (all) | TILE_WHITE_SUBWAY to 150 cm | HEX_TILE_WHITE (historic) / porcelain #CFCBC2 (modern) | CEILING_WHITE |
| Back-of-house | SEALED_CONCRETE walls painted #DCD9D2 | SEALED_CONCRETE | exposed |

### 7.6 Interior Performance
- Interiors stream per building: load when the player is within **35 m** of any door, or inside.
- Beyond that, windows use an **interior-mapping shader** (fake rooms with correct floor heights, wall colors from the building's finish rules, and lit/unlit states) so the city never looks hollow from outside.
- Per-building portal culling: rooms are only rendered if visible through doors or windows from the player's current room.

---

## 8. Terrain

- **Hamilton Ridge:** main street runs east–west along a ridge at elevation 0.
- **North of the ridge:** the land falls gently (−8 m over 400 m) into residential blocks.
- **South of the ridge:** campus slopes down. North Quad ≈ −2 m, Founders' Quad ≈ −6 m, Carillon Hill drops to the stadium bowl floor at **−28 m**.
- **Battle Ravine:** runs through the east side. Creek bed −18 m, steep wooded slopes, stone footbridge, exposed RED_CLAY banks.
- **Carrburg (west):** lower and flatter at −12 m, with a rail line on a 1.5 m embankment.
- **Resolution:** heightfield at 0.5 m resolution in the core. Roads and sidewalks cut and flatten the terrain with 2% cross-slopes.
- **Grass:** instanced blades within 25 m of the camera; GRASS_OCT base and GRASS_WORN desire paths across quads. Leaf litter (FALLEN_LEAF_MIX) is densest under oaks.

---

## 9. Districts

### 9.1 Hamilton Strip (Franklin St inspiration)
- **Street:** ~800 m long, 2 travel lanes + parallel parking both sides. Lanes 330 cm, parking 244 cm, sidewalks 450–600 cm of BRICK_PAVER. Mid-block crosswalks in ladder pattern (bars 60 cm wide, 60 cm gaps).
- **North side:** continuous 2–4 story storefront blocks; 2–3 newer 6–9 story mixed-use buildings set back above a 3-story base.
- **South side:** the first 300 m east of The Summit faces the ONSU North Quad stone wall and oaks; storefronts resume further east and west.
- **Alleys:** at least 3 invented alleys (3.5–6 m wide) with back doors, dumpster courts (dumpsters are items later; leave pads), murals, fire escapes, and stairs to second-floor bars.
- **Upper floors:** every storefront building's upper floors are interior apartments or offices.

### 9.2 The Summit
- The Hamilton × Columbia intersection: 4-way signal, scramble crosswalk, corner bank (BRICK_DOWNTOWN_C, limestone base), and **Top of the Mount** with its rooftop deck.
- Columbia St climbs 6 m from the south toward this intersection.

### 9.3 Rosemary Row
- One block north, parallel to Hamilton St.
- Two parking decks (5 levels, CONCRETE_NEW, LAMP_LED), late-night food stalls, 4–5 story apartment blocks over shops.
- Grittier: more ASPHALT_PATCH, graffiti, back entrances.

### 9.4 ONSU North Quad (McCorkle Place inspiration)
- Long lawn running north–south, bounded by the fieldstone wall on Hamilton St.
- Brick paths in herringbone and 30–40 giant willow oaks (25–30 m tall, canopy 25 m).
- **Buildings:** Elder East, Elder West, Wilberforce Library, the Old Cistern at the south end, plus 3 historic academic halls.

### 9.5 ONSU Founders' Quad (Polk Place inspiration)
- Rectangular lawn ≈ 110 × 220 m (compressed).
- **North end:** Founders' Hall. **South end:** a domed library facing it.
- **Sides:** 6 academic halls in Flemish bond.
- Crisscrossing brick paths with GRASS_WORN shortcut lines.

### 9.6 The Quarry
- Sunken brick plaza 2.5 m below grade with stepped seating walls.
- Student union (modern brick + glass, 4 floors) and dining hall (2 floors).
- Brutalist Davies Stacks on the west edge.

### 9.7 Carillon Hill & South Campus
- The Carillon Spire on a terraced lawn stepping down to Benefactor Stadium.
- 4 high-rise residence halls (9–11 floors), the Coach's Dome arena, recreation center, parking deck.

### 9.8 ONSU Medical Center
- 4 towers (8–12 floors) connected by glass skybridges at floor 3.
- ER bay with canopy, helipad on the tallest tower roof, 2 parking decks.
- Interiors follow the hospital finish rules; typical floors can share a plan but must still be fully modeled.

### 9.9 Carrburg (Carrboro inspiration)
- Converted brick textile mill (3 floors, 140 m long, sawtooth roof) with a co-op market inside.
- Train tracks, a town commons lawn, colorful one-story storefronts.
- **Painted storefront colors:** #C7522A, #E0B341, #4C7A8C, #7E9C5B, #B8577A.

### 9.10 Toadstool Hill (Gimghoul inspiration)
- Wooded winding lanes with stone and stucco houses (all with interiors) and Ghoulgrave Keep at the end.
- Heavy loblolly pine and holly; darker, quieter, LAMP_CAMPUS lanterns only.

### 9.11 Residential North
- Grid of 1–2 story houses and porches; old bungalows in #E9E4D8, #9DB0A3, #D4C59A, #8A9BB0 siding with TRIM_WHITE.
- Brick ranches in BRICK_DOWNTOWN_B.
- Every house has a full interior.

### 9.12 Outer Ring (low detail)
- Pine forest, a 4-lane bypass highway, distant suburban roofs.
- Skyline impostor of rival **Steer City / Earl University** (Gothic stone tower silhouette) to the east.
- No interiors are required in the outer ring; it is not enterable.

---

## 10. Landmark Hero Assets (LOD-max, hand-authored)

Each is an original design inspired by the real building. Each lives in its own file in `buildings/landmarks/` with a hand-authored floor plan, fully modeled exterior, and full hollow interior.

1. **The Old Cistern** — Open rotunda: 8 COLUMN_WHITE Doric columns on a circular stone platform (3 steps), COPPER_PATINA dome topped by a finial. Center: well curb (built-in) with a 4 m-deep hollow shaft beneath. No enclosed interior.
2. **The Carillon Spire** — Square brick tower, ~52 m, with limestone corners and a copper-roofed belfry. Interior: spiral and switchback stairs to the top, intermediate landings, a ringing room, and a bell chamber with timber bell frame (bells are items later). Louvered openings.
3. **Wilberforce Library** — Classical temple front, 6 Ionic columns, central dome in COPPER_PATINA. Interior: MARBLE_WHITE rotunda reading room with coffered dome, two stack wings over 3 floors, a basement special-collections vault, and staff stairs.
4. **Davies Stacks** — Brutalist, 8 floors, CONCRETE_BOARDFORM (boards 15 cm wide, 1 cm seams, wood-grain relief 0.2 cm). Interior: central atrium, 7 floors of open stack plates, study-room rings, two stair cores, 4 elevators.
5. **Founders' Hall** — Georgian, 3 floors, columned portico, cupola. Interior: central stair hall with a curved staircase, double-loaded office floors, attic.
6. **Elder East / Elder West** — Oldest dormitories, 4 floors, BRICK_CAMPUS_C with stucco end walls. Interior: double-loaded corridors, dorm doubles (3.4 × 4.6 m), floor restrooms, end stairs.
7. **Moorhouse Observatory** — Brick building with a 20 m COPPER_PATINA dome and a sundial garden. Interior: lobby rotunda, a dome theater with stepped seating tiers (platforms only), offices, and a rooftop observation deck.
8. **Founders' Quad library** — Domed, faces Founders' Hall. Interior: 2-floor reading room, stacks.
9. **Student Union & Dining Hall** — Modern brick + glass. Interiors: food-court counters (built-in shells), ballroom, offices, kitchen.
10. **Benefactor Memorial Stadium** — Bowl set into the hillside, lower bowl + upper deck on the home side, BRICK_CAMPUS_A façade. Interior: concourse ring, concession counters, locker rooms, tunnel, press box (4 floors), suites corridor. Field turf #3D7A3A with MARKING_WHITE lines; end zones HEAVEN_BLUE with ONSU_NAVY lettering.
11. **The Coach's Dome** — Round arena with a 120 m-diameter dome, white membrane roof #E4E6E6 over a HEAVEN_BLUE ring band. Interior: concourse ring, seating bowl tiers, SPORTS_MAPLE court with the parody center logo, locker rooms, practice gym, banners zone (items later).
12. **Pamlico Inn** — Colonial hotel, 3–4 floors, deep columned porch, cupola. Interior: lobby, front-desk counter, ballroom (14 × 28 m), restaurant, kitchen, 4 floors of guest rooms (each with bath).
13. **ONSU Medical Center towers** — See 9.8.
14. **Ghoulgrave Keep** — Fieldstone mini-castle: square tower plus great hall. Interior: great hall with fireplace, tower spiral stair, cellar, parapet walk.
15. **Grove Amphitheatre** — Stone-terraced outdoor theater in a ravine. Fieldstone tiers, stage, and a small stone backstage building with interior.

---

## 11. Hamilton Strip Business Roster (parody; exterior colors exact)

| Business | Type | Facade / Awning / Sign colors | Interior notes |
|---|---|---|---|
| Sutter's Pharmacy & Grill | diner + pharmacy | BRICK_DOWNTOWN_A, awning #1F4E79, sign MARKING_WHITE | long built-in counter, kitchen, basement |
| Top of the Mount | brewpub | BRICK_DOWNTOWN_C, sign #C9A86B on #18191A | 2 floors + rooftop deck, bar counters, brewhouse room |
| Junior Varsity Cinema | cinema | facade #7A2E2E, marquee #18191A with MARQUEE_BULB | lobby, concession counter, 2 auditoriums with raked platforms, projection booth |
| Pamlico Coffee House | café | BRICK_DOWNTOWN_B, awning #3E2A1E, sign #E6D3A3 | counter, basement seating room |
| Old North Outfitters | ONSU spirit shop | facade HEAVEN_BLUE, sign ONSU_NAVY | retail floor, mezzanine, stockroom |
| Tarry Page Books | bookstore | facade SHUTTER_GREEN, sign #E6D3A3 | 2 floors, stair, stockroom |
| Mount Pizza Co. | pizza | BRICK_PAINTED_WHITE, awning #A8322A | counter, oven alcove, kitchen |
| The Grinding Stone | dive bar | BRICK_DOWNTOWN_C, NEON_PINK + NEON_BLUE | bar counter, back room, upstairs pool room |
| Ye Olde Waffle Hutch | breakfast | facade #E0B341, awning #7A2E2E | counter, kitchen |
| Late Night Lo Mein | takeout | facade #A8322A, sign #E8B923 | counter, kitchen |
| Hamilton Records | vinyl shop | facade #2B2422, sign #FF4FA3 | retail floor, listening room |
| Bluebird Savings Bank | bank | LIMESTONE_TRIM facade, sign #142B4E | banking hall, teller counter, vault room |
| Jolly Molar Dental | dentist (2nd floor) | ground-floor door #6B1F1A | reception, 4 operatories |
| Hilltop Hardware | hardware store | BRICK_DOWNTOWN_A, awning #2F3F33 | retail floor, basement stock |
| Linen & Lamb | clothing | BRICK_PAINTED_WHITE, awning #B5A68A | retail floor, fitting rooms |
| Cosmic Carnitas | tacos | facade #4C7A8C, sign #E8B923 | counter, kitchen, patio |
| Cram Fortress Tutoring | tutoring (2nd floor) | door #142B4E | classrooms |
| Pitch Soles Tattoo | tattoo | facade #1A1A1A, sign NEON_RED | studio rooms |

Fill remaining storefronts with generated businesses following the same pattern. Every generated business needs a parody name, a palette-only color set, and a typed interior.

---

## 12. Vegetation

- **Willow oak** (dominant on campus): 22–30 m tall, 1–1.4 m trunk diameter. Trunk and primary branches are modeled geometry; foliage uses instanced leaf cards.
- **Other trees:**
  - white oak, red maple, sugar maple (downtown street trees, 8–12 m, in 120 × 120 cm grated tree pits)
  - dogwood (understory), magnolia (campus edges)
  - loblolly pine (stadium bowl, Toadstool Hill, outer ring, 20–30 m)
  - ginkgo (2–3 accent trees on campus)
- **Shrubs:** boxwood hedges 60–120 cm, holly, azalea #4A6B3A (no blooms in October).
- **Ivy:** IVY on 20% of campus building walls, north faces preferred; individual leaves within 10 m.
- **Mulch beds:** PINE_STRAW.

---

## 13. Street Furniture (exterior permanent; modeled now)

- **Lamp posts:** campus lanterns — IRON_GREEN, 3.7 m, LAMP_CAMPUS. Downtown acorn lamps — IRON_BLACK, 4.3 m, LAMP_LED.
- **Traffic signals:** mast arms in GALV_STEEL, heads in #2B2B2B with yellow backplates #E8B923 rimmed in retroreflective white.
- **Benches:** IRON_GREEN frames, slats #8A6A48, 183 cm long, seat height 45 cm.
- **Other furniture:**
  - bike racks (inverted-U, GALV_STEEL)
  - fire hydrants (#C9302C body, #E6E3DA caps)
  - bus shelters (glass + #142B4E frame, route map panels)
  - newspaper boxes (#1F4E79, #A8322A)
  - trash/recycling cans (IRON_BLACK / #1F4E79)
  - bollards, parking meters (GALV_STEEL), manhole covers with cast parody seals ("CITY OF CATHEDRAL MOUNT — 1819")
- Benches, lamps, signals, hydrants, and covers are **part of this build**. Loose movable items (bikes, cars, café chairs, trash bags) are **items later**.

---

## 14. Parody, Signage & Text Rules

- **No real logos, trademarks, brand names, or real business names anywhere.** Everything is an original parody with the same vibe and an original mark.
- **School:** Old North State University (ONSU), "Pitch Soles," mascot is an original ram-goat hybrid called **the Billram** (design it as an original character). Rival: **Earl University** in **Steer City**.
- **Fonts:** open-licensed only (e.g. Libre Baskerville, Playfair Display, Oswald, Bebas Neue, Pacifico, Roboto Slab), bundled in `/public/fonts`.
- **Posters, flyers, graffiti:** generated in a satirical GTA tone (student elections, fake concerts, lost-cat flyers, tutoring ads, Earl University insults). No real people, no real organizations.
- **Street names:** Hamilton St, Columbia St, Rosemary St, Cameron Ave, Founders Rd, Raleigh Pike, Merritt Mill Rd → **Miller's Run Rd**, Manning Dr → **Manor Dr**, plus invented alleys (Tanner's Alley, Inkwell Lane, Blue Lantern Way).
- Store every name in `data/parody-names.json` as `{ real_inspiration, parody_name, type, district }`.

---

## 15. Lighting & Weather Presets

| Preset | Sun elevation / azimuth | Sun color | Sky | Notes |
|---|---|---|---|---|
| **Golden Hour (default)** | 8° / 250° | SUN_GOLDEN, intensity 2.2 | gradient SKY_GOLDEN_ZENITH → SKY_GOLDEN_HORIZON | long shadows across quads, warm brick |
| Midday | 55° / 180° | SUN_NOON, 3.0 | #8FB8DE → #D6E6F2 | |
| Night | moon 30° / 120°, #AFC4E8, 0.15 | — | SKY_NIGHT | all LAMP_* and storefront INTERIOR_WARM emissives on; 60% of windows lit |
| Rain | overcast | — | SKY_RAIN | wet materials (roughness −0.35, darken 15%), puddles in paver depressions, drip lines under cornices, rain particles |

- Shadows: cascaded shadow maps (4 cascades) plus contact shadows for cm-level detail.
- Ambient occlusion: SSAO/GTAO tuned so mortar joints read at 1 m distance.
- Tone mapping: ACES Filmic, exposure 1.0; sRGB output.

---

## 16. Player, Tools & Debug

- **Controls:** first-person walk (WASD + mouse, pointer lock, eye height 165 cm, walk 1.4 m/s, run 4 m/s, step-up 20 cm max, capsule radius 30 cm) and free-fly mode (F key).
- **Doors:** E to open/close every door, animated on hinges.
- **Collision:** simplified per-building collision meshes, including interiors and stairs.
- **Minimap:** GTA-style top-right minimap with district names; full map screen (M) with landmark icons.
- **Debug tools (toggle with backtick):**
  - **Measure tool** — click two points, shows distance in cm (used for QA)
  - wireframe toggle, room labels (roomType + area), palette key under cursor
  - FPS/draw-call/triangle HUD, tile boundaries, interior streaming radius

---

## 17. Performance Budgets (target: 60 fps on a mid-range laptop GPU at 1080p)

- ≤ 2,500 draw calls visible.
- ≤ 8 M triangles visible, with heavy instancing.
- Full cm geometry within 15 m; simplified + normal-mapped at 15–80 m; impostors/merged blocks beyond 80 m.
- Interiors load only within 35 m of a door (Section 7.6).
- Tiles load in a 3 × 3 ring around the player; prefetch the next ring.
- Generated geometry is cached in IndexedDB after first build.

---

## 18. Workflow — report after each phase, then WAIT for approval

1. **Concept map:** top-down layout with districts, streets, landmarks, elevations. List every compression and invention relative to real Chapel Hill.
2. **Scaffold:** Vite + Three.js + TS project, `units.ts`, `palette.ts` + test, seeded RNG, tile system, player controls, debug tools.
3. **Terrain & roads:** heightfield, ravine, road network, curbs, sidewalks, markings, crosswalks.
4. **Kits:** every kit in Section 6, with unit tests for dimensions. Deliver a kit gallery scene.
5. **Interior system:** floor plan generator, room metadata, stairs/shafts, interior streaming, interior-mapping shader. Prove it on 3 generic buildings.
6. **Landmarks:** Old Cistern → Carillon Spire → Founders' Hall → Wilberforce Library → the rest, each with full interior.
7. **Hamilton Strip:** storefronts, upper floors, alleys, Section 11 businesses, all interiors.
8. **Remaining districts** (9.3–9.12), all interiors.
9. **Vegetation & street furniture.**
10. **Signage, posters, graffiti.**
11. **Lighting presets, rain, performance pass.**
12. **Export:** glTF per tile and per landmark via GLTFExporter.

**Every phase report includes Playwright screenshots in `/screenshots/phase-N/`:**
- overhead orthographic of the work area
- 3 street-level views
- 1 macro close-up ≤ 30 cm from a surface (proves cm detail)
- 1 interior view (from phase 5 on)

It also includes test results and a list of known issues.

---

## 19. Automated Tests (must pass before each phase report)

- **Kit dimensions:** bounding boxes within ±0.5 cm of spec.
- **Stairs:** risers ≤ 17.8 cm interior, treads ≥ 28 cm.
- **Doors:** every exterior and interior door ≥ 91 × 213 cm clear (except historic exceptions logged).
- **Palette:** no hex literals outside `palette.ts`.
- **Interiors:**
  - every building has ≥ 1 room per floor
  - every room reachable from an exterior door
  - all floors reachable by stairs
  - elevators where required
  - every room has `itemSlots: []`
- **Parody:** a list of real trademark/business names is checked against all generated text; any match fails.

---

## 20. Deliverables

- Running web app (`npm run dev`), walkable city.
- `/data`: buildings.json, rooms.json, parody-names.json, palette.json.
- `/screenshots` per phase; `/export` glTF.
- `README.md`: controls, debug keys, architecture overview, how to add items later using `rooms.json` + `itemSlots`.
- **City map image:** illustrated GTA-style map of Cathedral Mount with district and landmark labels, rendered from the overhead camera with stylized overlays.

---

## 21. First Action

Read this whole file. Then:
1. Restate the plan in under 15 bullet points.
2. List anything ambiguous.
3. Produce Phase 1 (concept map + compression/invention list).
4. **Stop and wait for my approval** before writing scaffold code.

---

## Project log
- Phase 1 (concept map) delivered: `docs/phase-1/PHASE-1-CONCEPT.md`, `docs/phase-1/concept-layout.json`, `screenshots/phase-1/concept-map.png`.
- User approved continuing through all phases without approval stops.
- Phases 2–6: scaffold, terrain/roads, kits + gallery, interior system, all 15 landmarks (screenshots in `screenshots/phase-2..6`).
- Phases 7–10: Hamilton Strip roster + generated businesses, all districts (705 buildings, every plan valid), vegetation, street furniture, signage/parody (2,107 strings checked).
- Phase 11 (in progress): rain (streaks, eave drips, puddles, sky env reflections) wired; performance pass pending real-GPU numbers.
- Phase 12: `npm run export` (map GLB + labels), `npm run export:gltf` (per-landmark / per-tile full-detail GLB, git-ignored); data in `/data`; README; city map via `tools/city-map/render.cjs` → `screenshots/city-map.png`.
- Pushing to GitHub fails with 403 (Claude GitHub App lacks access to the repo); commits are local on `claude/cathedral-mount-world-75m8a6`.
