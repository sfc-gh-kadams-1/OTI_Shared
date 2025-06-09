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
