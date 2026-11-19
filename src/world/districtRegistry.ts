// District generator registry (no imports: avoids module cycles with cityPlan).
import type { CityPlanBuilder } from './cityPlan';
export const DISTRICT_GENERATORS: { name: string; order: number; run: (b: CityPlanBuilder) => void }[] = [];
