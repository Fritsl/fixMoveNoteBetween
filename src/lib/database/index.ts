import { noteOperations } from './notes';
import { projectOperations } from './projects';
import { imageOperations } from './images';
import { authOperations } from './auth';
import { sequenceOperations } from './sequences';

export const database = {
  notes: noteOperations,
  projects: projectOperations,
  images: imageOperations,
  auth: authOperations,
  sequences: sequenceOperations
};