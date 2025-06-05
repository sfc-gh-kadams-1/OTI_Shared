--https://community.snowflake.com/s/article/Can-Snowflake-system-functions-be-used-in-Stored-Procedures

-- Setup the variables used to configure the solution.
SET MY_ADMIN_DB = 'ADMIN_UTILITIES';
SET MY_ADMIN_SCHEMA = $MY_ADMIN_DB || '.' || 'LOCAL_ADMIN_UTILITES';
SET MY_BUNDLEADMIN_ROLE = 'BUNDLEADMIN';


USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS identifier($MY_ADMIN_DB);
USE DATABASE identifier($MY_ADMIN_DB);
CREATE SCHEMA IF NOT EXISTS identifier($MY_ADMIN_SCHEMA);
USE SCHEMA identifier($MY_ADMIN_SCHEMA);
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS identifier($MY_BUNDLEADMIN_ROLE);
GRANT ROLE identifier($MY_BUNDLEADMIN_ROLE) TO ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE identifier($MY_ADMIN_DB) TO ROLE identifier($MY_BUNDLEADMIN_ROLE);
GRANT USAGE ON SCHEMA identifier($MY_ADMIN_SCHEMA) TO ROLE identifier($MY_BUNDLEADMIN_ROLE);


use database identifier($MY_ADMIN_DB);
use schema identifier($MY_ADMIN_SCHEMA);

--create procedure to check status of behavior change bundles
CREATE OR REPLACE PROCEDURE BEHAVIOR_CHANGE_BUNDLE_STATUS(bundle_name varchar)
returns varchar
language sql
execute as owner
as
$$
begin
    let res varchar := (select SYSTEM$BEHAVIOR_CHANGE_BUNDLE_STATUS(:bundle_name));
    return :res;
end;
$$
;

ALTER PROCEDURE BEHAVIOR_CHANGE_BUNDLE_STATUS(varchar)
SET COMMENT = 
$$
PROCEUDRE:BEHAVIOR_CHANGE_BUNDLE_STATUS
ARGUEMENTS: BUNDLE_NAME VARCHAR: The name of the bundle change for which status is desired.

Returns the status of the specified behavior change release bundle for the current account.
Returns one of the following VARCHAR values:

ENABLED (if the specified bundle is enabled for the current account)

DISABLED (if the specified bundle is disabled for the current account)

RELEASED (if the specified bundle is generally enabled for the current account and thus permanently enabled)

BUNDLE CHANGE MANAGEMNT DOCUMENTATION: https://docs.snowflake.com/en/release-notes/bcr-bundles/2025_03_bundle

USAGE EXAMPLE: CALL BEHAVIOR_CHANGE_BUNDLE_STATUS('2025_03'); 

$$;


GRANT USAGE ON PROCEDURE BEHAVIOR_CHANGE_BUNDLE_STATUS(VARCHAR) TO ROLE identifier($MY_BUNDLEADMIN_ROLE);


--sample usage
CALL BEHAVIOR_CHANGE_BUNDLE_STATUS('2025_09'); 

--create a job that creates tasks for enableing and disabling behavior changes 
CREATE OR REPLACE TASK task_create_bundle_management_tasks
  SCHEDULE = 'USING CRON 0 4 1 * * America/Chicago'  --on the first day of the month at 4 AM
   SERVERLESS_TASK_MAX_STATEMENT_SIZE='XSMALL'
AS
BEGIN
  LET MSG_ARRAY ARRAY := ARRAY_CONSTRUCT();
  LET ERROR_ARRAY ARRAY:= ARRAY_CONSTRUCT();
  LET OUTPUT VARCHAR default '';  
  LET DDL_STATEMENT VARCHAR;
  LET CUR CURSOR FOR (
          WITH as_of_date as (
            SELECT dateadd(month,-6,current_date()) START_DATE
        )
        ,bundle_releases as (
            SELECT DATEADD(MONTH, seq4() + 1, A.START_DATE) RELEASE_MONTH, TO_CHAR(DATEADD(MONTH, seq4() + 1, A.START_DATE),'YYYY_MM') bundle_release 
            FROM table(generator(ROWCOUNT => 12)) X
            CROSS JOIN as_of_date 
            ) 
            SELECT 
                  'CREATE TASK IF NOT EXISTS TSK_ENABLE_BUNDLE_' || BUNDLE_RELEASE ||  ' SERVERLESS_TASK_MAX_STATEMENT_SIZE=''XSMALL'' AS 
                        CALL SYSTEM$ENABLE_BEHAVIOR_CHANGE_BUNDLE(''' || BUNDLE_RELEASE || ''');' 
            FROM bundle_releases
            UNION ALL 
            SELECT 
                  'CREATE TASK IF NOT EXISTS TSK_DISABLE_BUNDLE_' || BUNDLE_RELEASE ||  ' SERVERLESS_TASK_MAX_STATEMENT_SIZE=''XSMALL'' AS CALL SYSTEM$DISABLE_BEHAVIOR_CHANGE_BUNDLE(''' || BUNDLE_RELEASE || ''');' 
            FROM bundle_releases
            UNION ALL 
            SELECT 
                  'GRANT OPERATE ON TASK TSK_ENABLE_BUNDLE_' || BUNDLE_RELEASE || ' TO ROLE ' || $MY_BUNDLEADMIN_ROLE || '; '
            FROM bundle_releases            
            UNION ALL 
            SELECT 
                  'GRANT OPERATE ON TASK TSK_DISABLE_BUNDLE_' || BUNDLE_RELEASE || ' TO ROLE ' || $MY_BUNDLEADMIN_ROLE || ';' 
            FROM bundle_releases
            );
  FOR ROW_VARIABLE IN CUR DO
     BEGIN
      --GET THE DDL AND EXECUTE IT TO CREATE THE VIEW
      DDL_STATEMENT := ROW_VARIABLE.DDL;
      EXECUTE IMMEDIATE (:DDL_STATEMENT);
      OUTPUT := 'EXECUTED: ' || :DDL_STATEMENT;
      MSG_ARRAY := ARRAY_APPEND(MSG_ARRAY, :OUTPUT );

             EXCEPTION  -- LOG ERRORS
             WHEN STATEMENT_ERROR THEN
              LET ERRM := SQLERRM;
              ERROR_ARRAY := ARRAY_APPEND(ERROR_ARRAY, 'ERROR EXECUTING: ' ||:DDL_STATEMENT ||'.  ERROR MESSAGE: '||  :ERRM );
       
             WHEN EXPRESSION_ERROR THEN
              LET ERRM := SQLERRM;
              ERROR_ARRAY := ARRAY_APPEND(ERROR_ARRAY, 'ERROR EXECUTING: ' ||:DDL_STATEMENT ||'.  ERROR MESSAGE: '||  :ERRM );
       
              WHEN OTHER THEN
              LET ERRM := SQLERRM;
              ERROR_ARRAY := ARRAY_APPEND(ERROR_ARRAY, 'ERROR EXECUTING: ' ||:DDL_STATEMENT ||'.  ERROR MESSAGE: '||  :ERRM );
        END;

   END FOR;
 RETURN ARRAY_CAT( MSG_ARRAY , ERROR_ARRAY); 
END;

--sample execution
CALL BEHAVIOR_CHANGE_BUNDLE_STATUS('2025_03'); 
EXECUTE TASK TSK_DISABLE_BUNDLE_2025_03;
CALL BEHAVIOR_CHANGE_BUNDLE_STATUS('2025_03'); 
EXECUTE TASK TSK_ENABLE_BUNDLE_2025_03;
CALL BEHAVIOR_CHANGE_BUNDLE_STATUS('2025_03'); 






