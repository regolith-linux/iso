# frozen_string_literal: true

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/focal64'
  config.vm.provision 'shell',
                      inline: 'apt update -qq',
                      privileged: true
end
