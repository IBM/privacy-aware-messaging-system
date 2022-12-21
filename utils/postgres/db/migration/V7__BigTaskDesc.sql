-- V7 - Increase task definition size
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET schema '${schema_name}';
--SET CURRENT SCHEMA ${schema_name};
--SET CURRENT PATH = SYSTEM PATH, ${schema_name};

ALTER TABLE TASKS
ALTER COLUMN DEFINITION
SET DATA TYPE VARCHAR(20000);

DROP FUNCTION ADD_TASK;
DROP FUNCTION UPDATE_TASK;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Inserts new task
--Same as V2, just up to 20k for definition

CREATE or REPLACE FUNCTION ADD_TASK(IN i_name VARCHAR(101),
                                     IN i_user VARCHAR(101),
                                     IN i_topology VARCHAR(101),
                                     IN i_definition VARCHAR(20000) DEFAULT NULL) RETURNS VOID
AS $$

    DECLARE v_id INTEGER;
    v_user_id INTEGER;
BEGIN

    SELECT * FROM GET_USER_ID(i_user) INTO v_user_id;
    v_id := NEXTVAL('TASK_SEQ');

    INSERT INTO TASKS (TASK_ID, USER_ID, TASK_NAME, TOPOLOGY, DEFINITION)
        VALUES (v_id, v_user_id, i_name, i_topology, i_definition);
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Updates a task
--Same as V2, just up to 20k for definition

CREATE or REPLACE FUNCTION UPDATE_TASK(IN i_name VARCHAR(101),
                                        IN i_topology VARCHAR(101),
                                        IN i_definition VARCHAR(20000) DEFAULT NULL,
                                        IN i_status VARCHAR(21) DEFAULT NULL) RETURNS VOID
AS $$
BEGIN
    UPDATE TASKS SET STATUS=i_status, TOPOLOGY=i_topology, DEFINITION=i_definition
        WHERE TASK_NAME=i_name;
END;
$$ LANGUAGE plpgsql;

