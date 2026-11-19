// Parody text generators (CLAUDE.md §14): posters, flyers, graffiti and marquee titles in a satirical
// GTA tone — student elections, fake concerts, lost cats, tutoring ads, Earl University insults.
// No real people or organizations. Every string is checked by tests/parody.test.ts.
import { Rng } from '../core/rng';

const BANDS = ['The Quad Squad', 'Billram & the Horns', 'Pine Straw Revival', 'Decaf Riot', 'The Ridge Runners', 'Sweet Gum Sirens', 'Copper Patina', 'Late Fee Orchestra', 'Rosemary Deckhands', 'Tar Pit Choir'];
const VENUES = ['The Grinding Stone', 'Top of the Mount', 'Grove Amphitheatre', 'Loomhouse Commons', 'The Quarry'];
const CANDIDATES = ['Dana Pemberly', 'Rob “Bobcat” Akers', 'Jules Okonkwo-Hart', 'Mira Vantongeren', 'Sam “The Ram” Delacroix'];
const PROMISES = ['FREE PARKING ON ROSEMARY (EVENTUALLY)', 'NAP PODS IN DAVIES STACKS', '24-HOUR WAFFLE ACCESS', 'NO 8 AMs. EVER.', 'A SECOND CARILLON, LOUDER'];
const CATS = ['Pumpernickel', 'Sir Fluffington', 'Waffles', 'Professor Mittens', 'Biscuit'];
const EARL = ['EARL U: WE WERE HERE FIRST — said nobody', 'STEER CITY IS A STATE OF MIND (A SAD ONE)', 'EARL U DRINKS DECAF', 'HONK IF YOU BEAT EARL', 'EARL UNIVERSITY: COME FOR THE TUITION, STAY FOR THE TUITION'];
export const MOVIES = ['DEAD WEEK II', 'THE LAST LATE FEE', 'CARILLON OF DOOM', 'WAFFLE HUTCH: ORIGINS', 'BILLRAM RISING', 'RETURN OF THE RAVINE'];

export interface Poster { kind: 'concert' | 'election' | 'lostcat' | 'tutoring' | 'earl' | 'sale'; title: string; lines: string[]; }

export function poster(rng: Rng): Poster {
  const k = rng.weighted([['concert', 3], ['election', 2], ['lostcat', 2], ['tutoring', 2], ['earl', 2], ['sale', 1]] as const);
  switch (k) {
    case 'concert': return { kind: k, title: rng.pick(BANDS).toUpperCase(), lines: [`LIVE @ ${rng.pick(VENUES).toUpperCase()}`, `FRI ${rng.int(1, 28)} NOV · DOORS 9PM`, rng.pick(['NO COVER (BRING A COVER)', '$5 · ALL AGES-ISH', 'FEAT. A KAZOO SOLO'])] };
    case 'election': { const c = rng.pick(CANDIDATES); return { kind: k, title: `VOTE ${c.split(' ')[0].toUpperCase()}`, lines: [`${c} for Student Body Prez`, rng.pick(PROMISES), 'PAID FOR BY CONCERNED PEOPLE'] }; }
    case 'lostcat': return { kind: k, title: 'LOST CAT', lines: [`"${rng.pick(CATS)}"`, 'Last seen judging people near the Old Cistern', 'Answers to: nothing. Reward: gratitude'] };
    case 'tutoring': return { kind: k, title: 'CRAM FORTRESS', lines: ['TUTORING · ORGO · CALC · VIBES', 'Pass or your stress back*', '*stress not refundable'] };
    case 'earl': return { kind: k, title: 'BEAT EARL', lines: [rng.pick(EARL), 'GO PITCH SOLES', 'RAM IT HOME, BILLRAM'] };
    default: return { kind: k, title: 'YARD SALE', lines: ['Futons · lava lamps · one (1) canoe', 'Harrow St · Saturday', 'No early birds. Or late birds.'] };
  }
}

const TAGS = ['ROSEMARY RATS', 'DECAF EARL', 'B1LLRAM', 'RIDGE CREW', 'NO 8AMS', 'QUAD GOBLIN', 'RAMS > STEERS', 'LOOM', 'PITCH SOLES 4EVA', 'WAFFLE OR DIE'];
export const graffitiTag = (rng: Rng) => rng.pick(TAGS);

/** Every fixed parody string (for the trademark test & parody-names.json). */
export function allParodyStrings(): string[] {
  return [...BANDS, ...VENUES, ...CANDIDATES, ...PROMISES, ...CATS, ...EARL, ...MOVIES, ...TAGS];
}
