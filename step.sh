#!/bin/bash

gem list
exit 1

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BUNDLE_GEMFILE=$THIS_SCRIPTDIR/xtc_client/Gemfile bundle install

BUNDLE_GEMFILE=$THIS_SCRIPTDIR/xtc_client/Gemfile bundle exec ruby "${THIS_SCRIPTDIR}/step.rb" \
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
