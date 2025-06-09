--SELF-SERVICE PROCS TO GRANT/REVOKE PRIVILEGES AND GRANTS 
--All code provided is representative examples.  Please harden as required to meet existing development, security and SDLC guidelines/standards.
SET ROLE_NM = 'LOCAL_ADMIN'; ------UPDATE to local admin role name 
SET CURRENTUSER =  CURRENT_USER();


--using a role with manage grants privileges (SECURITYADMIN, ACCOUNTADMIN OR A CUSTOME ROLE WITH MANAGE GRANTS PRIVILEGES)
CREATE DATABASE IF NOT EXISTS ADMIN_UTILITIES;
CREATE  SCHEMA  IF NOT EXISTS ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES;


USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS GRANTS_MANAGER;
GRANT USAGE ON DATABASE  ADMIN_UTILITIES TO ROLE GRANTS_MANAGER;
GRANT USAGE ON SCHEMA ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES TO ROLE GRANTS_MANAGER;
GRANT CREATE PROCEDURE ON SCHEMA ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES TO ROLE GRANTS_MANAGER; 
GRANT MANAGE GRANTS ON ACCOUNT TO ROLE GRANTS_MANAGER; 
GRANT ROLE GRANTS_MANAGER TO USER IDENTIFIER($CURRENTUSER);

USE ROLE GRANTS_MANAGER;
USE DATABASE  ADMIN_UTILITIES;
USE SCHEMA    LOCAL_ADMIN_UTILITES;


--CREATE PROCEDURE FOR GRANTING PRIVILEGES TO ROLES
CREATE OR REPLACE  PROCEDURE  ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES.MANAGE_GRANTS(GRANT_STATEMENT VARCHAR) 
RETURNS VARCHAR  NOT NULL
LANGUAGE SQL
EXECUTE AS   OWNER
AS
$$
DECLARE
    GRANT_EXCEPTION EXCEPTION (-20002,'NOT AUTHORIZED TO GRANT TO OR REVOKE FROM SYSTEM ROLES OR OTHER ELEVATED ROLES');
    GRANT_SCOPE_EXCEPTION EXCEPTION (-20002,'NOT AUTHORIZED TO GRANT THIS GLOBAL PRIVILEGE ON ACCOUNT');
    GRANT_UTILITIES_EXCEPTION EXCEPTION (-20002,'NOT AUTHORIZED TO PRIVILEGES ON ADMIN_UTILITES');
    GRANT_STATEMENT_RETURN VARCHAR DEFAULT '';
 BEGIN
--block granting sysem roles or roles with manage grants privileges
  IF (GRANT_STATEMENT  ILIKE ANY('%ACCOUNTADMIN%','%SYSADMIN%','%SECURITYADMIN%','%USERADMIN%','%GLOBALORGADMIN%','%ORGADMIN%','%GRANTS_MANAGER%')) THEN
    RAISE GRANT_EXCEPTION; 
--block granting privileges on specified databases owned by accountadmins
  ELSEIF (GRANT_STATEMENT ILIKE  '%ADMIN_UTILITES%') THEN
    RAISE GRANT_UTILITIES_EXCEPTION;    
--block grants of global privileges on account except those explicitly allowed below
  ELSEIF (GRANT_STATEMENT ILIKE  '% ACCOUNT %' AND 
    NOT GRANT_STATEMENT  ILIKE ANY(
        '%APPLY%AGGREGATION%POLICY%',
        '%APPLY%AUTHENTICATION%POLICY%',
        '%APPLY%MASKING%POLICY%',
        '%APPLY%ROW%ACCESS%POLICY%',
        '%APPLY%SESSION%POLICY%',
        '%APPLY%PACKAGES%POLICY%',
        '%APPLY%PROJECTION%POLICY%',
        '%APPLY%TAG%',
        '%ATTACH%POLICY%',
        '%AUDIT%',
        '%CANCEL%QUERY%',
        '%CREATE%COMPUTE%POOL%',
        '%CREATE%API%INTEGRATION%',
        '%CREATE%APPLICATION%',
        '%CREATE%APPLICATION%PACKAGE%',
        '%CREATE%DATABASE%',%
        '%CREATE%EXTERNAL%VOLUME%',
        '%CREATE%INTEGRATION%',
        '%CREATE%ROLE%',
        '%CREATE%WAREHOUSE%',
        '%EXECUTE%ALERT%',
        '%EXECUTE%MANAGED%ALERT%',
        '%EXECUTE%MANAGED%TASK%',
        '%EXECUTE%TASK%',
        '%IMPORT%SHARE%',
        '%MANAGE%ACCOUNT%SUPPORT%CASES%',
        '%MANAGE%USER%SUPPORT%CASES%',
        '%MANAGE%WAREHOUSES%',
        '%MODIFY%LOG%LEVEL%',
        '%MODIFY%SESSION%LOG%LEVEL%',
        '%MODIFY%SESSION%TRACE%LEVEL%',
        '%MODIFY%TRACE%LEVEL%',
        '%MONITOR%',
        '%MONITOR%EXECUTION%',
        '%MONITOR%USAGE%',
        '%OVERRIDE%SHARE%RESTRICTIONS%',
        '%PURCHASE%DATA%EXCHANGE%LISTING%',
        '%RESOLVE%ALL%'
    ))
    THEN
    RAISE GRANT_SCOPE_EXCEPTION;    

  END IF;
    
    EXECUTE IMMEDIATE GRANT_STATEMENT;
    GRANT_STATEMENT_RETURN := 'STATEMENT COMPLETED:  '|| GRANT_STATEMENT ;
    
    RETURN :GRANT_STATEMENT_RETURN;

END;
$$;

ALTER PROCEDURE ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES.MANAGE_GRANTS(VARCHAR) 
SET COMMENT = 
$$PROCEDURE NAME: ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES.MANAGE_GRANTS(VARCHAR) 
PROCEDURE ARGUMENTS: GRANT_STATEMENT VARCHAR;  This is the grant or revoke statement to be executed. 
PROCEDURE PURPOSE: To allow local account administrators to manage grants within the account but prevent impacting Snowflake System roles.  
HOW PROCEDURE WORKS:  The procedure is executed with owner's rights.  
    The role that owns the procedude has a single privilege (outside of usage onthe database and schema whare the proc is located): MANAGE GRANTS.  
    The role can only execute grant and revoke statements.  Other statements passed to the procedure will fail. 
    The procedure prevents granting global pribvileges on the account.
    If the statement passed to the procedure contains any of the following strings the procedure will throw an error:
        ACCOUNTADMIN
        SYSADMIN
        SECURITYADMIN
        USERADMIN
        GLOBALORGADMIN
        ORGADMIN
        GRANTS_MANAGER
        ADMIN_UTILITES
       -- or --
        ON ACCOUNT plus any global privilege not including the following:
            APPLY AGGREGATION POLICY  
            APPLY AUTHENTICATION POLICY     
            APPLY MASKING POLICY  
            APPLY ROW ACCESS POLICY    
            APPLY SESSION POLICY  
            APPLY PACKAGES POLICY      
            APPLY PROJECTION POLICY  
            APPLY TAG   
            ATTACH POLICY  
            AUDIT         
            CANCEL QUERY  
            CREATE COMPUTE POOL        
            CREATE API INTEGRATION      
            CREATE APPLICATION  
            CREATE APPLICATION PACKAGE      
            CREATE DATABASE       
            CREATE EXTERNAL VOLUME    
            CREATE INTEGRATION    
            CREATE ROLE     
            CREATE WAREHOUSE  
            EXECUTE ALERT    
            EXECUTE MANAGED ALERT   
            EXECUTE MANAGED TASK      
            EXECUTE TASK   
            IMPORT SHARE   
            MANAGE ACCOUNT SUPPORT CASES        
            MANAGE USER SUPPORT CASES     
            MANAGE WAREHOUSES  
            MODIFY LOG LEVEL      
            MODIFY SESSION LOG LEVEL   
            MODIFY SESSION TRACE LEVEL      
            MODIFY TRACE LEVEL  
            MONITOR  
            MONITOR EXECUTION  
            MONITOR USAGE   
            OVERRIDE SHARE RESTRICTIONS  
            PURCHASE DATA EXCHANGE LISTING        
            RESOLVE ALL   
USAGE EXAMPLE:  CALL ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES.MANAGE_GRANTS('GRANT ALL ON DATABASE DB1 TO ROLE ANALYST');
$$;

GRANT USAGE ON PROCEDURE ADMIN_UTILITIES.LOCAL_ADMIN_UTILITES.MANAGE_GRANTS(VARCHAR) TO ROLE IDENTIFIER($ROLE_NM);



-----get list of local admin utilites and usage 
DECLARE
RES RESULTSET ;
BEGIN
    show procedures;
    RES :=
        (select "catalog_name", "schema_name", "name","description"
        from table(result_scan(last_query_id()))
        where "catalog_name" = 'ADMIN_UTILITIES'
        and "schema_name" = 'LOCAL_ADMIN_UTILITES');
    RETURN TABLE(RES);
END;
