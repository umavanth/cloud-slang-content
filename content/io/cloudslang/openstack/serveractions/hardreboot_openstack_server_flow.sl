#   (c) Copyright 2014 Hewlett-Packard Development Company, L.P.
#   All rights reserved. This program and the accompanying materials
#   are made available under the terms of the Apache License v2.0 which accompany this distribution.
#
#   The Apache License is available at
#   http://www.apache.org/licenses/LICENSE-2.0
#
####################################################
# Authenticates and HARD REBOOT- Restart the server. Equivalent to power cycling the server.
#
# Inputs:
#   - host - OpenStack machine host
#   - identity_port - optional - port used for OpenStack authentication - Default: 5000
#   - compute_port - optional - port used for OpenStack computations - Default: 8774
#   - username - OpenStack username
#   - password - OpenStack password
#   - tenant_name - name of the project on OpenStack
#   - proxy_host - optional - proxy server used to access the web site - Default: none
#   - proxy_port - optional - proxy server port - Default: none
#   - server_id - OpenStack Server ID
# Outputs:
#   - return_result - response of the last operation executed
#   - error_message - error message of the operation that failed
# Results:
#   - SUCCESS
#   - FAILURE
####################################################

namespace: io.cloudslang.openstack.serveractions

imports:
 openstack_content: io.cloudslang.openstack
 openstack_utils: io.cloudslang.openstack.utils
 openstack_actions: io.cloudslang.openstack.serveractions


flow:
  name: hardreboot_openstack_server_flow
  inputs:
    - host
    - identity_port:
        default: "'5000'"
    - compute_port:
        default: "'8774'"
    - username
    - password
    - tenant_name
    - server_id
    - proxy_host:
        required: false
    - proxy_port:
        required: false
  workflow:
    - authentication:
        do:
          openstack_content.get_authentication_flow:
            - host
            - identity_port
            - username
            - password
            - tenant_name
            - proxy_host:
                required: false
            - proxy_port:
                required: false
        publish:
          - token
          - tenant
          - return_result
          - error_message


    - hardreboot_openstack_server:
        do:
           openstack_actions.hardreboot_openstack_server:
             - host
             - token
             - tenant
             - server_id
        publish:
           - return_result
           - error_message
  outputs:

    - return_result
    - error_message