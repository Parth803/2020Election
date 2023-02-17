-- PART 1
DELIMITER $$
DROP PROCEDURE IF EXISTS API1 $$
DROP PROCEDURE IF EXISTS API2 $$
DROP PROCEDURE IF EXISTS API3 $$
DROP PROCEDURE IF EXISTS API4 $$
DROP PROCEDURE IF EXISTS API5 $$

CREATE PROCEDURE API1(IN candidate varchar(50), IN timestamp varchar(100), IN precinct varchar(100))
BEGIN
	IF EXISTS (select * from Penna p where p.Timestamp = timestamp AND p.precinct = precinct) AND (candidate = "Biden" OR "Trump") THEN
		IF candidate = "Biden" THEN
			SELECT p.Biden FROM Penna p WHERE p.Timestamp = timestamp AND p.precinct = precinct;
		ELSE
			SELECT p.Trump FROM Penna p WHERE p.Timestamp = timestamp AND p.precinct = precinct;
		END IF;
	ELSEIF EXISTS (SELECT * FROM Penna p WHERE p.Timestamp < timestamp AND p.precinct = precinct) AND (candidate = "Biden" OR "Trump") THEN
		IF candidate = "Biden" THEN
			SELECT p.Biden FROM Penna p WHERE p.Timestamp < timestamp AND p.precinct = precinct ORDER BY p.Timestamp DESC LIMIT 1;
		ELSE
			SELECT p.Trump FROM Penna p WHERE p.Timestamp < timestamp AND p.precinct = precinct ORDER BY p.Timestamp DESC LIMIT 1;
		END IF;
	ELSEIF timestamp < (SELECT MIN(p.Timestamp) From Penna p LIMIT 1) THEN
		SELECT 0 as NumberOfVotes;
	ELSE
		SELECT "INVALID INPUT" as error;
	END IF;
END; $$

CREATE PROCEDURE API2(IN time varchar(100))
BEGIN
	IF EXISTS (SELECT p.TimeStamp, SUM(p.Biden) AS totalBidenVotes, SUM(p.Trump) AS totalTrumpVotes FROM Penna p WHERE p.Timestamp = (SELECT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE CONCAT(time, "%") ORDER BY p.Timestamp DESC LIMIT 1) GROUP BY p.Timestamp HAVING totalBidenVotes >= totalTrumpVotes) THEN
		SELECT CONCAT("Biden with ", SUM(p.Biden), " votes") AS winner FROM Penna p WHERE p.Timestamp = (SELECT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE CONCAT(time, "%") ORDER BY p.Timestamp DESC LIMIT 1);
	ELSEIF EXISTS (SELECT p.TimeStamp, SUM(p.Biden) AS totalBidenVotes, SUM(p.Trump) AS totalTrumpVotes FROM Penna p WHERE p.Timestamp = (SELECT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE CONCAT(time, "%") ORDER BY p.Timestamp DESC LIMIT 1) GROUP BY p.Timestamp HAVING totalBidenVotes <= totalTrumpVotes) THEN
		SELECT CONCAT("Trump with ", SUM(p.Trump), " votes") AS winner FROM Penna p WHERE p.Timestamp = (SELECT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE CONCAT(time, "%") ORDER BY p.Timestamp DESC LIMIT 1);
    ELSE
		SELECT "INVALID INPUT" as error;
    END IF;
END; $$

CREATE PROCEDURE API3(IN candidate varchar(50))
BEGIN
	IF candidate = "Trump" THEN
		SELECT DISTINCT p.precinct, p.totalvotes FROM Penna p WHERE p.Trump > p.totalvotes - p.Trump and p.timestamp = (SELECT MAX(Timestamp) From Penna p) ORDER BY p.totalvotes DESC LIMIT 10;
	ELSEIF candidate = "Biden" THEN
		SELECT DISTINCT p.precinct, p.totalvotes FROM Penna p WHERE p.Biden > p.totalvotes - p.Biden and p.timestamp = (SELECT MAX(Timestamp) From Penna p)  ORDER BY p.totalvotes DESC LIMIT 10;
	ELSE
		SELECT "INVALID INPUT" as error;
    END IF;
END; $$

CREATE PROCEDURE API4(IN precinct varchar(100))
BEGIN
	IF EXISTS (SELECT * FROM Penna p WHERE p.precinct = precinct AND p.Biden > p.Trump) THEN
		SELECT CONCAT("Biden won with ", p.Biden/p.totalvotes*100, "% votes") as PERCENTAGE FROM Penna p WHERE p.precinct = precinct AND p.Biden > p.Trump ORDER BY p.Timestamp DESC LIMIT 1;
	ELSEIF EXISTS (SELECT * FROM Penna p WHERE p.precinct = precinct AND p.Biden < p.Trump) THEN
		SELECT CONCAT("Trump won with ", p.Trump/p.totalvotes*100, "% votes") as PERCENTAGE FROM Penna p WHERE p.precinct = precinct AND p.Biden < p.Trump ORDER BY p.Timestamp DESC LIMIT 1;
	ELSE
		SELECT "INVALID INPUT" as error;
    END IF;
END; $$

CREATE PROCEDURE API5(IN str varchar(100))
BEGIN
	IF EXISTS (SELECT SUM(p.totalvotes), SUM(p.Biden) as bvotes, SUM(p.TRUMP) as tvotes FROM Penna p WHERE LOCATE(str, p.precinct) HAVING bvotes > tvotes) THEN
		SELECT CONCAT("Biden won with ", SUM(p.Biden), " votes in all precints with ", str, " in the name.") as WINNER FROM Penna p WHERE p.Timestamp = (SELECT MAX(Timestamp) From Penna p) AND LOCATE(str, p.precinct);
	ELSEIF EXISTS (SELECT SUM(p.totalvotes), SUM(p.Biden) as bvotes, SUM(p.TRUMP) as tvotes FROM Penna p WHERE LOCATE(str, p.precinct) HAVING bvotes < tvotes) THEN
		SELECT CONCAT("Trump won with ", SUM(p.Trump), " votes in all precints with ", str, " in the name.") as WINNER FROM Penna p WHERE p.Timestamp = (SELECT MAX(Timestamp) From Penna p) AND LOCATE(str, p.precinct);
	ELSE
		SELECT "INVALID INPUT" as error;
    END IF;
END; $$

DELIMITER ;

-- PART 2

DELIMITER $$
DROP PROCEDURE IF EXISTS newPenna $$
DROP PROCEDURE IF EXISTS Switch $$

-- 2.1
CREATE PROCEDURE newPenna()
BEGIN
	CREATE TABLE newPenna 
    SELECT p2.ID, p2.Timestamp, p2.state, p2.locality, p2.precinct, p2.geo, (p2.totalvotes - p1.totalvotes) AS newvotes, (p2.Biden - p1.Biden) as new_Biden, (p2.Trump - p1.Trump) as new_Trump
	FROM Penna p1 INNER JOIN Penna p2 ON p1.precinct = p2.precinct
	WHERE p2.timestamp = (SELECT MIN(timestamp) FROM Penna p3 WHERE p2.precinct = p3.precinct AND p3.Timestamp > p1.Timestamp);
END; $$

-- 2.2
CREATE PROCEDURE Switch()
BEGIN
	SELECT p1.precinct, p1.Timestamp, IF (p1.Biden > p1.Trump, "Biden", "Trump") as fromCandidate, IF (p2.Biden > p2.Trump, "Biden", "Trump") as toCandidate
	FROM Penna p1 INNER JOIN Penna p2 ON p1.precinct = p2.precinct 
    WHERE ((p1.Biden > p1.Trump AND p2.Trump > p2.Biden AND p2.Trump > p1.Biden) OR (p1.Trump > p1.Biden AND p2.Biden > p2.Trump AND p2.Biden > p1.Trump)) AND p2.Timestamp = (SELECT MAX(Timestamp) as max FROM Penna p3 WHERE p2.precinct = p3.precinct HAVING p1.Timestamp <= max - 1);
END; $$

DELIMITER ;

-- PART 3

SELECT IF (MIN(sumGreater) = 1, TRUE, FALSE) as sumOfVotesLessThanTotalVotes FROM (SELECT IF(p.totalvotes >= p.Biden + p.Trump, 1, 0) as sumGreater FROM Penna p) checkedPenna;

SELECT IF (MIN(isBetween) = 1, TRUE, FALSE) as timestampsAreBetweenNov11AndNov3 FROM (SELECT IF(p.timestamp BETWEEN "2020-11-03 00:00:00" AND "2020-11-11 23:59:59" , 1, 0) as isBetween FROM Penna p) checkedPenna;

SELECT IF (MIN(votesAscending) = 1, TRUE, FALSE) as allVotesAscending FROM (SELECT IF(group_concat(totalVotes ORDER BY totalVotes) = group_concat(totalVotes ORDER BY Timestamp), TRUE, FALSE) as votesAscending FROM Penna p WHERE p.Timestamp > "2020-11-05 00:00:00" GROUP BY p.precinct) checkedPenna;

-- PART 4

DELIMITER $$

DROP TRIGGER IF EXISTS InsertIntoInsertedTuples $$
DROP TRIGGER IF EXISTS InsertIntoUpdatedTuples $$
DROP TRIGGER IF EXISTS InsertIntoDeletedTuples $$
DROP TABLE IF EXISTS InsertedTuples $$
DROP TABLE IF EXISTS UpdatedTuples $$
DROP TABLE IF EXISTS DeletedTuples $$
DROP PROCEDURE IF EXISTS MoveVotes $$

CREATE TABLE InsertedTuples SELECT * FROM Penna WHERE 0=1;
CREATE TABLE UpdatedTuples SELECT * FROM Penna WHERE 0=1;
CREATE TABLE DeletedTuples SELECT * FROM Penna WHERE 0=1;

CREATE TRIGGER InsertIntoInsertedTuples
	BEFORE INSERT ON Penna
	FOR EACH ROW
	BEGIN
		INSERT INTO InsertedTuples(ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) 
        VALUES (new.ID, new.Timestamp, new.state, new.locality, new.precinct, new.geo, new.totalvotes, new.Biden, new.Trump, new.filestamp);
	END; $$

CREATE TRIGGER InsertIntoUpdatedTuples
	BEFORE UPDATE ON Penna
	FOR EACH ROW
	BEGIN
		INSERT INTO UpdatedTuples(ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) 
        VALUES (new.ID, new.Timestamp, new.state, new.locality, new.precinct, new.geo, new.totalvotes, new.Biden, new.Trump, new.filestamp);
	END; $$

CREATE TRIGGER InsertIntoDeletedTuples
	BEFORE DELETE ON Penna
	FOR EACH ROW
	BEGIN
		INSERT INTO DeletedTuples(ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) 
        VALUES (old.ID, old.Timestamp, old.state, old.locality, old.precinct, old.geo, old.totalvotes, old.Biden, old.Trump, old.filestamp);
	END; $$

-- 4.2
CREATE PROCEDURE MoveVotes(IN precinct varchar(100), IN timestamp datetime, IN candidate varchar(50), IN Number_of_Moved_Votes int)
BEGIN
	IF NOT EXISTS (SELECT * FROM Penna p WHERE p.Timestamp = timestamp) THEN
		SELECT "Unknown Timestamp";
	ELSEIF (candidate != "Biden") AND (candidate != "Trump") THEN
		SELECT "Wrong Candidate Name";
	ELSEIF NOT EXISTS (SELECT * FROM Penna p WHERE p.precinct = precinct) THEN
		SELECT "Wrong Precinct Name";
	ELSE
		IF (candidate = "Biden") AND EXISTS (SELECT * FROM Penna p WHERE p.Timestamp = timestamp AND p.precinct = precinct AND p.Biden < Number_of_Moved_Votes) THEN
			SELECT "Not enough votes";
		ELSEIF (candidate = "Trump") AND EXISTS (SELECT * FROM Penna p WHERE p.Timestamp = timestamp AND p.precinct = precinct AND p.Trump < Number_of_Moved_Votes) THEN
			SELECT "Not enough votes";
		ELSE
			IF (candidate = "Biden") THEN
				UPDATE Penna p SET p.Biden = p.Biden - Number_of_Moved_Votes WHERE p.precinct = precinct AND p.Timestamp >= timestamp;
                UPDATE Penna p SET p.Trump = p.Trump + Number_of_Moved_Votes WHERE p.precinct = precinct AND p.Timestamp >= timestamp;
            ELSE
				UPDATE Penna p SET p.Trump = p.Trump - Number_of_Moved_Votes WHERE p.precinct = precinct AND p.Timestamp >= timestamp; 
				UPDATE Penna p SET p.Biden = p.Biden + Number_of_Moved_Votes WHERE p.precinct = precinct AND p.Timestamp >= timestamp; 
            END IF;
		END IF;
	END IF;
END; $$

DELIMITER ;


-- TESTS
-- call API1(“Biden”, "2020-11-10", "Adams Township - Dunlo Voting Precinct");
-- call API2("2020-11-10");
-- call API3("Biden");
-- call API4("Barr Township Voting Precinct");
-- call API5("Township");

-- call newPenna();
-- call Switch();

-- call MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:58:36', "Biden", 10);
