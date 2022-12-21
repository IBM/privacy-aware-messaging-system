-- V5 - BigInt cast
-- Author: Mark Purcell (markpurcell@ie.ibm.com)

SET schema '${schema_name}';

DROP FUNCTION TO_HASH;

CREATE or REPLACE FUNCTION TO_HASH(input BIGINT) RETURNS BIGINT
AS $$
DECLARE
   v_one BIGINT;
   v_two BIGINT;
BEGIN
    SELECT CAST((65535 & input) AS BIGINT) INTO v_one;
    SELECT CAST((4294901760 & input) AS BIGINT) INTO v_two;
    RETURN ((v_one * power(2, 16)) + (v_two / power(2, 16)));
END;
$$ LANGUAGE plpgsql;
