-- V6 - Task Status and filtering
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET schema '${schema_name}';
--SET CURRENT SCHEMA ${schema_name};
--SET CURRENT PATH = SYSTEM PATH, ${schema_name};

DROP FUNCTION GET_TASKS;

ALTER TABLE TASKS DROP CONSTRAINT TASK_STATUS;
ALTER TABLE ASSIGNMENTS DROP CONSTRAINT ASSIGNMENT_STATUS;

ALTER TABLE TASKS ADD CONSTRAINT TASK_STATUS CHECK (STATUS IN ('CREATED', 'PENDING', 'STARTED', 'FAILED', 'COMPLETE'));
ALTER TABLE ASSIGNMENTS ADD CONSTRAINT ASSIGNMENT_STATUS CHECK (STATUS IN ('CREATED', 'PENDING', 'STARTED', 'FAILED', 'COMPLETE'));

-----------------------------------------------------------------------------
--Return all tasks with option to omit of certain status
--

CREATE OR REPLACE FUNCTION GET_TASKS(IN i_status varchar default '')
RETURNS TABLE(task_name varchar, status varchar, added varchar, topology varchar, definition varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            WHERE T.STATUS != i_status
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return all tasks of open status
--
CREATE OR REPLACE FUNCTION GET_OPEN_TASKS()
RETURNS TABLE(task_name varchar, status varchar, added varchar, topology varchar, definition varchar)
AS $$
    SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            WHERE T.STATUS NOT IN ('FAILED', 'COMPLETE')
            ORDER BY T.TASK_NAME;
$$ LANGUAGE SQL;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Trigger to set task to pending after a task join
--
CREATE OR REPLACE FUNCTION UPDATE_TASK_PENDING() RETURNS TRIGGER
AS $$
BEGIN 
    UPDATE TASKS SET STATUS = 'PENDING' WHERE TASK_ID = NEW.TASK_ID;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER UPDATE_TASK_PENDING_TRIGGER
    AFTER INSERT ON ASSIGNMENTS
    REFERENCING NEW TABLE AS NEW
    FOR EACH ROW EXECUTE FUNCTION UPDATE_TASK_PENDING();

