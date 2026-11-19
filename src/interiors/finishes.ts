// Construction dimensions (§7.1), floor-to-floor heights (§7.2) and interior finish rules (§7.5).
import type { Finish, RoomType, Typology } from './types';

export const WALL = { histGround: 45, histUpper: 35, modern: 30, partition: 12, fire: 20 } as const;
export const SLAB = { modern: 30, historic: 35 } as const;
export const CORRIDOR = { academic: 183, residential: 152, hospital: 244 } as const;
export const SHAFT = { w: 213, d: 203, doorW: 107, doorH: 213 } as const;

export const FTF: Record<Typology, [number, number]> = {
  historic_academic: [480, 420], modern_academic: [420, 400], residence_historic: [360, 340], residence_highrise: [300, 290],
  downtown_commercial: [450, 330], office_lab: [420, 400], hospital: [480, 430], house: [290, 275], parking: [330, 300],
  inn: [450, 340], library: [480, 420], bar: [450, 330], diner: [450, 330], retail: [450, 330], mill: [480, 420], arena: [600, 450],
};
export const isHistoric = (t: Typology) => ['historic_academic', 'residence_historic', 'house', 'inn', 'library', 'mill', 'downtown_commercial', 'bar', 'diner', 'retail'].includes(t);
export const extWallT = (t: Typology, floor: number) => (isHistoric(t) ? (floor <= 0 ? WALL.histGround : WALL.histUpper) : WALL.modern);
export const slabT = (t: Typology) => (isHistoric(t) && t !== 'downtown_commercial' ? SLAB.historic : SLAB.modern);
/** modern = suspended ceiling with 60 cm plenum; historic = exposed (slab only). */
export const hasPlenum = (t: Typology) => ['modern_academic', 'office_lab', 'hospital', 'residence_highrise'].includes(t);
export function ceilingHeight(t: Typology, ftf: number): number { return ftf - slabT(t) - (hasPlenum(t) ? 60 : 0); }

const F = (floor: string, wall: string, ceiling: string, floorKey: Finish['floorKey'], wallKey: Finish['wallKey'], ceilingKey: Finish['ceilingKey'], lighting: Finish['lighting'], extra: Partial<Finish> = {}): Finish => ({ floor, wall, ceiling, floorKey, wallKey, ceilingKey, lighting, ...extra });

const RESTROOM_HIST = F('tex:hextile', 'paint:PAINT_OFFICE', 'paint:CEILING_WHITE', 'HEX_TILE_WHITE', 'TILE_WHITE_SUBWAY', 'CEILING_WHITE', 'INTERIOR_COOL', { tileH: 150 });
const RESTROOM_MOD = F('tex:porcelain', 'paint:PAINT_OFFICE', 'paint:CEILING_WHITE', 'PORCELAIN_MODERN', 'TILE_WHITE_SUBWAY', 'CEILING_WHITE', 'INTERIOR_COOL', { tileH: 150 });
const BOH = F('tex:sealed_concrete', 'paint:BOH_PAINT', 'tex:sealed_concrete', 'SEALED_CONCRETE', 'BOH_PAINT', 'SEALED_CONCRETE', 'INTERIOR_COOL');
const STAIR_F = (t: Typology) => (isHistoric(t) ? F('tex:terrazzo', 'paint:PLASTER_CAMPUS', 'paint:CEILING_WHITE', 'TERRAZZO', 'PLASTER_CAMPUS', 'CEILING_WHITE', 'INTERIOR_WARM') : F('tex:sealed_concrete', 'tex:cmu', 'paint:CEILING_WHITE', 'SEALED_CONCRETE', 'PAINT_DORM_BLOCK', 'CEILING_WHITE', 'INTERIOR_COOL'));

/** Finish for a room type in a building typology (CLAUDE.md §7.5). */
export function finishFor(t: Typology, room: RoomType): Finish {
  if (room === 'restroom' || room === 'apartment_bath' || room === 'bath' || room === 'guest_bath') return isHistoric(t) ? RESTROOM_HIST : RESTROOM_MOD;
  if (room === 'mechanical' || room === 'storage' || room === 'stockroom' || room === 'cellar' || room === 'laundry') return BOH;
  if (room === 'stair') return STAIR_F(t);
  if (room === 'parking') return F('tex:concrete_deck', 'tex:concrete_new', 'tex:concrete_new', 'CONCRETE_NEW', 'CONCRETE_NEW', 'CONCRETE_NEW', 'INTERIOR_COOL');
  if (room === 'deck') return F('tex:concrete_new', 'paint:CONCRETE_NEW', 'paint:CEILING_WHITE', 'CONCRETE_NEW', 'CONCRETE_NEW', 'CEILING_WHITE', 'INTERIOR_COOL');
  if (room === 'attic') return F('tex:heart_pine', 'tex:heart_pine', 'tex:heart_pine', 'HEART_PINE', 'HEART_PINE', 'HEART_PINE', 'INTERIOR_WARM');
  if (room === 'kitchen' && t !== 'house') return F('tex:vct_plain', 'paint:PAINT_RETAIL', 'tex:acoustic', 'VCT_A', 'PAINT_RETAIL', 'ACOUSTIC_TILE', 'INTERIOR_COOL', { tileH: 150 });
  switch (t) {
    case 'historic_academic': case 'mill':
      return room === 'corridor' || room === 'lobby' || room === 'hall'
        ? F('tex:terrazzo', 'paint:PLASTER_CAMPUS', 'paint:CEILING_WHITE', 'TERRAZZO', 'PLASTER_CAMPUS', 'CEILING_WHITE', 'INTERIOR_WARM', { wainscot: 'paint:WAINSCOT_GREEN', wainscotH: 110, crown: true })
        : F('tex:heart_pine', 'paint:PLASTER_CAMPUS', 'paint:CEILING_WHITE', 'HEART_PINE', 'PLASTER_CAMPUS', 'CEILING_WHITE', 'INTERIOR_WARM', { wainscot: 'paint:WAINSCOT_GREEN', wainscotH: 110, crown: true });
    case 'modern_academic': case 'office_lab': case 'arena':
      return room === 'corridor' || room === 'lobby' || room === 'concourse' ? F('tex:vct', 'paint:PAINT_OFFICE', 'tex:acoustic', 'VCT_A', 'PAINT_OFFICE', 'ACOUSTIC_TILE', 'INTERIOR_COOL', { suspended: true })
        : F('tex:carpet_office', 'paint:PAINT_OFFICE', 'tex:acoustic', 'CARPET_OFFICE', 'PAINT_OFFICE', 'ACOUSTIC_TILE', 'INTERIOR_COOL', { suspended: true });
    case 'residence_historic': case 'residence_highrise':
      return F('tex:vct_plain', 'tex:cmu', 'paint:CEILING_WHITE', 'VCT_A', 'PAINT_DORM_BLOCK', 'CEILING_WHITE', 'INTERIOR_COOL');
    case 'downtown_commercial': case 'retail':
      if (room === 'apartment_living' || room === 'apartment_bed' || room === 'apartment_kitchen' || room === 'office' || room === 'hall')
        return F('tex:oak_floor', 'paint:PAINT_RETAIL', 'paint:CEILING_WHITE', 'OAK_FLOOR', 'PAINT_RETAIL', 'CEILING_WHITE', 'INTERIOR_WARM', { crown: true });
      return F('tex:oak_floor', 'paint:PAINT_RETAIL', 'tex:tin', 'OAK_FLOOR', 'PAINT_RETAIL', 'CEILING_WHITE', 'INTERIOR_WARM');
    case 'bar':
      return room === 'bar' || room === 'back_room' || room === 'pool_room' ? F('tex:sealed_concrete', 'paint:PAINT_BAR_DARK', 'tex:walnut', 'SEALED_CONCRETE', 'PAINT_BAR_DARK', 'WALNUT_DARK', 'INTERIOR_WARM')
        : F('tex:oak_floor', 'paint:PAINT_RETAIL', 'paint:CEILING_WHITE', 'OAK_FLOOR', 'PAINT_RETAIL', 'CEILING_WHITE', 'INTERIOR_WARM');
    case 'diner':
      return F('tex:vct', 'paint:PAINT_DINER', 'paint:CEILING_WHITE', 'VCT_A', 'PAINT_DINER', 'CEILING_WHITE', 'INTERIOR_WARM');
    case 'hospital':
      return room === 'lobby' ? F('tex:terrazzo', 'paint:PAINT_HOSPITAL', 'tex:acoustic', 'TERRAZZO', 'PAINT_HOSPITAL', 'ACOUSTIC_TILE', 'INTERIOR_COOL', { band: 'paint:PAINT_HOSPITAL_ACCENT', suspended: true })
        : F('tex:sheet_vinyl', 'paint:PAINT_HOSPITAL', 'tex:acoustic', 'SHEET_VINYL', 'PAINT_HOSPITAL', 'ACOUSTIC_TILE', 'INTERIOR_COOL', { band: 'paint:PAINT_HOSPITAL_ACCENT', suspended: true });
    case 'inn':
      return room === 'corridor' ? F('tex:carpet_inn', 'paint:PLASTER_IVORY', 'paint:CEILING_WHITE', 'CARPET_INN', 'PLASTER_IVORY', 'CEILING_WHITE', 'INTERIOR_WARM', { wainscot: 'tex:walnut', wainscotH: 90, crown: true })
        : F('tex:oak_floor', 'paint:PLASTER_IVORY', 'paint:CEILING_WHITE', 'OAK_FLOOR', 'PLASTER_IVORY', 'CEILING_WHITE', 'INTERIOR_WARM', { wainscot: 'tex:walnut', wainscotH: 90, crown: true });
    case 'library':
      return room === 'stacks' ? F('tex:carpet_office', 'paint:PLASTER_IVORY', 'paint:CEILING_WHITE', 'CARPET_OFFICE', 'PLASTER_IVORY', 'CEILING_WHITE', 'INTERIOR_COOL', { wainscot: 'tex:walnut', wainscotH: 120 })
        : F('tex:marble', 'paint:PLASTER_IVORY', 'paint:CEILING_WHITE', 'MARBLE_WHITE', 'PLASTER_IVORY', 'CEILING_WHITE', 'INTERIOR_WARM', { wainscot: 'tex:walnut', wainscotH: 120, crown: true });
    case 'house':
      return room === 'kitchen' ? F('tex:vct', 'paint:PAINT_RETAIL', 'paint:CEILING_WHITE', 'VCT_A', 'PAINT_RETAIL', 'CEILING_WHITE', 'INTERIOR_WARM')
        : F('tex:oak_floor', 'paint:PLASTER_IVORY', 'paint:CEILING_WHITE', 'OAK_FLOOR', 'PLASTER_IVORY', 'CEILING_WHITE', 'INTERIOR_WARM', { crown: true });
    case 'parking':
      return F('tex:concrete_deck', 'tex:concrete_new', 'tex:concrete_new', 'CONCRETE_NEW', 'CONCRETE_NEW', 'CONCRETE_NEW', 'INTERIOR_COOL');
  }
  return F('tex:oak_floor', 'paint:PAINT_OFFICE', 'paint:CEILING_WHITE', 'OAK_FLOOR', 'PAINT_OFFICE', 'CEILING_WHITE', 'INTERIOR_WARM');
}
