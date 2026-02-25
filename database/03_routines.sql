DELIMITER $$

-- TRIGGER 1: BEFORE INSERT
-- Prevents adding a player younger than 15 years old.
CREATE TRIGGER before_player_insert
BEFORE INSERT ON player
FOR EACH ROW
BEGIN
    IF DATEDIFF(CURRENT_DATE, NEW.dob) / 365.25 < 15 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Player must be at least 15 years old.';
    END IF;
END$$

-- TRIGGER 2: AFTER DELETE
-- Logs the deletion of a player for audit purposes.
CREATE TRIGGER after_player_delete
AFTER DELETE ON player
FOR EACH ROW
BEGIN
    INSERT INTO player_log (player_id, deleted_at)
    VALUES (OLD.player_id, CURRENT_TIMESTAMP);
END$$

-- CURSOR: Row-by-row processing to apply a "Loyalty Bonus"
-- Increases salary by 10% if the player's contract is older than 2 years.
CREATE PROCEDURE apply_loyalty_bonus()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE c_id INT;
    DECLARE c_start DATE;
    DECLARE current_sal DECIMAL(12,2);
    
    -- Declare Cursor
    DECLARE contract_cursor CURSOR FOR 
        SELECT contract_id, start_date, salary FROM contract;
        
    -- Declare Continue Handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN contract_cursor;
    
    read_loop: LOOP
        FETCH contract_cursor INTO c_id, c_start, current_sal;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- If contract started more than 730 days (2 years) ago
        IF DATEDIFF(CURRENT_DATE, c_start) > 730 THEN
            UPDATE contract 
            SET salary = current_sal * 1.10 
            WHERE contract_id = c_id;
        END IF;
    END LOOP;
    
    CLOSE contract_cursor;
END$$

DELIMITER ;

-- =================================================================
-- PHASE 2: STORED PROCEDURES & ADVANCED TRIGGERS
-- =================================================================

DELIMITER //

-- 1. The Blockbuster Transfer System (Using ACID Transactions)
CREATE PROCEDURE transfer_player(
    IN p_player_id INT,
    IN p_new_club_id INT,
    IN p_new_salary DECIMAL(12,2),
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    -- If any query fails, rollback the entire transfer
    DECLARE exit handler for sqlexception
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Expire old contract immediately
    UPDATE contract 
    SET end_date = CURRENT_DATE() 
    WHERE player_id = p_player_id AND end_date > CURRENT_DATE();

    -- Update player's current club
    UPDATE player 
    SET club_id = p_new_club_id 
    WHERE player_id = p_player_id;

    -- Insert brand new contract
    INSERT INTO contract (player_id, club_id, salary, start_date, end_date)
    VALUES (p_player_id, p_new_club_id, p_new_salary, p_start_date, p_end_date);

    COMMIT;
END //

-- 2. Double-Booking Prevention Trigger (BEFORE INSERT)
CREATE TRIGGER before_match_insert_check_booking
BEFORE INSERT ON matches
FOR EACH ROW
BEGIN
    DECLARE clash_count INT;
    SELECT COUNT(*) INTO clash_count FROM matches 
    WHERE stadium_id = NEW.stadium_id AND match_date = NEW.match_date;
    
    IF clash_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Stadium Double-Booking detected. Choose another date or venue.';
    END IF;
END //

-- 3. Trophy Auto-Updater Trigger (AFTER UPDATE)
CREATE TRIGGER after_match_final_update
AFTER UPDATE ON matches
FOR EACH ROW
BEGIN
    -- If match is a Final, and a score was just inputted
    IF NEW.match_type = 'Final' AND OLD.home_score IS NULL AND NEW.home_score IS NOT NULL THEN
        IF NEW.home_score > NEW.away_score THEN
            UPDATE club SET total_trophies = total_trophies + 1 WHERE club_id = NEW.home_club_id;
        ELSEIF NEW.away_score > NEW.home_score THEN
            UPDATE club SET total_trophies = total_trophies + 1 WHERE club_id = NEW.away_club_id;
        END IF;
    END IF;
END //

-- 4. Transfer History Audit Logger (AFTER UPDATE)
CREATE TRIGGER after_player_transfer
AFTER UPDATE ON player
FOR EACH ROW
BEGIN
    -- Check if the club_id has changed
    IF OLD.club_id <> NEW.club_id OR (OLD.club_id IS NULL AND NEW.club_id IS NOT NULL) THEN
        INSERT INTO player_transfer_history (player_id, old_club_id, new_club_id)
        VALUES (NEW.player_id, OLD.club_id, NEW.club_id);
    END IF;
END //

DELIMITER ;