-- V6 - Task Status and filtering
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET CURRENT SCHEMA ${schema_name};
SET CURRENT PATH = SYSTEM PATH, ${schema_name};

DROP PROCEDURE GET_TASKS;

ALTER TABLE TASKS DROP CONSTRAINT TASK_STATUS;
ALTER TABLE ASSIGNMENTS DROP CONSTRAINT ASSIGNMENT_STATUS;

ALTER TABLE TASKS ADD CONSTRAINT TASK_STATUS CHECK (STATUS IN ('CREATED', 'PENDING', 'STARTED', 'FAILED', 'COMPLETE'));
ALTER TABLE ASSIGNMENTS ADD CONSTRAINT ASSIGNMENT_STATUS CHECK (STATUS IN ('CREATED', 'PENDING', 'STARTED', 'FAILED', 'COMPLETE'));

-----------------------------------------------------------------------------
--Return all tasks with option to omit of certain status
--

CREATE OR REPLACE PROCEDURE GET_TASKS(IN i_status VARCHAR(21) DEFAULT '')
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            WHERE T.STATUS != i_status
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Return all tasks of open status
--

CREATE OR REPLACE PROCEDURE GET_OPEN_TASKS()
LANGUAGE SQL
DYNAMIC RESULT SETS 1
BEGIN
    DECLARE cur CURSOR WITH RETURN TO CLIENT FOR
        SELECT T.TASK_NAME, T.STATUS, TO_UTC(T.ADDED) AS ADDED,
            T.TOPOLOGY, T.DEFINITION
            FROM TASKS T
            WHERE T.STATUS NOT IN ('FAILED', 'COMPLETE')
            ORDER BY T.TASK_NAME;
    OPEN cur;
END;

-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--Trigger to set task to pending after a task join
--

CREATE OR REPLACE TRIGGER UPDATE_TASK_PENDING 
    AFTER INSERT ON ASSIGNMENTS
    REFERENCING OLD ROW AS OLD NEW ROW AS NEW
    FOR EACH ROW MODE DB2SQL
BEGIN
    UPDATE TASKS SET STATUS = 'PENDING' WHERE TASK_ID = NEW.TASK_ID;
END;

-----------------------------------------------------------------------------
