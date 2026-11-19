// Facade presets per typology (palette-only colors, CLAUDE.md §4/§5/§9).
import type { FacadeSpec, Typology } from '../interiors/types';

export function defaultFacade(t: Typology, opts: Partial<FacadeSpec> = {}): FacadeSpec {
  const base: Record<Typology, FacadeSpec> = {
    historic_academic: { wall: 'brick:flemish:BRICK_CAMPUS_A', backWall: 'brick:common:BRICK_CAMPUS_A', trim: 'satin:TRIM_WHITE', window: '9/9', winW: 107, winH: 230, bay: 320, cornice: 'dentil', roof: 'hip', roofKey: 'tex:slate', pitch: 32, shutters: 'satin:SHUTTER_GREEN', doorStyle: 'colonial:DOOR_GREEN:107:244', lintel: 'keystone', quoins: false, basementWindows: true, stoop: true },
    modern_academic: { wall: 'brick:running:BRICK_CAMPUS_B', trim: 'metal:ALUMINUM_STOREFRONT', window: 'modern', winW: 240, winH: 220, bay: 300, cornice: 'coping', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'storefront', parapetH: 90 },
    office_lab: { wall: 'brick:running:BRICK_CAMPUS_C', trim: 'metal:ALUMINUM_STOREFRONT', window: 'modern', winW: 260, winH: 230, bay: 300, cornice: 'coping', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'storefront', parapetH: 90 },
    residence_historic: { wall: 'brick:flemish:BRICK_CAMPUS_C', backWall: 'brick:common:BRICK_CAMPUS_C', trim: 'satin:TRIM_WHITE', window: '6/6', winW: 91, winH: 183, bay: 340, cornice: 'box', roof: 'gable', roofKey: 'tex:slate', pitch: 38, shutters: 'satin:SHUTTER_GREEN', doorStyle: 'colonial:DOOR_RED', lintel: 'jack', basementWindows: true, stoop: true },
    residence_highrise: { wall: 'brick:running:BRICK_CAMPUS_B', trim: 'metal:ALUMINUM_STOREFRONT', window: 'modern', winW: 150, winH: 150, bay: 340, cornice: 'coping', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'storefront', parapetH: 110 },
    downtown_commercial: { wall: 'brick:running:BRICK_DOWNTOWN_A', trim: 'satin:TRIM_WHITE', window: '2/2', winW: 91, winH: 200, bay: 200, cornice: 'italianate', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'colonial:DOOR_BLACK', lintel: 'soldier', parapetH: 90, storefront: { bays: 2, entry: 'center', awning: { kind: 'shed', color: 'paint:AWNING_HARBOR_BLUE' } } },
    retail: { wall: 'brick:running:BRICK_DOWNTOWN_B', trim: 'satin:TRIM_WHITE', window: '2/2', winW: 91, winH: 200, bay: 200, cornice: 'italianate', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'colonial:DOOR_BLACK', lintel: 'soldier', parapetH: 90, storefront: { bays: 2, entry: 'center' } },
    bar: { wall: 'brick:running:BRICK_DOWNTOWN_C', trim: 'satin:SHUTTER_BLACK', window: '2/2', winW: 91, winH: 200, bay: 200, cornice: 'box', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'colonial:DOOR_BLACK', lintel: 'segmental' as any, parapetH: 90, storefront: { bays: 1, entry: 'left' } },
    diner: { wall: 'brick:running:BRICK_DOWNTOWN_A', trim: 'satin:TRIM_WHITE', window: '2/2', winW: 91, winH: 200, bay: 200, cornice: 'box', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'colonial:DOOR_BLACK', parapetH: 90, storefront: { bays: 2, entry: 'center' } },
    hospital: { wall: 'brick:running:BRICK_CAMPUS_B', trim: 'metal:ALUMINUM_STOREFRONT', window: 'modern', winW: 220, winH: 200, bay: 280, cornice: 'coping', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'storefront', parapetH: 110 },
    house: { wall: 'paint:SIDING_CREAM', trim: 'satin:TRIM_WHITE', window: '6/6', winW: 81, winH: 150, bay: 300, cornice: 'box', roof: 'gable', roofKey: 'tex:shingle', pitch: 35, shutters: 'satin:SHUTTER_BLACK', doorStyle: 'colonial:DOOR_RED', stoop: true },
    parking: { wall: 'tex:concrete_new', trim: 'metal:GALV_STEEL', window: 'none', winW: 0, winH: 0, bay: 900, cornice: 'none', roof: 'flat', roofKey: 'tex:concrete_deck', doorStyle: 'steel', parapetH: 107 },
    inn: { wall: 'brick:flemish:BRICK_CAMPUS_B', trim: 'satin:TRIM_WHITE', window: '6/6', winW: 91, winH: 183, bay: 300, cornice: 'dentil', roof: 'hip', roofKey: 'tex:slate', pitch: 30, shutters: 'satin:SHUTTER_GREEN', doorStyle: 'colonial:DOOR_BLACK', lintel: 'keystone', stoop: true },
    library: { wall: 'brick:flemish:BRICK_CAMPUS_A', trim: 'tex:limestone', window: '9/9', winW: 120, winH: 260, bay: 360, cornice: 'dentil', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'colonial:DOOR_BLACK:107:244', lintel: 'keystone', parapetH: 100, stoop: true },
    mill: { wall: 'brick:common:BRICK_DOWNTOWN_A', trim: 'satin:TRIM_WHITE_AGED', window: '9/9', winW: 120, winH: 260, bay: 300, cornice: 'box', roof: 'flat', roofKey: 'tex:seam', doorStyle: 'colonial:DOOR_GREEN', lintel: 'segmental' as any },
    arena: { wall: 'brick:running:BRICK_CAMPUS_A', trim: 'metal:ALUMINUM_STOREFRONT', window: 'modern', winW: 300, winH: 300, bay: 600, cornice: 'coping', roof: 'flat', roofKey: 'tex:tpo', doorStyle: 'storefront' },
  };
  return { ...base[t], ...opts };
}
