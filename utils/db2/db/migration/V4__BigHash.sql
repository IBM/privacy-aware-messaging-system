-- V4 - Fix hash cast
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET CURRENT SCHEMA ${schema_name};
SET CURRENT PATH = SYSTEM PATH, ${schema_name};

DROP FUNCTION TO_HASH;

-----------------------------------------------------------------------------
--Return an assignment hash of task id and user id
--

CREATE or REPLACE FUNCTION TO_HASH(input INTEGER)
RETURNS INTEGER
RETURN (BIGINT(65535 & input) * power(2, 16)) + (BIGINT(4294901760 & input) / power(2, 16));

-----------------------------------------------------------------------------
