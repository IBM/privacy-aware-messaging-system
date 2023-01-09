-- V3 - Data Economy
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET CURRENT SCHEMA ${schema_name};
SET CURRENT PATH = SYSTEM PATH, ${schema_name};

ALTER TABLE MODELS DROP CONSTRAINT MODEL_PK;

--Modify models to include contributons and model lineage
ALTER TABLE MODELS
  ACTIVATE VALUE COMPRESSION
  ADD COLUMN USER_ID      INTEGER
  ADD COLUMN XSUM         VARCHAR(251) COMPRESS SYSTEM DEFAULT
  ADD COLUMN CONTRIBUTION VARCHAR(501) COMPRESS SYSTEM DEFAULT
  ADD COLUMN REWARD       VARCHAR(501) COMPRESS SYSTEM DEFAULT
  ADD COLUMN METADATA     VARCHAR(251) COMPRESS SYSTEM DEFAULT
  ADD COLUMN GENRE        VARCHAR(21) COMPRESS SYSTEM DEFAULT NOT NULL DEFAULT 'UPDATE';

ALTER TABLE MODELS ADD CONSTRAINT MODEL_PK PRIMARY KEY (MODEL_ID, TASK_ID, GENRE);
ALTER TABLE MODELS ADD CONSTRAINT MOD_USER_FK FOREIGN KEY (USER_ID) REFERENCES USERS (USER_ID) ON DELETE CASCADE;
ALTER TABLE MODELS ADD CONSTRAINT GENRE_CHECK CHECK (GENRE IN ('INITIAL', 'INTERIM', 'UPDATE', 'COMPLETE'));

DROP PROCEDURE ADD_MODEL;
DROP PROCEDURE GET_MODEL;
DROP PROCEDURE GET_MODELS;
DROP PROCEDURE UPDATE_ASSIGNMENT;

-----------------------------------------------------------------------------
--Find the most recent model id for a task/user
--
CREATE OR REPLACE PROCEDURE GET_RECENT_MODEL_ID(IN i_task_id INTEGER,
                                                IN i_user_id INTEGER,
                                                OUT i_model_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    SELECT MAX(MODEL_ID) INTO i_model_id FROM MODELS WHERE TASK_ID = i_task_id and USER_ID = i_user_id;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return all model updates
--

CREATE OR REPLACE PROCEDURE GET_MODEL_LINEAGE(IN i_task VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
	SELECT M.MODEL_ID, ASSIGNMENT_HASH(M.TASK_ID, M.USER_ID) AS PARTICIPANT,
            M.GENRE, M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED,
            TO_UTC(M.UPDATED) AS UPDATED , M.CONTRIBUTION, M.REWARD, M.METADATA 
	    FROM MODELS M, TASKS T
	    WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID
            ORDER BY M.MODEL_ID;
    OPEN cur;
END;

CREATE OR REPLACE PROCEDURE GET_USER_MODEL_LINEAGE(IN i_task VARCHAR(101),
                                                   IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
	SELECT M.MODEL_ID, M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED,
            TO_UTC(M.UPDATED) AS UPDATED, M.CONTRIBUTION, M.REWARD, M.METADATA
	    FROM MODELS M, TASKS T, USERS U
	    WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            M.TASK_ID = T.TASK_ID AND
            M.USER_ID = U.USER_ID
            ORDER BY M.MODEL_ID;
    OPEN cur;
END;


CREATE OR REPLACE PROCEDURE GET_MODELS(IN i_genre VARCHAR(21) DEFAULT 'COMPLETE')
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, TO_UTC(M.ADDED) AS ADDED
            FROM MODELS M, TASKS T
            WHERE M.GENRE = i_genre AND
            T.TASK_ID = M.TASK_ID
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

CREATE OR REPLACE PROCEDURE GET_MODEL(IN i_task VARCHAR(101),
                                      IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M, MODEL_ACL A, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            M.TASK_ID = T.TASK_ID AND
            M.GENRE = 'COMPLETE' AND
            A.MODEL_ID = M.MODEL_ID AND
            A.USER_ID = U.USER_ID;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Removes model lineage
--

CREATE OR REPLACE PROCEDURE DELETE_LINEAGE_BY_ID(IN i_task_id INTEGER,
                                                 IN i_user_id INTEGER DEFAULT NULL)
LANGUAGE SQL
BEGIN
    DELETE FROM MODELS WHERE TASK_ID = i_task_id AND USER_ID != i_user_id;
END;

CREATE OR REPLACE PROCEDURE DELETE_LINEAGE(IN i_task VARCHAR(101),
                                           IN i_user VARCHAR(101))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);
    CALL DELETE_LINEAGE_BY_ID(v_task_id, v_user_id);
END;

CREATE OR REPLACE TRIGGER CLEAR_LINEAGE 
    AFTER DELETE ON MODELS
    REFERENCING OLD ROW AS OLD NEW ROW AS NEW
    FOR EACH ROW MODE DB2SQL
BEGIN
    DECLARE v_user_id INTEGER;

    SELECT USER_ID INTO v_user_id FROM TASKS WHERE TASK_ID = NEW.TASK_ID;

    --Is this an aggregated model?
    IF (v_user_id = NEW.USER_ID) THEN
        CALL DELETE_LINEAGE(NEW.TASK_ID, NEW.USER_ID);
    END IF;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new model
--

CREATE OR REPLACE TRIGGER UPDATE_MODEL_ACL 
    AFTER INSERT ON MODELS
    REFERENCING OLD ROW AS OLD NEW ROW AS NEW
    FOR EACH ROW MODE DB2SQL
BEGIN
    DECLARE v_user_id INTEGER;

    SELECT USER_ID INTO v_user_id FROM TASKS WHERE TASK_ID = NEW.TASK_ID;
    INSERT INTO MODEL_ACL(MODEL_ID, USER_ID) VALUES (NEW.MODEL_ID, NEW.USER_ID);

    --Is this an aggregated model?
    IF (v_user_id = NEW.USER_ID) THEN
        INSERT INTO MODEL_ACL (MODEL_ID, USER_ID) 
            SELECT NEW.MODEL_ID, A.USER_ID FROM ASSIGNMENTS A
                WHERE A.TASK_ID = NEW.TASK_ID;
    ELSE
        INSERT INTO MODEL_ACL (MODEL_ID, USER_ID) VALUES (NEW.MODEL_ID, v_user_id);
    END IF;
END;


CREATE or REPLACE PROCEDURE ADD_MODEL_BY_ID(IN i_task_id INTEGER, 
                                            IN i_user_id INTEGER,                                      
                                            IN i_ex_id VARCHAR(251),
                                            IN i_meta VARCHAR(251),
                                            IN i_xsum VARCHAR(251),
                                            IN i_genre VARCHAR(21))
LANGUAGE SQL
BEGIN
    DECLARE v_id INTEGER;

    SET v_id = NEXT VALUE FOR MODEL_SEQ;

    INSERT INTO MODELS (MODEL_ID, TASK_ID, USER_ID, EXTERNAL_ID, METADATA, XSUM, GENRE)
        VALUES (v_id, i_task_id, i_user_id, i_ex_id, i_meta, i_xsum, i_genre);
END;


CREATE or REPLACE PROCEDURE ADD_MODEL(IN i_task VARCHAR(101),
                                      IN i_user VARCHAR(101),
                                      IN i_ex_id VARCHAR(251),
                                      IN i_meta VARCHAR(251),
                                      IN i_xsum VARCHAR(251),
                                      IN i_genre VARCHAR(21))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);
    CALL ADD_MODEL_BY_ID(v_task_id, v_user_id, i_ex_id, i_meta, i_xsum, i_genre);
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Add value

CREATE or REPLACE PROCEDURE UPDATE_ASSIGNMENT_VALUE(IN i_participant VARCHAR(101),
                                                    IN i_contribution VARCHAR(501),
                                                    IN i_reward VARCHAR(501))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;
    DECLARE v_model_id INTEGER;

    SET v_task_id = TO_HASH(SUBSTR(i_participant, 1, LOCATE(':', i_participant)-1));
    SET v_user_id = TO_HASH(SUBSTR(i_participant, LOCATE(':', i_participant)+1));

    CALL GET_RECENT_MODEL_ID(v_task_id, v_user_id, v_model_id);

    UPDATE MODELS SET CONTRIBUTION=i_contribution, REWARD=i_reward WHERE MODEL_ID = v_model_id;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Update assignment and model ref
--

CREATE or REPLACE PROCEDURE UPDATE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101),
                                              IN i_status VARCHAR(21),
                                              IN i_ex_id VARCHAR(251),
                                              IN i_xsum VARCHAR(251),
                                              IN i_meta VARCHAR(251))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);

    UPDATE ASSIGNMENTS SET STATUS=i_status WHERE TASK_ID = v_task_id and USER_ID = v_user_id;

    CALL ADD_MODEL_BY_ID(v_task_id, v_user_id, i_ex_id, i_meta, i_xsum, 'UPDATE');
END;

-----------------------------------------------------------------------------

