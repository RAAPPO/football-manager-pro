-- 1. Updatable View (Contains no aggregates or joins, so we can UPDATE through it)
CREATE VIEW player_contact_view AS
SELECT player_id, f_name, l_name, city, state, pincode
FROM player;

-- 2. Complex View (Read-Only) combining Players, Clubs, and calculating Age dynamically
CREATE VIEW player_roster_view AS
SELECT 
    p.player_id,
    CONCAT(p.f_name, ' ', p.l_name) AS full_name,
    FLOOR(DATEDIFF(CURRENT_DATE, p.dob) / 365.25) AS age_calculated,
    UPPER(c.club_name) AS club_name,
    p.position
FROM player p
LEFT JOIN club c ON p.club_id = c.club_id;

-- =================================================================
-- PHASE 2: ADVANCED ANALYTICS VIEWS
-- =================================================================

-- 1. Live League Standings (Calculates Points, Wins, Losses, and Goal Difference on the fly)
CREATE OR REPLACE VIEW league_standings_view AS
SELECT 
    club_id,
    club_name,
    COUNT(match_id) AS matches_played,
    SUM(CASE WHEN is_win = 1 THEN 1 ELSE 0 END) AS wins,
    SUM(CASE WHEN is_draw = 1 THEN 1 ELSE 0 END) AS draws,
    SUM(CASE WHEN is_loss = 1 THEN 1 ELSE 0 END) AS losses,
    SUM(goals_for) AS goals_for,
    SUM(goals_against) AS goals_against,
    SUM(goals_for) - SUM(goals_against) AS goal_difference,
    SUM(CASE WHEN is_win = 1 THEN 3 WHEN is_draw = 1 THEN 1 ELSE 0 END) AS points
FROM (
    SELECT 
        c.club_id, c.club_name, m.match_id,
        m.home_score AS goals_for, m.away_score AS goals_against,
        IF(m.home_score > m.away_score, 1, 0) AS is_win,
        IF(m.home_score = m.away_score, 1, 0) AS is_draw,
        IF(m.home_score < m.away_score, 1, 0) AS is_loss
    FROM club c
    JOIN matches m ON c.club_id = m.home_club_id
    WHERE m.home_score IS NOT NULL
    UNION ALL
    SELECT 
        c.club_id, c.club_name, m.match_id,
        m.away_score AS goals_for, m.home_score AS goals_against,
        IF(m.away_score > m.home_score, 1, 0) AS is_win,
        IF(m.away_score = m.home_score, 1, 0) AS is_draw,
        IF(m.away_score < m.home_score, 1, 0) AS is_loss
    FROM club c
    JOIN matches m ON c.club_id = m.away_club_id
    WHERE m.away_score IS NOT NULL
) AS team_results
GROUP BY club_id, club_name
ORDER BY points DESC, goal_difference DESC;

-- 2. Golden Boot Leaderboard (Using Advanced Window Functions)
CREATE OR REPLACE VIEW golden_boot_view AS
SELECT 
    p.player_id,
    CONCAT(p.f_name, ' ', p.l_name) AS player_name,
    c.club_name,
    SUM(ma.goals) AS total_goals,
    DENSE_RANK() OVER (ORDER BY SUM(ma.goals) DESC) AS league_rank
FROM player p
JOIN match_appearances ma ON p.player_id = ma.player_id
LEFT JOIN club c ON p.club_id = c.club_id
GROUP BY p.player_id, p.f_name, p.l_name, c.club_name
HAVING total_goals > 0;