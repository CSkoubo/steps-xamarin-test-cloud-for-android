#!/bin/bash
gem install uber -v 0.0.15
gem install declarative -v 0.0.8
gem install multipart-post -v 2.0.0
gem install faraday -v 0.9.2
gem install json -v 2.0.2
gem install multi_json -v 1.11.2
gem install representable -v 3.0.0

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ruby "${THIS_SCRIPTDIR}/step.rb" \
  -s "${xamarin_project}" \
  -c "${xamarin_configuration}" \
  -p "${xamarin_platform}" \
  -u "${xamarin_user}" \
  -a "${test_cloud_api_key}" \
  -d "${test_cloud_devices}" \
  -y "${test_cloud_is_async}" \
  -r "${test_cloud_series}" \
  -l "${test_cloud_parallelization}" \
  -g "${sign_parameters}" \
  -m "${other_parameters}"
