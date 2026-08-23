\set ON_ERROR_STOP on
\conninfo

BEGIN TRANSACTION READ ONLY;
SELECT current_database(), current_user, current_schema;
SELEC deliberate_syntax_error;
COMMIT;
