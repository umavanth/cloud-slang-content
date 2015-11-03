#   (c) Copyright 2014 Hewlett-Packard Development Company, L.P.
#   All rights reserved. This program and the accompanying materials
#   are made available under the terms of the Apache License v2.0 which accompany this distribution.
#
#   The Apache License is available at
#   http://www.apache.org/licenses/LICENSE-2.0
#
####################################################
# Retrieves the image id from the response of the list_openstack_images operation of a given image by name.
#
# Inputs:
#   - image_body - response of list_openstack_images operation
#   - image_name - image name
# Outputs:
#   - image_id - ID of the specified image
#   - return_result - was parsing was successful or not
#   - return_code - 0 if parsing was successful, -1 otherwise
#   - error_message - error message
# Results:
#   - SUCCESS - parsing was successful (returnCode == '0')
#   - FAILURE - otherwise
####################################################

namespace: io.cloudslang.openstack.images

operation:
  name: get_image_id
  inputs:
    - image_body
    - image_name
  action:
    python_script: |
      try:
        import json
        images = json.loads(image_body)['images']
        matched_image = next(image for image in images if image['name'] == image_name)
        image_id = matched_image['id']
        return_code = '0'
        return_result = 'Parsing successful.'
      except StopIteration:
        return_code = '-1'
        return_result = 'No images in list'
      except  ValueError:
        return_code = '-1'
        return_result = 'Parsing error.'

  outputs:
    - image_id
    - return_result
    - return_code
    - error_message: return_result if return_code == '-1' else ''
  results:
    - SUCCESS: return_code == '0'
    - FAILURE