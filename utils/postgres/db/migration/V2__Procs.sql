-- V2 - Add stored procedures
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

--TODO
SET schema '${schema_name}';
--SET CURRENT SCHEMA ${schema_name};
--SET CURRENT PATH = SYSTEM PATH, ${schema_name};

-----------------------------------------------------------------------------
--Inserts new user
--

CREATE or REPLACE FUNCTION ADD_USER(IN i_name VARCHAR(101), IN i_org VARCHAR(501)) RETURNS VOID
AS $$

    DECLARE v_id INTEGER;
BEGIN
    v_id := NEXTVAL('USER_SEQ');
    INSERT INTO USERS (USER_ID, USER_NAME, ORGANISATION) VALUES (v_id, i_name, i_org);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Deletes a user
--

CREATE or REPLACE FUNCTION DELETE_USER(IN i_name VARCHAR(101)) RETURNS VOID
AS $$
BEGIN
    DELETE FROM USERS WHERE USER_NAME = i_name;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Return user id
--

CREATE OR REPLACE FUNCTION GET_USER_ID(IN i_user VARCHAR(101), OUT i_user_id INTEGER) RETURNS INTEGER
AS $$
BEGIN
    SELECT USER_ID INTO i_user_id FROM USERS WHERE USER_NAME = i_user;

    IF (i_user_id IS NULL) THEN
        RAISE EXCEPTION 'User not found';
    END IF;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Inserts new task
--

CREATE or REPLACE FUNCTION ADD_TASK(IN i_name VARCHAR(101),
                                     IN i_user VARCHAR(101),
                                     IN i_topology VARCHAR(101),
                                     IN i_definition VARCHAR(5000) DEFAULT NULL) RETURNS VOID
AS $$

    DECLARE v_id INTEGER;
    DECLARE v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;
    v_id := NEXTVAL('TASK_SEQ');

    INSERT INTO TASKS (TASK_ID, USER_ID, TASK_NAME, TOPOLOGY, DEFINITION)
        VALUES (v_id, v_user_id, i_name, i_topology, i_definition);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Deletes a task
--

CREATE or REPLACE FUNCTION DELETE_TASK(IN i_name VARCHAR(101)) RETURNS VOID
AS $$
BEGIN
    DELETE FROM TASKS WHERE TASK_NAME = i_name;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Return task id
--

CREATE OR REPLACE FUNCTION GET_TASK_ID(IN i_task VARCHAR(101), OUT i_task_id INTEGER) RETURNS INTEGER
AS $$
BEGIN
    SELECT TASK_ID INTO i_task_id FROM TASKS WHERE TASK_NAME = i_task;

    IF (i_task_id IS NULL) THEN
        RAISE EXCEPTION 'Task not found';
    END IF;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Updates a task
--

CREATE or REPLACE FUNCTION ADMIN_UPDATE_TASK(IN i_name VARCHAR(101),
                                              IN i_status VARCHAR(21),
                                              IN i_queue VARCHAR(101) DEFAULT NULL) RETURNS VOID
AS $$
BEGIN
    UPDATE TASKS SET STATUS=i_status, QUEUE=i_queue
        WHERE TASK_NAME=i_name;
END;
$$ LANGUAGE plpgsql;

CREATE or REPLACE FUNCTION UPDATE_TASK(IN i_name VARCHAR(101),
                                        IN i_topology VARCHAR(101),
                                        IN i_definition VARCHAR(5000) DEFAULT NULL,
                                        IN i_status VARCHAR(21) DEFAULT NULL) RETURNS VOID
AS $$
BEGIN
    UPDATE TASKS SET STATUS=i_status, TOPOLOGY=i_topology, DEFINITION=i_definition
        WHERE TASK_NAME=i_name;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Return all users
--

CREATE OR REPLACE FUNCTION GET_USERS() RETURNS TABLE(user_name varchar, organisation varchar)
AS $$
    SELECT U.USER_NAME, U.ORGANISATION FROM USERS U
               ORDER BY U.USER_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------
--Return an assignment hash of task id and user id
--

CREATE or REPLACE FUNCTION TO_HASH(input INTEGER) RETURNS INTEGER
AS $$
BEGIN
    RETURN ((65535 & input) * power(2, 16)) + ((4294901760 & input) / power(2, 16));
END;
$$ LANGUAGE plpgsql;

CREATE or REPLACE FUNCTION ASSIGNMENT_HASH(task_id INTEGER, user_id INTEGER) RETURNS VARCHAR(51)
AS $$
BEGIN
    RETURN CONCAT(cast(TO_HASH(task_id) as varchar), ':', cast(TO_HASH(user_id) as varchar));
END;
$$ LANGUAGE plpgsql;


-----------------------------------------------------------------------------
--Return an ISO 8601 time

CREATE or REPLACE FUNCTION TO_UTC(ts TIMESTAMP) RETURNS VARCHAR(51)
AS $$
BEGIN
    RETURN CONCAT(REPLACE(TO_CHAR(ts, 'YYYY-MM-DD HH24:MI:SS.MS'), ' ', 'T'), 'Z');
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------
--Return task
--

CREATE OR REPLACE FUNCTION ADMIN_GET_TASK_INFO(IN i_task VARCHAR(101))
RETURNS TABLE(task_name varchar, user_name varchar, status varchar, queue varchar, topology varchar, definition varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED 
            FROM TASKS T, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_ID = T.USER_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_TASK_CREATION_INFO(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(task_name varchar, user_name varchar, status varchar, queue varchar, topology varchar, definition varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED 
            FROM TASKS T, USERS U
            WHERE T.TASK_NAME = i_task AND
            U.USER_NAME = i_user AND
            T.USER_ID = U.USER_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_USER_TASKS(IN i_user VARCHAR(101))
RETURNS TABLE(task_name varchar, status varchar, queue varchar, topology varchar, definition varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS, T.QUEUE, T.TOPOLOGY, T.DEFINITION,
            TO_UTC(T.ADDED) AS ADDED, TO_UTC(T.UPDATED) AS UPDATED
            FROM TASKS T, USERS U
            WHERE U.USER_NAME = i_user AND
            T.USER_ID = U.USER_ID
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------
--Return all tasks
--

CREATE OR REPLACE FUNCTION GET_TASKS()
RETURNS TABLE(task_name varchar, status varchar, added varchar, topology varchar, definition varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return a users participation
--
CREATE OR REPLACE FUNCTION GET_ASSIGNMENTS_BY_ID(IN i_user_id INTEGER)
RETURNS TABLE(task_name varchar, tstatus varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS AS TSTATUS, A.QUEUE, A.STATUS AS STATUS, 
            TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A, TASKS T
            WHERE A.USER_ID = i_user_id AND
            T.TASK_ID = A.TASK_ID 
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_ASSIGNMENTS(IN i_user VARCHAR(101))
RETURNS TABLE(task_name varchar, tstatus varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS AS TSTATUS, A.QUEUE, A.STATUS AS STATUS, 
            TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A, TASKS T, USERS U
            WHERE U.USER_NAME = i_user AND
            A.USER_ID = U.USER_ID AND
            T.TASK_ID = A.TASK_ID 
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return participants for a task
--
CREATE OR REPLACE FUNCTION ADMIN_GET_TASK_ASSIGNMENTS(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(user_name varchar, queue varchar, status varchar, participant varchar, added varchar, updated varchar)
AS $$
    SELECT U.USER_NAME, A.QUEUE, A.STATUS, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
           TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
           FROM TASKS T, ASSIGNMENTS A, USERS U
           WHERE T.TASK_ID IN
              (SELECT T.TASK_ID FROM TASKS T, USERS U
                    WHERE U.USER_NAME = i_user AND T.USER_ID = U.USER_ID AND T.TASK_NAME = i_task) AND
           A.TASK_ID = T.TASK_ID AND
           U.USER_ID = A.USER_ID
           ORDER BY A.ADDED;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION GET_TASK_ASSIGNMENTS(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(status varchar, participant varchar, added varchar, updated varchar)
AS $$
    SELECT A.STATUS, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
            TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM TASKS T, ASSIGNMENTS A
            WHERE T.TASK_ID IN 
                (SELECT T.TASK_ID FROM TASKS T, USERS U
                    WHERE U.USER_NAME = i_user AND T.USER_ID = U.USER_ID AND T.TASK_NAME = i_task) AND
            A.TASK_ID = T.TASK_ID
            ORDER BY A.ADDED;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return participants for all tasks - admin only
--
CREATE OR REPLACE FUNCTION GET_ALL_ASSIGNMENTS()
RETURNS TABLE(task_name varchar, user_name varchar, participant varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, U.USER_NAME, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
               A.QUEUE, A.STATUS, TO_UTC(T.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM TASKS T, USERS U, ASSIGNMENTS A
            WHERE A.TASK_ID = T.TASK_ID AND
            U.USER_ID = A.USER_ID
            ORDER BY T.TASK_NAME, U.USER_NAME, T.ADDED;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new task participant
--
CREATE or REPLACE FUNCTION ADD_ASSIGNMENT(IN i_task VARCHAR(101),
                                           IN i_user VARCHAR(101),
                                           IN i_queue VARCHAR(101)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;

    INSERT INTO ASSIGNMENTS (TASK_ID, USER_ID, QUEUE) VALUES (v_task_id, v_user_id, i_queue);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Updates an assignment
--
CREATE or REPLACE FUNCTION UPDATE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101),
                                              IN i_status VARCHAR(21)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;

    UPDATE ASSIGNMENTS SET STATUS=i_status WHERE TASK_ID = v_task_id and USER_ID = v_user_id;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Retrieves assignment details
--
CREATE OR REPLACE FUNCTION GET_ASSIGNMENT_BY_ID(IN i_task_id INTEGER, IN i_user_id INTEGER)
RETURNS TABLE(task_id varchar, user_id varchar, participant varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT A.TASK_ID, A.USER_ID, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
               A.QUEUE, A.STATUS, TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A
            WHERE A.TASK_ID = i_task_id AND
            A.USER_ID = i_user_id;
$$ LANGUAGE SQL;

CREATE or REPLACE FUNCTION GET_ASSIGNMENT(IN i_task VARCHAR(101), IN i_user VARCHAR(101))
RETURNS TABLE(task_id varchar, user_id varchar, participant varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT A.TASK_ID, A.USER_ID, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
            A.QUEUE, A.STATUS, TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A, TASKS T, USERS U
            WHERE T.TASK_NAME = i_task AND 
            U.USER_NAME = i_user AND
            A.TASK_ID = T.TASK_ID AND
            A.USER_ID = U.USER_ID;
$$ LANGUAGE SQL;

CREATE or REPLACE FUNCTION GET_ASSIGNMENT_BY_HASH(IN i_participant VARCHAR(101))
RETURNS TABLE(task_id varchar, user_id varchar, participant varchar, queue varchar, status varchar, added varchar, updated varchar)
AS $$
    SELECT A.TASK_ID, A.USER_ID, ASSIGNMENT_HASH(A.TASK_ID, A.USER_ID) AS PARTICIPANT,
               A.QUEUE, A.STATUS, TO_UTC(A.ADDED) AS ADDED, TO_UTC(A.UPDATED) AS UPDATED
            FROM ASSIGNMENTS A 
            WHERE
            A.TASK_ID = TO_HASH(CAST(SUBSTR(i_participant, 1, POSITION(':' IN i_participant)-1) AS INTEGER)) AND
            A.USER_ID = TO_HASH(CAST(SUBSTR(i_participant, POSITION(':' IN i_participant)+1) AS INTEGER));
$$ LANGUAGE SQL;

CREATE or REPLACE FUNCTION DELETE_ASSIGNMENT(IN i_task VARCHAR(101),
                                              IN i_user VARCHAR(101)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_user_id INTEGER;
BEGIN
 
    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;

    DELETE FROM ASSIGNMENTS WHERE TASK_ID = v_task_id and USER_ID = v_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE or REPLACE FUNCTION DELETE_ASSIGNMENTS(IN i_task VARCHAR(101)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;

    DELETE FROM ASSIGNMENTS WHERE TASK_ID = v_task_id;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return a list of expired tasks
--
CREATE OR REPLACE FUNCTION ADMIN_GET_EXPIRED_TASKS(IN i_days INTERVAL DEFAULT '1 day')
RETURNS TABLE(task_name varchar, user_name varchar, status varchar, updated varchar)
AS $$
    SELECT T.TASK_NAME, U.USER_NAME, T.STATUS, T.UPDATED
	    FROM TASKS T, USERS U
            WHERE T.UPDATED + i_days < CURRENT_TIMESTAMP AND
            T.STATUS != 'COMPLETE' AND T.STATUS != 'FAILED' AND
            U.USER_ID = T.USER_ID
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new model
--

CREATE or REPLACE FUNCTION ADD_MODEL(IN i_task VARCHAR(101), IN i_exid VARCHAR(251)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
    v_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;
    v_id := NEXTVAL('MODEL_SEQ');

    INSERT INTO MODELS (MODEL_ID, TASK_ID, EXTERNAL_ID) VALUES (v_id, v_task_id, i_exid);

    INSERT INTO MODEL_ACL (MODEL_ID, USER_ID)
        SELECT M.MODEL_ID, A.USER_ID
            FROM MODELS M, ASSIGNMENTS A
            WHERE M.TASK_ID = v_task_id AND
            A.TASK_ID = M.TASK_ID;
END;
$$ LANGUAGE plpgsql;

--Return models
--

CREATE OR REPLACE FUNCTION GET_MODELS()
RETURNS TABLE(model_id varchar, external_id varchar, task_name varchar, status varchar, added varchar)
AS $$
    SELECT M.MODEL_ID, M.EXTERNAL_ID, T.TASK_NAME, T.STATUS, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M
            WHERE M.TASK_ID = T.TASK_ID
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

--Return model
--

CREATE OR REPLACE FUNCTION GET_MODEL(IN i_task VARCHAR(101))
RETURNS TABLE(model_id varchar, external_id varchar, status varchar, added varchar)
AS $$
    SELECT M.MODEL_ID, M.EXTERNAL_ID, T.STATUS, TO_UTC(M.ADDED) AS ADDED
            FROM TASKS T, MODELS M
            WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID
            ORDER BY M.MODEL_ID;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return model ACL
--
CREATE OR REPLACE FUNCTION GET_MODEL_ACL(IN i_task VARCHAR(101))
RETURNS TABLE(external_id varchar, user_id varchar)
AS $$
    SELECT M.EXTERNAL_ID, A.USER_ID
            FROM TASKS T, MODELS M, MODEL_ACL A
            WHERE T.TASK_NAME = i_task AND
            M.TASK_ID = T.TASK_ID AND
            A.MODEL_ID = M.MODEL_ID;
$$ LANGUAGE SQL;

--Deletes a model
--

CREATE or REPLACE FUNCTION DELETE_MODEL(IN i_task VARCHAR(101)) RETURNS VOID
AS $$

    DECLARE v_task_id INTEGER;
BEGIN

    SELECT * FROM GET_TASK_ID(i_task) INTO v_task_id;

    DELETE FROM MODELS WHERE TASK_ID = v_task_id;
END;
$$ LANGUAGE plpgsql;


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts some test data
--
select ADD_USER('TEST-USER-0', 'org1');
select ADD_USER('TEST-USER-1', 'org2');
select ADD_USER('TEST-USER-2', 'org3');
select ADD_TASK('TEST-TASK-1', 'TEST-USER-0', 'STAR', '{"quorum":0}');
select ADD_TASK('TEST-TASK-2', 'TEST-USER-0', 'STAR', '{"quorum":0}');

select ADD_ASSIGNMENT('TEST-TASK-1', 'TEST-USER-1', 'T1-U1-QUEUE');
select ADD_ASSIGNMENT('TEST-TASK-1', 'TEST-USER-2', 'T1-U2-QUEUE');
select ADD_ASSIGNMENT('TEST-TASK-2', 'TEST-USER-2', 'T1-U2-QUEUE2');

--select GET_ASSIGNMENTS('TEST-USER-2');


-----------------------------------------------------------------------------

