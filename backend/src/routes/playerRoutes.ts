import { Router } from 'express';
import { getPlayers, getPlayerById, createPlayer, updatePlayer, deletePlayer, searchPlayers, getPlayerTransferHistory, transferPlayer } from '../controllers/playerController';

const router = Router();

router.get('/', getPlayers);

// MUST BE ABOVE /:id ROUTE
router.get('/search', searchPlayers);

router.get('/:id', getPlayerById);
router.post('/', createPlayer);
router.put('/:id', updatePlayer);
router.delete('/:id', deletePlayer);
router.get('/search', searchPlayers);
router.post('/:id/transfer', transferPlayer);
router.get('/:id/transfers', getPlayerTransferHistory);

export default router;