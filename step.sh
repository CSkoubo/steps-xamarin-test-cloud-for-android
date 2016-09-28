#!/bin/bash

function install_gem {
  gem list -i $1 -v $2 > /dev/null || gem install $1 -v $2 --no-ri --no-rdoc
}

install_gem uber 0.0.15
install_gem declarative 0.0.8
install_gem multipart-post 2.0.0
install_gem faraday 0.9.2
install_gem json 2.0.2
install_gem multi_json 1.11.2
install_gem representable 3.0.0

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ruby "${THIS_SCRIPTDIR}/step.rb" \
  -a "${test_cloud_api_key}"
  