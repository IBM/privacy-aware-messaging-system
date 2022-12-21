-- V2 - Add stored procedures
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET CURRENT SCHEMA ${schema_name};
SET CURRENT PATH = SYSTEM PATH, ${schema_name};

-----------------------------------------------------------------------------
--Inserts new user
--

CREATE or REPLACE PROCEDURE ADD_USER(IN i_name VARCHAR(101), IN i_org VARCHAR(501))
LANGUAGE SQL
BEGIN
    DECLARE v_id INTEGER;

    SET v_id = NEXT VALUE FOR USER_SEQ;
    INSERT INTO USERS (USER_ID, USER_NAME, ORGANISATION) VALUES (v_id, i_name, i_org);
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Deletes a user
--

CREATE or REPLACE PROCEDURE DELETE_USER(IN i_name VARCHAR(101))
LANGUAGE SQL
BEGIN
    DELETE FROM USERS WHERE USER_NAME = i_name;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return user id
--

CREATE OR REPLACE PROCEDURE GET_USER_ID(IN i_user VARCHAR(101), OUT i_user_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    SELECT USER_ID INTO i_user_id FROM USERS WHERE USER_NAME = i_user;

    IF (i_user_id IS NULL) THEN
        SIGNAL SQLSTATE '20001' SET MESSAGE_TEXT = 'User not found';
    END IF;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new task
--

CREATE or REPLACE PROCEDURE ADD_TASK(IN i_name VARCHAR(101),
                                     IN i_user VARCHAR(101),
                                     IN i_topology VARCHAR(101),
                                     IN i_definition VARCHAR(5000) DEFAULT NULL)
LANGUAGE SQL
BEGIN
    DECLARE v_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_USER_ID(i_user, v_user_id);
    SET v_id = NEXT VALUE FOR TASK_SEQ;

    INSERT INTO TASKS (TASK_ID, USER_ID, TASK_NAME, TOPOLOGY, DEFINITION)
        VALUES (v_id, v_user_id, i_name, i_topology, i_definition);
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Deletes a task
--

CREATE or REPLACE PROCEDURE DELETE_TASK(IN i_name VARCHAR(101))
LANGUAGE SQL
BEGIN
    DELETE FROM TASKS WHERE TASK_NAME = i_name;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return task id
--

CREATE OR REPLACE PROCEDURE GET_TASK_ID(IN i_task VARCHAR(101), OUT i_task_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    SELECT TASK_ID INTO i_task_id FROM TASKS WHERE TASK_NAME = i_task;

    IF (i_task_id IS NULL) THEN
        SIGNAL SQLSTATE '20001' SET MESSAGE_TEXT = 'Task not found';
    END IF;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Updates a task
--

CREATE or REPLACE PROCEDURE ADMIN_UPDATE_TASK(IN i_name VARCHAR(101),
                                              IN i_status VARCHAR(21),
                                              IN i_queue VARCHAR(101) DEFAULT NULL)
LANGUAGE SQL
BEGIN
    UPDATE TASKS SET STATUS=i_status, QUEUE=i_queue
        WHERE TASK_NAME=i_name;
END;

CREATE or REPLACE PROCEDURE UPDATE_TASK(IN i_name VARCHAR(101),
                                        IN i_topology VARCHAR(101),
                                        IN i_definition VARCHAR(5000) DEFAULT NULL,
                                        IN i_status VARCHAR(21))
LANGUAGE SQL
BEGIN
    UPDATE TASKS SET STATUS=i_status, TOPOLOGY=i_topology, DEFINITION=i_definition
        WHERE TASK_NAME=i_name;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return all users
--

CREATE OR REPLACE PROCEDURE GET_USERS()
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT U.USER_NAME, U.ORGANISATION FROM USERS U
            ORDER BY U.USER_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return an assignment hash of task id and user id
--

CREATE or REPLACE FUNCTION TO_HASH(input INTEGER)
RETURNS INTEGER
RETURN ((65535 & input) * power(2, 16)) + ((4294901760 & input) / power(2, 16));

CREATE or REPLACE FUNCTION ASSIGNMENT_HASH(task_id INTEGER, user_id INTEGER)
RETURNS VARCHAR(51)
RETURN TO_CHAR(TO_HASH(task_id)) CONCAT ':' CONCAT TO_CHAR(TO_HASH(user_id));

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return an ISO 8601 time
--

CREATE or REPLACE FUNCTION TO_UTC(ts TIMESTAMP)
RETURNS VARCHAR(51)
RETURN CONCAT(REPLACE(TO_CHAR(ts, 'YYYY-MM-DD HH24:MI:SS.NNNNNN'), ' ', 'T'), 'Z');

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return task
--

CREATE OR REPLACE PROCEDURE ADMIN_GET_TASK_INFO(IN i_task VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED 
            FROM TASKS T, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_ID = T.USER_ID;
    OPEN cur;
END;

-----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE GET_TASK_CREATION_INFO(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED 
            FROM TASKS T, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            T.USER_ID = U.USER_ID;
    OPEN cur;
END;

-----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE GET_USER_TASKS(IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED
            FROM TASKS T, USERS U
            WHERE U.USER_NAME = i_user AND
            T.USER_ID = U.USER_ID
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--Return all tasks
--

CREATE OR REPLACE PROCEDURE GET_TASKS()
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return a users participation
--

CREATE OR REPLACE PROCEDURE GET_ASSIGNMENTS_BY_ID(IN i_user_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, T.STATUS AS TSTATUS, A.QUEUE, A.STATUS AS STATUS, 
            TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A, TASKS T
            WHERE A.USER_ID = i_user_id AND
            T.TASK_ID = A.TASK_ID 
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

CREATE OR REPLACE PROCEDURE GET_ASSIGNMENTS(IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE v_user_id INTEGER;
    CALL GET_USER_ID(i_user, v_user_id);
    CALL GET_ASSIGNMENTS_BY_ID(v_user_id);
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return participants for a task
--


CREATE OR REPLACE PROCEDURE ADMIN_GET_TASK_ASSIGNMENTS_BY_ID(IN i_task VARCHAR(101), IN i_user_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT U.USER_NAME, A.QUEUE, A.STATUS, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
           TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
           FROM TASKS T, ASSIGNMENTS A, USERS U
           WHERE T.TASK_ID IN
              (SELECT T.TASK_ID FROM TASKS T
                    WHERE T.TASK_NAME = i_task AND T.USER_ID = i_user_id) AND
           A.TASK_ID = T.TASK_ID AND
           U.USER_ID = A.USER_ID
           ORDER BY A.ADDED;
    OPEN cur;
END;

CREATE OR REPLACE PROCEDURE GET_TASK_ASSIGNMENTS_BY_ID(IN i_task VARCHAR(101), IN i_user_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT A.STATUS, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
            TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM TASKS T, ASSIGNMENTS A
            WHERE T.TASK_ID IN 
                (SELECT T.TASK_ID FROM TASKS T
                    WHERE T.TASK_NAME = i_task AND T.USER_ID = i_user_id) AND
            A.TASK_ID = T.TASK_ID
            ORDER BY A.ADDED;
    OPEN cur;
END;

CREATE OR REPLACE PROCEDURE GET_TASK_ASSIGNMENTS(IN i_task VARCHAR(101), IN i_user VARCHAR(101), 
                                                 IN i_admin BOOLEAN DEFAULT FALSE)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE v_user_id INTEGER;
    CALL GET_USER_ID(i_user, v_user_id);

    IF (i_admin IS TRUE) THEN
        CALL ADMIN_GET_TASK_ASSIGNMENTS_BY_ID(i_task, v_user_id);
    ELSE
        CALL GET_TASK_ASSIGNMENTS_BY_ID(i_task, v_user_id);
    END IF;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return participants for all tasks - admin only
--

CREATE OR REPLACE PROCEDURE GET_ALL_ASSIGNMENTS()
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, U.USER_NAME, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
               A.QUEUE, A.STATUS, TO_UTC(T.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM TASKS T, USERS U, ASSIGNMENTS A
            WHERE A.TASK_ID = T.TASK_ID AND
            U.USER_ID = A.USER_ID
            ORDER BY T.TASK_NAME, U.USER_NAME, T.ADDED;
   OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new task participant
--

CREATE or REPLACE PROCEDURE ADD_ASSIGNMENT(IN i_task VARCHAR(101),
                                           IN i_user VARCHAR(101),
                                           IN i_queue VARCHAR(101))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);

    INSERT INTO ASSIGNMENTS (TASK_ID, USER_ID, QUEUE) VALUES (v_task_id, v_user_id, i_queue);
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Updates an assignment
--

CREATE or REPLACE PROCEDURE UPDATE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101),
                                              IN i_status VARCHAR(21))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);

    UPDATE ASSIGNMENTS SET STATUS=i_status WHERE TASK_ID = v_task_id and USER_ID = v_user_id;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Retrieves assignment details
--

CREATE OR REPLACE PROCEDURE GET_ASSIGNMENT_BY_ID(IN i_task_id INTEGER, IN i_user_id INTEGER)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT A.TASK_ID, A.USER_ID, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
               A.QUEUE, A.STATUS, TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A
            WHERE A.TASK_ID = i_task_id AND
            A.USER_ID = i_user_id;
    OPEN cur;
END;

CREATE or REPLACE PROCEDURE GET_ASSIGNMENT(IN i_task VARCHAR(101),
                                           IN i_user VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);
    CALL GET_ASSIGNMENT_BY_ID(v_task_id, v_user_id); 
END;

CREATE or REPLACE PROCEDURE GET_ASSIGNMENT_BY_HASH(IN i_participant VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    SET v_task_id = TO_HASH(SUBSTR(i_participant, 1, LOCATE(':', i_participant)-1));
    SET v_user_id = TO_HASH(SUBSTR(i_participant, LOCATE(':', i_participant)+1));

    CALL GET_ASSIGNMENT_BY_ID(v_task_id, v_user_id); 
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Deletes an assignment
--

CREATE or REPLACE PROCEDURE DELETE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_user_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    CALL GET_USER_ID(i_user, v_user_id);

    DELETE FROM ASSIGNMENTS WHERE TASK_ID = v_task_id and USER_ID = v_user_id;
END;

CREATE or REPLACE PROCEDURE DELETE_ASSIGNMENTS(IN i_task VARCHAR(101))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);

    DELETE FROM ASSIGNMENTS WHERE TASK_ID = v_task_id;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return a list of expired tasks
--

CREATE OR REPLACE PROCEDURE ADMIN_GET_EXPIRED_TASKS(IN i_days INTEGER DEFAULT 1)
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.UPDATED
	    FROM TASKS T, USERS U
            WHERE T.UPDATED + i_days < CURRENT TIMESTAMP AND
            T.STATUS != 'COMPLETE' AND T.STATUS != 'FAILED' AND
            U.USER_ID = T.USER_ID
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new model
--

CREATE or REPLACE PROCEDURE ADD_MODEL(IN i_task VARCHAR(101), IN i_exid VARCHAR(251))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;
    DECLARE v_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);
    SET v_id = NEXT VALUE FOR MODEL_SEQ;

    INSERT INTO MODELS (MODEL_ID, TASK_ID, EXTERNAL_ID) VALUES (v_id, v_task_id, i_exid);

    INSERT INTO MODEL_ACL (MODEL_ID, USER_ID)
        SELECT M.MODEL_ID, A.USER_ID
            FROM MODELS M, ASSIGNMENTS A
            WHERE M.TASK_ID = v_task_id AND
            A.TASK_ID = M.TASK_ID;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return models
--

CREATE OR REPLACE PROCEDURE GET_MODELS()
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT M.MODEL_ID, M.EXTERNAL_ID, T.TASK_NAME, T.STATUS, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M
            WHERE M.TASK_ID = T.TASK_ID
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return model
--

CREATE OR REPLACE PROCEDURE GET_MODEL(IN i_task VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT M.MODEL_ID, M.EXTERNAL_ID, T.STATUS, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M
            WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID
            ORDER BY M.MODEL_ID;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return model ACL
--

CREATE OR REPLACE PROCEDURE GET_MODEL_ACL(IN i_task VARCHAR(101))
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT M.EXTERNAL_ID, A.USER_ID
            FROM TASKS T, MODELS M, MODEL_ACL A
            WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID AND
            A.MODEL_ID = M.MODEL_ID;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Deletes a model
--

CREATE or REPLACE PROCEDURE DELETE_MODEL(IN i_task VARCHAR(101))
LANGUAGE SQL
BEGIN
    DECLARE v_task_id INTEGER;

    CALL GET_TASK_ID(i_task, v_task_id);

    DELETE FROM MODELS WHERE TASK_ID = v_task_id;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts some test data
--

call ADD_USER('TEST-USER-0', 'org1');
call ADD_USER('TEST-USER-1', 'org2');
call ADD_USER('TEST-USER-2', 'org3');
call ADD_TASK('TEST-TASK-1', 'TEST-USER-0', 'STAR', '{"quorum":0}');
call ADD_TASK('TEST-TASK-2', 'TEST-USER-0', 'STAR', '{"quorum":0}');

call ADD_ASSIGNMENT('TEST-TASK-1', 'TEST-USER-1', 'T1-U1-QUEUE');
call ADD_ASSIGNMENT('TEST-TASK-1', 'TEST-USER-2', 'T1-U2-QUEUE');
call ADD_ASSIGNMENT('TEST-TASK-2', 'TEST-USER-2', 'T1-U2-QUEUE2');

-----------------------------------------------------------------------------
