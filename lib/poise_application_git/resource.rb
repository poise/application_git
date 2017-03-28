#
# Copyright 2015-2017, Noah Kantrowitz
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

require 'poise_git/resources/poise_git'
require 'poise_application/app_mixin'


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
  class Resource < PoiseGit::Resources::PoiseGit::Resource
    include PoiseApplication::AppMixin
    provides(:application_git)
    subclass_providers!

    # @api private
    def initialize(*args)
      super
      # Because the superclass declares this, we have to as well. Should be
      # removable at some point when Chef makes everything use the provider
      # resolver system instead.
      @resource_name = :application_git if defined?(@resource_name) && @resource_name
      # Clear defaults in older versions of Chef.
      remove_instance_variable(:@group) if instance_variable_defined?(:@group)
      remove_instance_variable(:@user) if instance_variable_defined?(:@user)
    end

    # @!attribute group
    #   Group to run git as. Defaults to the application group.
    #   @return [String, Integer, nil, false]
    attribute(:group, kind_of: [String, Integer, NilClass, FalseClass], default: lazy { parent && parent.group })

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
      super
    end

  end

end
