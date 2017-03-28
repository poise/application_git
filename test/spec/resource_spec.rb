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

require 'spec_helper'

describe PoiseApplicationGit::Resource do
  step_into(:application_git)
  before do
    # Don't actually run the real thing, this is awkward as hell but sigh.
    allow_any_instance_of(PoiseGit::Resources::PoiseGit::Provider).to receive(:action_sync).and_return(nil)
  end

  context 'with basic usage' do
    recipe do
      application_git '/test' do
        repository 'https://example.com/test.git'
        revision 'd44ec06d0b2a87732e91c005ed2048c824fd63ed'
        deploy_key 'secretkey'
      end
    end

    it { is_expected.to sync_application_git('/test').with(destination: '/test', repository: 'https://example.com/test.git', revision: 'd44ec06d0b2a87732e91c005ed2048c824fd63ed', deploy_key: 'secretkey') }
  end # /context with basic usage


  context 'with a local path to a deploy key' do
    recipe do
      application_git '/test' do
        repository 'https://example.com/test.git'
        revision 'd44ec06d0b2a87732e91c005ed2048c824fd63ed'
        deploy_key '/etc/key'
      end
    end

    it { is_expected.to sync_application_git('/test').with(destination: '/test', repository: 'https://example.com/test.git', revision: 'd44ec06d0b2a87732e91c005ed2048c824fd63ed', deploy_key: '/etc/key') }
  end # /context with a local path to a deploy key

  context 'with an application path' do
    recipe do
      application '/app' do
        application_git 'https://example.com/test.git' do
          revision 'd44ec06d0b2a87732e91c005ed2048c824fd63ed'
        end
      end
    end

    it { is_expected.to sync_application_git('https://example.com/test.git').with(destination: '/app', repository: 'https://example.com/test.git', revision: 'd44ec06d0b2a87732e91c005ed2048c824fd63ed') }
  end # /context with an application path


  context 'with an application owner' do
    recipe do
      application '/app' do
        owner 'myuser'
        application_git 'https://example.com/test.git' do
          revision 'd44ec06d0b2a87732e91c005ed2048c824fd63ed'
        end
      end
    end

    it { is_expected.to sync_application_git('https://example.com/test.git').with(user: 'myuser') }
  end # /context with an application owner

  context 'with an application group' do
    recipe do
      application '/app' do
        group 'mygroup'
        application_git 'https://example.com/test.git' do
          revision 'd44ec06d0b2a87732e91c005ed2048c824fd63ed'
        end
      end
    end

    it { is_expected.to sync_application_git('https://example.com/test.git').with(group: 'mygroup') }
  end # /context with an application group
end
