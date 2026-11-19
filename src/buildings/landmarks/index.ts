// Landmark registry (CLAUDE.md §10): importing this module registers every landmark's hooks.
import type { BuildingSpec } from '../../interiors/types';
import * as cistern from './oldCistern';
import * as carillon from './carillonSpire';
import * as wilberforce from './wilberforceLibrary';
import * as davies from './daviesStacks';
import * as founders from './foundersHall';
import * as elder from './elderDorms';
import * as moorhouse from './moorhouseObservatory';
import * as ashgrove from './ashgroveLibrary';
import * as union from './studentUnion';
import * as stadium from './benefactorStadium';
import * as dome from './coachsDome';
import * as inn from './pamlicoInn';
import * as medical from './medicalCenter';
import * as keep from './ghoulgraveKeep';
import * as grove from './groveAmphitheatre';

export function landmarkSpecs(): BuildingSpec[] {
  return [cistern, carillon, wilberforce, davies, founders, elder, moorhouse, ashgrove, union, stadium, dome, inn, medical, keep, grove].flatMap((m) => m.specs());
}
