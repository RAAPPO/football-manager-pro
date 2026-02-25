import { Request, Response } from 'express';
import pool from '../config/db';

export const getDashboardData = async (req: Request, res: Response) => {
    try {
        // 1. Aggregate Queries (Fulfills the COUNT and SUM requirements!)
        const statsQuery = `
            SELECT 
                (SELECT COUNT(*) FROM player) AS total_players,
                (SELECT COUNT(*) FROM club) AS total_clubs,
                (SELECT SUM(total_trophies) FROM club) AS total_trophies,
                (SELECT COUNT(*) FROM matches) AS total_matches
        `;
        const [statsResult]: any = await pool.query(statsQuery);

        // 2. Upcoming Matches (Date is today or in the future)
        const upcomingQuery = `
            SELECT m.match_id, DATE_FORMAT(m.match_date, '%M %d, %Y') as formatted_date, 
                   h.club_name AS home_team, a.club_name AS away_team
            FROM matches m
            JOIN club h ON m.home_club_id = h.club_id
            JOIN club a ON m.away_club_id = a.club_id
            WHERE m.match_date >= CURRENT_DATE
            ORDER BY m.match_date ASC LIMIT 5;
        `;
        const [upcomingMatches] = await pool.query(upcomingQuery);

        // 3. Previous Matches (Date is in the past)
        const recentQuery = `
            SELECT m.match_id, DATE_FORMAT(m.match_date, '%M %d, %Y') as formatted_date, 
                   h.club_name AS home_team, a.club_name AS away_team, 
                   m.home_score, m.away_score
            FROM matches m
            JOIN club h ON m.home_club_id = h.club_id
            JOIN club a ON m.away_club_id = a.club_id
            WHERE m.match_date < CURRENT_DATE
            ORDER BY m.match_date DESC LIMIT 5;
        `;
        const [recentMatches] = await pool.query(recentQuery);

        // Send it all back as one neat JSON package
        res.json({
            stats: statsResult[0],
            upcoming: upcomingMatches,
            recent: recentMatches
        });

    } catch (error) {
        res.status(500).json({ error: 'Failed to load dashboard data' });
    }
};

// ==========================================
// PHASE 2: ADVANCED ANALYTICS (VIEWS)
// ==========================================

export const getLeagueStandings = async (req: Request, res: Response): Promise<void> => {
    try {
        const [rows] = await pool.query('SELECT * FROM league_standings_view');
        res.json(rows);
    } catch (error) {
        console.error("Error fetching standings:", error);
        res.status(500).json({ error: "Failed to fetch league standings" });
    }
};

export const getTopScorers = async (req: Request, res: Response): Promise<void> => {
    try {
        const [rows] = await pool.query('SELECT * FROM golden_boot_view LIMIT 10');
        res.json(rows);
    } catch (error) {
        console.error("Error fetching top scorers:", error);
        res.status(500).json({ error: "Failed to fetch top scorers" });
    }
};