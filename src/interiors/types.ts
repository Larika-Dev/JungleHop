// Interior plan data model (CLAUDE.md §7). All plan dimensions are integer cm in BUILDING-LOCAL space:
// origin = front-left exterior corner at ground-floor finished floor level (FFL), +x along the frontage
// (left -> right seen from the street), +z into the building (front facade lies on z = 0, facing −z), +y up.
import type { PaletteKey } from '../core/palette';
import type { DistrictId } from '../world/layout';

export type RoomType =
  | 'office' | 'classroom' | 'lecture' | 'dorm_double' | 'dorm_single' | 'corridor' | 'stair' | 'restroom' | 'lobby'
  | 'retail_floor' | 'stockroom' | 'kitchen' | 'dining' | 'bar' | 'reading_room' | 'stacks' | 'ward' | 'exam' | 'or'
  | 'mechanical' | 'storage' | 'apartment_living' | 'apartment_bed' | 'apartment_kitchen' | 'apartment_bath' | 'locker'
  | 'auditorium' | 'chapel' | 'ballroom' | 'guest_room' | 'guest_bath' | 'parking' | 'elevator_lobby' | 'attic' | 'hall'
  | 'living' | 'bedroom' | 'bath' | 'study' | 'vault' | 'booth' | 'court' | 'concourse' | 'suite' | 'press_box' | 'gallery'
  | 'nurse_station' | 'cafe' | 'theater' | 'brewhouse' | 'banking_hall' | 'operatory' | 'reception' | 'fitting_room'
  | 'listening_room' | 'studio' | 'projection' | 'ringing_room' | 'bell_chamber' | 'great_hall' | 'cellar' | 'backstage'
  | 'food_court' | 'gym' | 'deck' | 'dressing' | 'laundry' | 'pool_room' | 'back_room';

export type Typology =
  | 'historic_academic' | 'modern_academic' | 'residence_historic' | 'residence_highrise' | 'downtown_commercial'
  | 'office_lab' | 'hospital' | 'house' | 'parking' | 'inn' | 'library' | 'bar' | 'diner' | 'retail' | 'mill' | 'arena';

export type PlanKind = 'double_loaded' | 'single_loaded' | 'open_core' | 'shotgun' | 'center_hall' | 'atrium' | 'parking' | 'custom';

export interface Rect { x0: number; z0: number; x1: number; z1: number; }
export interface Finish { floor: string; wall: string; ceiling: string; wallKey: PaletteKey; floorKey: PaletteKey; ceilingKey: PaletteKey; lighting: 'INTERIOR_WARM' | 'INTERIOR_COOL'; wainscot?: string; wainscotH?: number; tileH?: number; crown?: boolean; suspended?: boolean; band?: string; }

export interface Room { id: string; idx: number; floor: number; /** finished (wall-face) rect */ rect: Rect; /** centerline rect (floors/ceilings span this) */ cl: Rect; type: RoomType; label?: string; finish: Finish; }

export interface Opening {
  /** cm from wall start (a) to the opening's left edge */
  at: number; w: number; h: number; sill: number;
  kind: 'door' | 'window' | 'arch';
  /** DoorSystem style id (kits/door.ts doorStyleBuilder) */
  style?: string;
  /** +1: leaf swings toward the wall's left normal side; −1 the other side */
  swing?: 1 | -1;
}
export interface WallSeg {
  floor: number; ax: number; az: number; bx: number; bz: number; t: number;
  kind: 'ext' | 'part' | 'fire' | 'glass';
  openings: Opening[];
}
export interface StairRec { id: string; floor: number; toFloor: number; rect: Rect; kind: 'U' | 'straight' | 'spiral'; w: number; /** direction the first flight rises toward */ dir: 'z+' | 'z-' | 'x+' | 'x-'; rise: number; }
export interface ShaftRec { rect: Rect; floors: number[]; door: 'z0' | 'z1' | 'x0' | 'x1'; }
export interface FloorPlan { floor: number; y: number; ftf: number; slab: number; ceiling: number; extT: number; rooms: Room[]; walls: WallSeg[]; holes: Rect[]; /** ceiling cut-outs (rotundas/atria open above) */ openCeiling?: Rect[]; }
export interface ExtDoor { floor: number; side: 'front' | 'back' | 'left' | 'right'; at: number; w: number; h: number; style: string; y: number; }
export interface WindowRec { floor: number; side: 'front' | 'back' | 'left' | 'right'; at: number; w: number; h: number; sill: number; type: WindowType; }
export type WindowType = '6/6' | '9/9' | '2/2' | 'modern' | 'storefront' | 'hopper' | 'arched' | 'oculus' | 'none';

export interface FacadeSpec {
  wall: string; // material key (brick:... / tex:stucco / paint:SIDING_*)
  backWall?: string; // rear/side walls (6-course common bond)
  sideWall?: string; // left/right walls when different (e.g. stucco end walls)
  trim: string;
  window: WindowType;
  winW: number; winH: number; bay: number; // cm
  cornice: 'box' | 'dentil' | 'italianate' | 'coping' | 'none';
  roof: 'flat' | 'gable' | 'hip' | 'gambrel' | 'none';
  roofKey: string; pitch?: number;
  shutters?: string | null;
  storefront?: { bays: 1 | 2 | 3; entry: 'center' | 'left' | 'right' | 'corner'; frame?: string; bulk?: string; awning?: { kind: 'shed' | 'dome' | 'canopy'; color: string; stripe?: string } | null; signBand?: string };
  doorStyle: string; // exterior door style id
  lintel?: 'keystone' | 'flat' | 'jack' | 'soldier' | 'none';
  quoins?: boolean;
  basementWindows?: boolean;
  parapetH?: number;
  stoop?: boolean;
}

export interface BusinessInfo { name: string; type: string; sign?: PaletteKey; signBg?: PaletteKey; facade?: string; awning?: string; real?: string; }

export interface BuildingSpec {
  id: string;
  name?: string;
  district: DistrictId;
  /** world plan position of the local origin (front-left corner) and rotation (radians about +Y) */
  x: number; z: number; rotY: number;
  /** ground floor FFL (world y, m) */
  y: number;
  w: number; d: number; // cm
  floors: number; basement: boolean; attic: boolean;
  typology: Typology; plan: PlanKind;
  facade: FacadeSpec;
  /** shared (party) walls: left/right sides abut neighbours — no windows there */
  party?: { left?: boolean; right?: boolean };
  business?: BusinessInfo;
  upperUse?: 'apartments' | 'offices';
  public?: boolean;
  /** custom plan builder for landmarks */
  custom?: string;
  seed: string;
  tags?: string[];
}

export interface Plan {
  spec: BuildingSpec;
  floors: FloorPlan[]; // index 0 = lowest (basement if present)
  stairs: StairRec[];
  shafts: ShaftRec[];
  extDoors: ExtDoor[];
  windows: WindowRec[];
  /** elevated roof base (cm above FFL of floor 0 / ground) */
  roofY: number;
  /** wall-less connections between rooms (open plan, lobbies) */
  links: [string, string][];
}
