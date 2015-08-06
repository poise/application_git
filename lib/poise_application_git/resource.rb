#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'zlib'

require 'chef/provider'
require 'chef/resource'
require 'poise_application/app_mixin'

require 'poise_application_git/safe_string'


module PoiseApplicationGit
  class Resource < Chef::Resource::Git
    include PoiseApplication::AppMixin
    provides(:application_git)

    def initialize(*args)
      super
      # Because the superclass declares this, we have to as well. Should be
      # removable at some point when Chef makes everything use the provider
      # resolver system instead.
      @resource_name = :application_git
      @provider = PoiseApplicationGit::Provider
    end

    attribute(:strict_ssh, equal_to: [true, false], default: false)

    def after_created
      # Allow using the repository as the name in an application block.
      if parent && !repository
        destination(parent.path)
        repository(name)
      end
    end

    def deploy_key(val=nil)
      if val
        # Set the wrapper script if we have a deploy key.
        ssh_wrapper(ssh_wrapper_path) if !ssh_wrapper
        # Also use a SafeString for literal deploy keys so they aren't shown.
        val = SafeString.new(val) unless deploy_key_is_local?(val)
      end
      set_or_return(:deploy_key, val, kind_of: String)
    end

    def ssh_wrapper_path
      @ssh_wrapper_path ||= ::File.expand_path("~#{user}/.ssh/ssh_wrapper_#{Zlib.crc32(name)}")
    end

    def deploy_key_is_local?(key=nil)
      key ||= deploy_key
      key && key[0] == '/'
    end

    def deploy_key_path
      @deploy_key_path ||= if deploy_key_is_local?
        deploy_key
      else
        ::File.expand_path("~#{user}/.ssh/id_deploy_#{Zlib.crc32(name)}")
      end
    end
  end # /class Resource

  class Provider < Chef::Provider::Git
    include PoiseApplication::AppMixin
    provides(:application_git)

    def whyrun_supported?
      false # Just not dealing with this right now
    end

    def load_current_resource
      include_recipe('git')
      notifying_block do
        create_dotssh
        write_deploy_key
        write_ssh_wrapper
      end if new_resource.deploy_key
      super
    end

    private

    def create_dotssh
      directory ::File.expand_path("~#{new_resource.user}/.ssh") do
        owner new_resource.user
        group new_resource.group
        mode '755'
      end
    end

    def write_deploy_key
      # Check if we have a local path or some actual content
      return if new_resource.deploy_key_is_local?
      file new_resource.deploy_key_path do
        owner new_resource.user
        group new_resource.group
        mode '600'
        content new_resource.deploy_key
        sensitive true
      end
    end

    def write_ssh_wrapper
      # Write out the GIT_SSH script, it should already be enabled above
      file new_resource.ssh_wrapper_path do
        owner new_resource.user
        group new_resource.group
        mode '700'
        content %Q{#!/bin/sh\n/usr/bin/env ssh #{'-o "StrictHostKeyChecking=no" ' unless new_resource.strict_ssh}-i "#{new_resource.deploy_key_path}" $@\n}
      end
    end

    # Patch back in the `#git` from the git provider. This otherwise conflicts
    # with the `#git` defined by the DSL, which gets included in such a way
    # that the DSL takes priority.
    def git(*args, &block)
      Chef::Provider::Git.instance_method(:git).bind(self).call(*args, &block)
    end
  end # /class Provider
end
