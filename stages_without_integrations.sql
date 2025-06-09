select * 
from snowflake.account_usage.stages
where stage_type = 'External Named'
and storage_integration is null
and deleted is null;
