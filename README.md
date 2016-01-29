# Application_Git Cookbook

[![Build Status](https://img.shields.io/travis/poise/application_git.svg)](https://travis-ci.org/poise/application_git)
[![Gem Version](https://img.shields.io/gem/v/poise-application-git.svg)](https://rubygems.org/gems/poise-application-git)
[![Cookbook Version](https://img.shields.io/cookbook/v/application_git.svg)](https://supermarket.chef.io/cookbooks/application_git)
[![Coverage](https://img.shields.io/codecov/c/github/poise/application_git.svg)](https://codecov.io/github/poise/application_git)
[![Gemnasium](https://img.shields.io/gemnasium/poise/application_git.svg)](https://gemnasium.com/poise/application_git)
[![License](https://img.shields.io/badge/license-Apache_2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

A [Chef](https://www.chef.io/) cookbook to handle deploying code from git when
using the [application cookbook](https://github.com/poise/application).

## Quick Start

To deploy from a private GitHub repository:

```ruby
application '/srv/myapp' do
  git 'git@github.com:example/myapp.git' do
    deploy_key chef_vault_item('deploy_keys', 'myapp')['key']
  end
end
```

## Requirements

Chef 12 or newer is required.

## Resources

### `application_git`

The `application_git` resource deploys code from git. It extends the core `git`
resource to support deploy keys and disabling strict host key verification.

```ruby
application '/srv/myapp' do
  git 'git@github.com:example/myapp.git'
end
```

#### Actions

All actions work the same as the core `git` resource.

* `:sync` – Clone and checkout the requested revision *(default)*
* `:checkout` – Checkout the request revision. If the repository isn't already
  cloned, this action does nothing.
* `:export` – Export the repository without the `.git` folder.

#### Properties

All properties from the core `git` resource work the same way with the following
additions:

* `deploy_key` – SSH key to use with git. Can be specified either as a path to
  key file already created or as a string value containing the key directly.
* `strict_ssh` – Enable strict SSH host key checking. *(default: false)*

### DSL Usage

The `application_git` resource can be used directly as a replacement for the
core `git` resource:

```ruby
application_git '/srv/myapp' do
  repository 'git@github.com:example/myapp.git'
  deploy_key chef_vault_item('deploy_keys', 'myapp')['key']
end
```

Within the `application` resource, a simplified DSL is available. As with other
`application` plugins, the default name of the resource if unspecified is the
application path. The following two examples are equivalent:

```ruby
application '/srv/myapp' do
  git do
    repository 'git@github.com:example/myapp.git'
  end
end

application '/srv/myapp' do
  git 'git@github.com:example/myapp.git'
end
```

## Sponsors

Development sponsored by [Chef Software](https://www.chef.io/), [Symonds & Son](http://symondsandson.com/), and [Orion](https://www.orionlabs.co/).

The Poise test server infrastructure is sponsored by [Rackspace](https://rackspace.com/).

## License

Copyright 2015-2016, Noah Kantrowitz

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
