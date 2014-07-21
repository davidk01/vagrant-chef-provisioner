#!/bin/bash
apt-get -y update
apt-get -y install wget curl apt-transport-https
apt-get -y update

# downloading chef-server takes a toll on vagrant provisioning
# if the user has downloaded the file then use the downloaded file
if [[ ! -e $(ls /vagrant/chef-server*.deb) ]]; then
  wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef_11.12.8-2_amd64.deb
fi
dpkg -i $(ls /vagrant/chef-server*.deb)

# installing the server package is not enough
sudo chef-server-ctl reconfigure

# add omnibus ruby to /etc/profile so all users get it
if [[ ! $(cat /etc/profile | grep PATH) ]]; then
  echo "export PATH=/opt/chef-server/embedded/bin/:\$PATH" >> /etc/profile
fi

# create knife configuration for root user
cd /root
source /etc/profile
if [[ ! -e /root/.chef ]]; then
  mkdir -p .chef
  cp /etc/chef-server/admin.pem .chef/
  cp /vagrant/knife.root.rb .chef/knife.rb
fi

# upload roles, data bags and cookbooks
pushd /vagrant_data
  knife cookbook upload -a -o ./cookbooks
  knife cookbook upload -a -o ./site-cookbooks
  knife role from file roles/*
  for bag in $(ls data_bags/); do
    knife data bag create ${bag}
    knife data bag from file ${bag} data_bags/${bag}
  done
  knife environment from file environments/*.json
  knife environment from file /vagrant/*.json
  knife node create precise64 -d -y -E vagrant
  knife bootstrap --sudo -x vagrant -E vagrant -P vagrant localhost
popd

gem install chef --no-ri --no-rdoc

# make our lives easier
apt-get -q -y install vim
echo 'export EDITOR=vim' >> /root/.bashrc
