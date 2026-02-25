import { Router } from 'express';
import { getMatches, getMatchById, createMatch, updateMatch, deleteMatch, getStadiums, addMatchAppearance, getMatchLineup } from '../controllers/matchController';

const router = Router();

router.get('/stadiums', getStadiums); // MUST be above /:id so it doesn't get confused
router.get('/', getMatches);
router.get('/:id', getMatchById);
router.post('/', createMatch);
router.put('/:id', updateMatch);
router.delete('/:id', deleteMatch);
router.get('/:id/lineup', getMatchLineup);
router.post('/:id/lineup', addMatchAppearance);

export default router;