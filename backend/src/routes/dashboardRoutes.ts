import { Router } from 'express';
import { getDashboardData, getLeagueStandings, getTopScorers } from '../controllers/dashboardController';

const router = Router();

router.get('/', getDashboardData);
router.get('/standings', getLeagueStandings);
router.get('/top-scorers', getTopScorers);

export default router;