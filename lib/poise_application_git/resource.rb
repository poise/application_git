#
# Copyright 2015-2016, Noah Kantrowitz
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
require 'poise_application/resources/application'

require 'poise_application_git/safe_string'


module PoiseApplicationGit
  # An `application_git` resource to clone application code from git.
  #
  # @since 1.0.0
  # @provides application_git
  # @action sync
  # @action checkout
  # @action export
  # @example
  #   application '/srv/myapp' do
  #     git 'git@github.com:example/myapp.git' do
  #       deploy_key data_bag_item('deploy_keys', 'myapp')['key']
  #     end
  #   end
  class Resource < Chef::Resource::Git
    include PoiseApplication::AppMixin
    provides(:application_git)

    # @api private
    def initialize(*args)
      super
      # Because the superclass declares this, we have to as well. Should be
      # removable at some point when Chef makes everything use the provider
      # resolver system instead.
      @resource_name = :application_git
      @provider = PoiseApplicationGit::Provider
      # Clear defaults in older versions of Chef.
      remove_instance_variable(:@group) if instance_variable_defined?(:@group)
      remove_instance_variable(:@user) if instance_variable_defined?(:@user)
    end

    # @!attribute group
    #   Group to run git as. Defaults to the application group.
    #   @return [String, Integer, nil, false]
    attribute(:group, kind_of: [String, Integer, NilClass, FalseClass], default: lazy { parent && parent.group })
    # @!attribute strict_ssh
    #   Enable strict SSH host key checking. Defaults to false.
    #   @return [Boolean]
    attribute(:strict_ssh, equal_to: [true, false], default: false)
    # @!attribute user
    #   User to run git as. Defaults to the application owner.
    #   @return [String, Integer, nil, false]
    attribute(:user, kind_of: [String, Integer, NilClass, FalseClass], default: lazy { parent && parent.owner })

    # @api private
    def after_created
      # Allow using the repository as the name in an application block.
      if parent && !repository
        destination(parent.path)
        repository(name)
      end
    end

    # @!attribute deploy_key
    #   SSH deploy key as either a string value or a path to a key file.
    #   @return [String]
    def deploy_key(val=nil)
      # Use a SafeString for literal deploy keys so they aren't shown.
      val = SafeString.new(val) if val && !deploy_key_is_local?(val)
      set_or_return(:deploy_key, val, kind_of: String)
    end

    # Default SSH wrapper path.
    #
    # @api private
    # @return [String]
    def ssh_wrapper_path
      @ssh_wrapper_path ||= ::File.expand_path("~#{user}/.ssh/ssh_wrapper_#{Zlib.crc32(name)}")
    end

    # Guess if the deploy key is a local path or literal value.
    #
    # @api private
    # @param key [String, nil] Key value to check. Defaults to self.key.
    # @return [Boolean]
    def deploy_key_is_local?(key=nil)
      key ||= deploy_key
      key && key[0] == '/'
    end

    # Path to deploy key.
    #
    # @api private
    # @return [String]
    def deploy_key_path
      @deploy_key_path ||= if deploy_key_is_local?
        deploy_key
      else
        ::File.expand_path("~#{user}/.ssh/id_deploy_#{Zlib.crc32(name)}")
      end
    end
  end

  # Provider for `application_git`.
  #
  # @since 1.0.0
  # @see Resource
  # @provides application_git
  class Provider < Chef::Provider::Git
    include PoiseApplication::AppMixin
    provides(:application_git)

    # @api private
    def initialize(*args)
      super
      # Set the SSH wrapper path in a late-binding kind of way. This better
      # supports situations where the user doesn't exist until Chef converges.
      new_resource.ssh_wrapper(new_resource.ssh_wrapper_path) if new_resource.deploy_key
    end

    # @api private
    def whyrun_supported?
      false # Just not dealing with this right now
    end

    # Hack our special login in before load_current_resource runs because that
    # needs access to the git remote.
    #
    # @api private
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

    # Create a .ssh folder for the user.
    #
    # @return [void]
    def create_dotssh
      directory ::File.expand_path("~#{new_resource.user}/.ssh") do
        owner new_resource.user
        group new_resource.group
        mode '755'
      end
    end

    # Copy the deploy key to a file if needed.
    #
    # @return [void]
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

    # Create the SSH wrapper script.
    #
    # @return [void]
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
  end
end
