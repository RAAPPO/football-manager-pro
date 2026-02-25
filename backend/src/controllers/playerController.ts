import { Request, Response } from 'express';
import pool from '../config/db';

// VIEW: Get all players (Using our Complex View!)
export const getPlayers = async (req: Request, res: Response) => {
    try {
        const [rows] = await pool.query('SELECT * FROM player_roster_view');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch players' });
    }
};

// INSERT: Add a new player
export const createPlayer = async (req: Request, res: Response) => {
    const { f_name, l_name, dob, position, city, state, pincode, club_id } = req.body;
    try {
        const [result]: any = await pool.query(
            'INSERT INTO player (f_name, l_name, dob, position, city, state, pincode, club_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [f_name, l_name, dob, position, city, state, pincode, club_id]
        );
        res.status(201).json({ message: 'Player created successfully', player_id: result.insertId });
    } catch (error: any) {
        // This will catch the error if they are under 15 (Trigger validation)
        res.status(400).json({ error: error.message || 'Failed to create player' });
    }
};

// DELETE: Remove a player (This will fire the AFTER DELETE Trigger we wrote)
export const deletePlayer = async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
        await pool.query('DELETE FROM player WHERE player_id = ?', [id]);
        res.json({ message: 'Player deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete player' });
    }
};

// VIEW SINGLE: Get raw player data for the Edit form
export const getPlayerById = async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
        // We use DATE_FORMAT so the date string fits perfectly into the HTML <input type="date">
        const query = `
            SELECT player_id, f_name, l_name, DATE_FORMAT(dob, '%Y-%m-%d') as dob, 
                   position, city, state, pincode, club_id 
            FROM player WHERE player_id = ?
        `;
        const [rows]: any = await pool.query(query, [id]);

        if (rows.length === 0) return res.status(404).json({ error: 'Player not found' });
        res.json(rows[0]);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch player details' });
    }
};

// UPDATE: Modify an existing player
export const updatePlayer = async (req: Request, res: Response) => {
    const { id } = req.params;
    const { f_name, l_name, dob, position, city, state, pincode, club_id } = req.body;
    try {
        // Handle empty club string if they set the player to Free Agent
        const validClubId = club_id === '' ? null : club_id;

        await pool.query(
            'UPDATE player SET f_name=?, l_name=?, dob=?, position=?, city=?, state=?, pincode=?, club_id=? WHERE player_id=?',
            [f_name, l_name, dob, position, city, state, pincode, validClubId, id]
        );
        res.json({ message: 'Player updated successfully' });
    } catch (error: any) {
        res.status(400).json({ error: error.message || 'Failed to update player' });
    }
};


// ==========================================
// PHASE 2: ADVANCED SCOUTING & TRANSFERS
// ==========================================

export const searchPlayers = async (req: Request, res: Response): Promise<void> => {
    try {
        const { name, nameMatchType, position, club_id, minAge, maxAge, minSalary, minTrophies } = req.query;

        let sqlQuery = `
            SELECT 
                p.player_id, 
                CONCAT(p.f_name, ' ', p.l_name) AS full_name,
                TIMESTAMPDIFF(YEAR, p.dob, CURDATE()) AS age,
                p.position,
                COALESCE(c.club_name, 'Free Agent') AS club_name,
                COALESCE(c.total_trophies, 0) AS club_trophies,
                COALESCE(con.salary, 0) AS salary
            FROM player p
            LEFT JOIN club c ON p.club_id = c.club_id
            LEFT JOIN contract con ON p.player_id = con.player_id
            WHERE 1=1
        `;

        const queryParams: any[] = [];

        if (name && typeof name === 'string') {
            if (nameMatchType === 'startsWith') {
                sqlQuery += ` AND CONCAT(p.f_name, ' ', p.l_name) LIKE ?`;
                queryParams.push(`${name}%`);
            } else if (nameMatchType === 'endsWith') {
                sqlQuery += ` AND CONCAT(p.f_name, ' ', p.l_name) LIKE ?`;
                queryParams.push(`%${name}`);
            } else if (nameMatchType === 'exact') {
                sqlQuery += ` AND CONCAT(p.f_name, ' ', p.l_name) = ?`;
                queryParams.push(name);
            } else {
                sqlQuery += ` AND CONCAT(p.f_name, ' ', p.l_name) LIKE ?`;
                queryParams.push(`%${name}%`);
            }
        }

        if (position) { sqlQuery += ` AND p.position = ?`; queryParams.push(position); }
        if (club_id) { sqlQuery += ` AND p.club_id = ?`; queryParams.push(Number(club_id)); }
        if (minAge) { sqlQuery += ` AND TIMESTAMPDIFF(YEAR, p.dob, CURDATE()) >= ?`; queryParams.push(Number(minAge)); }
        if (maxAge) { sqlQuery += ` AND TIMESTAMPDIFF(YEAR, p.dob, CURDATE()) <= ?`; queryParams.push(Number(maxAge)); }
        if (minSalary) { sqlQuery += ` AND con.salary >= ?`; queryParams.push(Number(minSalary)); }
        if (minTrophies) { sqlQuery += ` AND c.total_trophies >= ?`; queryParams.push(Number(minTrophies)); }

        sqlQuery += ` ORDER BY salary DESC, age ASC`;

        const [rows] = await pool.query(sqlQuery, queryParams);
        res.json(rows);
    } catch (error) {
        console.error("Error searching players:", error);
        res.status(500).json({ error: "Failed to search players" });
    }
};

export const transferPlayer = async (req: Request, res: Response): Promise<void> => {
    try {
        const playerId = req.params.id;
        const { new_club_id, new_salary, start_date, end_date } = req.body;

        // Triggers your custom Stored Procedure
        await pool.query('CALL transfer_player(?, ?, ?, ?, ?)', [playerId, new_club_id, new_salary, start_date, end_date]);
        res.json({ message: "Blockbuster Transfer Completed Successfully!" });
    } catch (error: any) {
        console.error("Transfer error:", error);
        res.status(500).json({ error: error.message || "Failed to execute transfer" });
    }
};

export const getPlayerTransferHistory = async (req: Request, res: Response): Promise<void> => {
    try {
        const [rows] = await pool.query(`
            SELECT h.transfer_id, c1.club_name AS old_club, c2.club_name AS new_club, h.transfer_date
            FROM player_transfer_history h
            LEFT JOIN club c1 ON h.old_club_id = c1.club_id
            LEFT JOIN club c2 ON h.new_club_id = c2.club_id
            WHERE h.player_id = ? ORDER BY h.transfer_date DESC
        `, [req.params.id]);
        res.json(rows);
    } catch (error) {
        console.error("Error fetching transfer history:", error);
        res.status(500).json({ error: "Failed to fetch transfer history" });
    }
};