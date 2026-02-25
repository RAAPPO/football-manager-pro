-- DDL Commands: Schema creation for Football Management System

-- 1. Users Table (For Admin/User Module)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('Admin', 'User') DEFAULT 'User',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Club Table
CREATE TABLE club (
    club_id INT AUTO_INCREMENT PRIMARY KEY,
    club_name VARCHAR(100) NOT NULL UNIQUE,
    founded_year INT NOT NULL,
    total_trophies INT DEFAULT 0,
    owner_name VARCHAR(100),
    club_email VARCHAR(100) UNIQUE
);

-- 3. Stadium Table
CREATE TABLE stadium (
    stadium_id INT AUTO_INCREMENT PRIMARY KEY,
    stadium_name VARCHAR(100) NOT NULL,
    capacity INT NOT NULL,
    city VARCHAR(50) NOT NULL
);

-- 4. Player Table (Age removed - will be calculated using Date functions)
CREATE TABLE player (
    player_id INT AUTO_INCREMENT PRIMARY KEY,
    f_name VARCHAR(50) NOT NULL,
    l_name VARCHAR(50) NOT NULL,
    dob DATE NOT NULL,
    position VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(50),
    pincode VARCHAR(10),
    club_id INT,
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE SET NULL
);

-- 5. Player Phone Table (1NF - handling multiple phone numbers)
CREATE TABLE player_phone (
    player_id INT,
    phone_no VARCHAR(15),
    PRIMARY KEY (player_id, phone_no),
    FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
);

-- 6. Contract Table (Duration removed - will be calculated dynamically)
CREATE TABLE contract (
    contract_id INT AUTO_INCREMENT PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    salary DECIMAL(12,2) NOT NULL,
    player_id INT NOT NULL,
    club_id INT NOT NULL,
    FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE,
    FOREIGN KEY (club_id) REFERENCES club(club_id) ON DELETE CASCADE
);

-- 7. Matches Table (Self-referencing clubs for Home/Away to allow Complex Joins)
CREATE TABLE matches (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    match_type VARCHAR(50) NOT NULL,
    match_date DATE NOT NULL,
    home_club_id INT NOT NULL,
    away_club_id INT NOT NULL,
    home_score INT DEFAULT 0,
    away_score INT DEFAULT 0,
    stadium_id INT NOT NULL,
    FOREIGN KEY (home_club_id) REFERENCES club(club_id) ON DELETE CASCADE,
    FOREIGN KEY (away_club_id) REFERENCES club(club_id) ON DELETE CASCADE,
    FOREIGN KEY (stadium_id) REFERENCES stadium(stadium_id) ON DELETE CASCADE
);

-- 8. Player Log Table (For AFTER DELETE Trigger)
CREATE TABLE player_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    player_id INT NOT NULL,
    deleted_at DATETIME NOT NULL
);

-- =================================================================
-- PHASE 2: ADVANCED SCHEMA ADDITIONS
-- =================================================================

-- 1. Many-to-Many Junction Table for Match Lineups & Stats
CREATE TABLE IF NOT EXISTS match_appearances (
    appearance_id INT PRIMARY KEY AUTO_INCREMENT,
    match_id INT NOT NULL,
    player_id INT NOT NULL,
    minutes_played INT DEFAULT 0,
    goals INT DEFAULT 0,
    assists INT DEFAULT 0,
    FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE,
    UNIQUE KEY unique_appearance (match_id, player_id)
);

-- 2. Audit Table for Automated Transfer History
CREATE TABLE IF NOT EXISTS player_transfer_history (
    transfer_id INT PRIMARY KEY AUTO_INCREMENT,
    player_id INT NOT NULL,
    old_club_id INT,
    new_club_id INT,
    transfer_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
);