\set ON_ERROR_STOP on
\conninfo

SELECT current_database() AS database_name,
       current_user AS role_name,
       current_schema AS schema_name,
       current_setting('server_version_num') AS server_version_num,
       current_setting('search_path') AS search_path;

\dn
\dt factorycare.*

BEGIN TRANSACTION READ ONLY;
SELECT current_database() AS database_name,
       current_user AS role_name,
       current_schema AS schema_name;
COMMIT;
