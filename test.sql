DECLARE
    RES RESULTSET ;
BEGIN
    show procedures in database ADMIN_UTILITIES;
    RES :=
        (select "catalog_name", "schema_name", "name","description"
        from table(result_scan(last_query_id()))
        where "schema_name" = 'LOCAL_ADMIN_UTILITES');
    RETURN TABLE(RES);
END;


DECLARE
    RES RESULTSET ;
BEGIN
    show tasks in database ADMIN_UTILITIES;
    RES :=
        (select "database_name", "schema_name", "name","definition"
        from table(result_scan(last_query_id()))
        where "schema_name" = 'LOCAL_ADMIN_UTILITES');
    RETURN TABLE(RES);
END;
