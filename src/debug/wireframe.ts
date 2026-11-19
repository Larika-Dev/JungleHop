// Wireframe toggle (CLAUDE.md §16).
import { MeshBasicMaterial, type Scene } from 'three';
import { pc } from '../core/palette';

const wire = new MeshBasicMaterial({ color: pc('MARKING_WHITE'), wireframe: true });
export function setWireframe(scene: Scene, on: boolean) { scene.overrideMaterial = on ? wire : null; }
