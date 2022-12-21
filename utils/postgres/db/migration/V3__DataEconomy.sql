-- V3 - Data Economy
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

--TODO
SET schema '${schema_name}';
--SET CURRENT SCHEMA ${schema_name};
--SET CURRENT PATH = SYSTEM PATH, ${schema_name};

ALTER TABLE MODELS DROP CONSTRAINT MODEL_PK CASCADE;

-----------------------------------------------------------------------------
--Modify models to include contributons and model lineage
ALTER TABLE MODELS
  ADD USER_ID      INTEGER,
  ADD XSUM         VARCHAR(251), --COMPRESS SYSTEM DEFAULT
  ADD CONTRIBUTION VARCHAR(501), --COMPRESS SYSTEM DEFAULT
  ADD REWARD       VARCHAR(501), --COMPRESS SYSTEM DEFAULT
  ADD METADATA     VARCHAR(251), --COMPRESS SYSTEM DEFAULT
  ADD GENRE        VARCHAR(21) NOT NULL DEFAULT 'UPDATE'; --COMPRESS SYSTEM DEFAULT NOT NULL DEFAULT 'UPDATE';

ALTER TABLE MODELS ADD CONSTRAINT MODEL_PK PRIMARY KEY (MODEL_ID, TASK_ID, GENRE);
ALTER TABLE MODELS ADD CONSTRAINT MOD_USER_FK FOREIGN KEY (USER_ID) REFERENCES USERS (USER_ID) ON DELETE CASCADE;
ALTER TABLE MODELS ADD CONSTRAINT GENRE_CHECK CHECK (GENRE IN ('INITIAL', 'INTERIM', 'UPDATE', 'COMPLETE'));

DROP FUNCTION ADD_MODEL;
DROP FUNCTION GET_MODEL;
DROP FUNCTION GET_MODELS;
DROP FUNCTION UPDATE_ASSIGNMENT;

-----------------------------------------------------------------------------
--Find the most recent model id for a task/user
--
CREATE OR REPLACE FUNCTION GET_RECENT_MODEL_ID(IN i_task_id INTEGER,
                                                IN i_user_id INTEGER,
                                                OUT i_model_id INTEGER) RETURNS INTEGER
AS $$
BEGIN
    SELECT MAX(MODEL_ID) INTO i_model_id FROM MODELS WHERE TASK_ID = i_task_id and USER_ID = i_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GET_MODEL_LINEAGE(IN i_task VARCHAR(101))
RETURNS TABLE(model_id integer, participant varchar, genre varchar, external_id varchar, xsum varchar, added varchar, updated varchar, contribution varchar, reward varchar, metadata varchar)
AS $$
    SELECT M.MODEL_ID, ASSIGNMENT_HASH(M.TASK_ID, M.USER_ID) AS PARTICIPANT,
            M.GENRE, M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED,
            TO_UTC(M.UPDATED) AS UPDATED , M.CONTRIBUTION, M.REWARD, M.METADATA 
	    FROM MODELS M, TASKS T
	    WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID
            ORDER BY M.MODEL_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_USER_MODEL_LINEAGE(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(model_id integer, external_id varchar, xsum varchar, added varchar, updated varchar, contribution varchar, reward varchar, metadata varchar)
AS $$
    SELECT M.MODEL_ID, M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED,
            TO_UTC(M.UPDATED) AS UPDATED, M.CONTRIBUTION, M.REWARD, M.METADATA
	    FROM MODELS M, TASKS T, USERS U
	    WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            M.TASK_ID = T.TASK_ID AND
            M.USER_ID = U.USER_ID
            ORDER BY M.MODEL_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_MODELS(IN i_genre VARCHAR(21) DEFAULT 'COMPLETE')
RETURNS TABLE(task_name varchar, added varchar)
AS $$
    SELECT T.TASK_NAME, TO_UTC(M.ADDED) AS ADDED
            FROM MODELS M, TASKS T
            WHERE M.GENRE = i_genre AND
            T.TASK_ID = M.TASK_ID
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------
--Return model
--

CREATE OR REPLACE FUNCTION GET_MODEL(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(external_id varchar, xsum varchar, added varchar)
AS $$
    SELECT M.EXTERNAL_ID, M.XSUM, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M, MODEL_ACL A, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            M.TASK_ID = T.TASK_ID AND
            M.GENRE = 'COMPLETE' AND
            A.MODEL_ID = M.MODEL_ID AND
            A.USER_ID = U.USER_ID;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Removes model lineage
--
CREATE OR REPLACE FUNCTION DELETE_LINEAGE_BY_ID(IN i_task_id INTEGER,
                                                 IN i_user_id INTEGER DEFAULT NULL) RETURNS VOID
AS $$
BEGIN
    DELETE FROM MODELS WHERE TASK_ID = i_task_id AND USER_ID != i_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION DELETE_LINEAGE(IN i_task VARCHAR(101),
                                           IN i_user VARCHAR(101)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;
BEGIN
    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;

    PERFORM DELETE_LINEAGE_BY_ID(v_task_id, v_user_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CLEAR_LINEAGE() RETURNS TRIGGER
AS $$

    DECLARE v_user_id INTEGER;
BEGIN

    SELECT USER_ID INTO v_user_id FROM TASKS WHERE TASK_ID = OLD.TASK_ID;

    IF (v_user_id = OLD.USER_ID) THEN
        PERFORM DELETE_LINEAGE(OLD.TASK_ID, OLD.USER_ID);
    END IF;

    DELETE FROM MODEL_ACL WHERE MODEL_ID = OLD.MODEL_ID;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER CLEAR_LINEAGE_TRIGGER
    AFTER DELETE ON MODELS
    REFERENCING OLD TABLE AS OLD
    FOR EACH ROW EXECUTE FUNCTION CLEAR_LINEAGE();

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new model
--

CREATE OR REPLACE FUNCTION UPDATE_MODEL_ACL() RETURNS TRIGGER
AS $$
    DECLARE v_user_id INTEGER;
BEGIN

    SELECT USER_ID INTO v_user_id FROM TASKS WHERE TASK_ID = NEW.TASK_ID;
    INSERT INTO MODEL_ACL(MODEL_ID, USER_ID) VALUES (NEW.MODEL_ID, NEW.USER_ID);

    IF (v_user_id = NEW.USER_ID) THEN
        INSERT INTO MODEL_ACL (MODEL_ID, USER_ID) 
            SELECT NEW.MODEL_ID, A.USER_ID FROM ASSIGNMENTS A
                WHERE A.TASK_ID = NEW.TASK_ID;
    ELSE
        INSERT INTO MODEL_ACL (MODEL_ID, USER_ID) VALUES (NEW.MODEL_ID, v_user_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER UPDATE_MODEL_ACL_TRIGGER
    AFTER INSERT ON MODELS
    REFERENCING NEW TABLE AS NEW
    FOR EACH ROW EXECUTE FUNCTION UPDATE_MODEL_ACL();

CREATE or REPLACE FUNCTION ADD_MODEL_BY_ID(IN i_task_id INTEGER, 
                                            IN i_user_id INTEGER,                                      
                                            IN i_ex_id VARCHAR(251),
                                            IN i_meta VARCHAR(251),
                                            IN i_xsum VARCHAR(251),
                                            IN i_genre VARCHAR(21)) RETURNS VOID
AS $$

    DECLARE v_id INTEGER;
BEGIN
    v_id := NEXTVAL('MODEL_SEQ');

    INSERT INTO MODELS (MODEL_ID, TASK_ID, USER_ID, EXTERNAL_ID, METADATA, XSUM, GENRE)
        VALUES (v_id, i_task_id, i_user_id, i_ex_id, i_meta, i_xsum, i_genre);
END;
$$ LANGUAGE plpgsql;


CREATE or REPLACE FUNCTION ADD_MODEL(IN i_task VARCHAR(101),
                                      IN i_user VARCHAR(101),
                                      IN i_ex_id VARCHAR(251),
                                      IN i_meta VARCHAR(251),
                                      IN i_xsum VARCHAR(251),
                                      IN i_genre VARCHAR(21)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;
    PERFORM ADD_MODEL_BY_ID(v_task_id, v_user_id, i_ex_id, i_meta, i_xsum, i_genre);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Add value

CREATE or REPLACE FUNCTION UPDATE_ASSIGNMENT_VALUE(IN i_participant VARCHAR(101),
                                                    IN i_contribution VARCHAR(501),
                                                    IN i_reward VARCHAR(501)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;
    DECLARE v_model_id INTEGER;
BEGIN

    --v_task_id := TO_HASH(SUBSTR(i_participant, 1, POSITION(':' IN i_participant)-1));
    --v_user_id := TO_HASH(SUBSTR(i_participant, POSITION(':' IN i_participant)+1));
    v_task_id := cast(TO_HASH(CAST(SUBSTR(i_participant, 1, POSITION(':' IN i_participant)-1) AS INTEGER)) AS INTEGER);
    v_user_id := cast(TO_HASH(CAST(SUBSTR(i_participant, POSITION(':' IN i_participant)+1) AS INTEGER)) AS INTEGER);

    SELECT * FROM GET_RECENT_MODEL_ID(v_task_id, v_user_id) INTO v_model_id;

    UPDATE MODELS SET CONTRIBUTION=i_contribution, REWARD=i_reward WHERE MODEL_ID = v_model_id;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Update assignment and model ref
--
CREATE or REPLACE FUNCTION UPDATE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101),
                                              IN i_status VARCHAR(21),
                                              IN i_ex_id VARCHAR(251),
                                              IN i_xsum VARCHAR(251),
                                              IN i_meta VARCHAR(251)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;

    UPDATE ASSIGNMENTS SET STATUS=i_status WHERE TASK_ID = v_task_id and USER_ID = v_user_id;

    PERFORM ADD_MODEL_BY_ID(v_task_id, v_user_id, i_ex_id, i_meta, i_xsum, 'UPDATE');
END;
$$ LANGUAGE plpgsql;


