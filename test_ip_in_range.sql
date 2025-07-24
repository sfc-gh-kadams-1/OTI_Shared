--creat function to determine if IP is conatined within any of the cidr ranhes supplied
CREATE OR REPLACE FUNCTION IS_IP_IN_CIDR_RANGES(
    ip_address_str STRING,
    cidr_ranges_str STRING
)
RETURNS BOOLEAN
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9' -- Or '3.10', '3.11', etc., based on Snowflake's supported versions
HANDLER = 'is_ip_in_cidr_ranges_py'
AS
$$
import ipaddress

def is_ip_in_cidr_ranges_py(ip_address_str: str, cidr_ranges_str: str) -> bool:
    """
    Checks if an IP address is contained within any of a comma-separated list of CIDR ranges.

    Args:
        ip_address_str (str): The IP address string (e.g., '192.168.1.10', '2001:db8::1').
        cidr_ranges_str (str): A comma-separated string of CIDR ranges (e.g., '192.168.1.0/24,10.0.0.0/8').

    Returns:
        bool: True if the IP is in any range, False otherwise.
              Returns None (maps to SQL NULL) if any input is invalid.
    """
    try:
        ip_obj = ipaddress.ip_address(ip_address_str)
    except ValueError:
        # Invalid IP address format
        return None

    cidr_list = [c.strip() for c in cidr_ranges_str.split(',') if c.strip()]

    for cidr_str in cidr_list:
        try:
            network_obj = ipaddress.ip_network(cidr_str, strict=False) # strict=False allows host bits to be set
            if ip_obj in network_obj:
                return True
        except ValueError:
            # Invalid CIDR format in the list, or type mismatch (e.g., IPv4 in IPv6 network)
            # Returning None for any invalid CIDR in the list, as the overall result is indeterminate
            return None
        except TypeError:
            # This can happen if ip_obj is IPv4 and network_obj is IPv6 (or vice versa) and they are not compatible
            # The 'in' operator will raise TypeError for incompatible address families.
            # We treat this as an unmatch rather than an error for the specific check, but if the
            # overall function must return NULL for any unparseable CIDR, the ValueError catch above handles it.
            # For strict type mismatch, it means the IP is not in that specific network.
            # However, if any CIDR in the list is invalid, the function should return NULL.
            return None # Re-evaluate: if a valid IP is checked against a list where one CIDR is valid but another is type-incompatible, should it be NULL?
                        # Given the prompt's focus on "any of the cidr ranges", if *any* CIDR is unparseable, NULL is appropriate.

    return False
$$;

show network policies;

set cidr_ranges = '192.168.1.0/24,10.0.0.0/8,172.16.0.0/16,52.247.216.65/24,52.183.42.53/12';

--use function identify ip addresses not covered by network policy
create temporary table ip_in_range as (
with ip_addreses_used as (
select CLIENT_IP
from SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY 
where is_success = 'YES'
group by all)
select CLIENT_IP ,
IS_IP_IN_CIDR_RANGES ( CLIENT_IP ,$cidr_ranges ) as in_range
from ip_addreses_used);


--get list of user and client types that with ips out of range
SELECT 
    USER_NAME,CLIENT_IP, reported_client_type ,count(*) login_count
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY lh
join SNOWFLAKE.ACCOUNT_USAGE.users u
on u.name = lh.user_name
where u.deleted_on is null
and CLIENT_IP in 
    (select CLIENT_IP from ip_in_range where in_range = false)
group by all;
