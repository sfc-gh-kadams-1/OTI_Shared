CREATE NETWORK RULE block_public_access
  MODE = INGRESS
  TYPE = IPV4
  VALUE_LIST = ('0.0.0.0/0');

CREATE NETWORK RULE allow_vpceid_access
  MODE = INGRESS
  TYPE = AWSVPCEID
  VALUE_LIST = ('vpce-0fa383eb170331202');

CREATE NETWORK POLICY allow_vpceid_block_public_policy
  ALLOWED_NETWORK_RULE_LIST = ('allow_vpceid_access')
  BLOCKED_NETWORK_RULE_LIST=('block_public_access');


CREATE NETWORK RULE allow_access_rule
  MODE = INGRESS
  TYPE = IPV4
  VALUE_LIST = ('192.168.1.0/24');

CREATE NETWORK RULE block_access_rule
  MODE = INGRESS
  TYPE = IPV4
  VALUE_LIST = ('192.168.1.99');

CREATE NETWORK POLICY public_network_policy
  ALLOWED_NETWORK_RULE_LIST = ('allow_access_rule')
  BLOCKED_NETWORK_RULE_LIST=('block_access_rule');


