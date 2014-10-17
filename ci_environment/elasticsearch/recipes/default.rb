#
# Cookbook Name:: ElasticSearch
# Recipe:: default
# Copyright 2012-2013, Travis CI Development Team <contact@travis-ci.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

include_recipe "java"

require "tmpdir"

tmp = Dir.tmpdir
case node[:platform]
when "debian", "ubuntu"
  v = node.elasticsearch.version
  ["elasticsearch-#{v}.deb"].each do |deb|
    path = File.join(tmp, deb)

    remote_file(path) do
      owner  node.travis_build_environment.user
      group  node.travis_build_environment.group
      source "http://download.elasticsearch.org/elasticsearch/elasticsearch/#{deb}"

      not_if "which elasticsearch"
    end

    file(path) do
      action :nothing
    end

    package(deb) do
      action   :install
      source   path
      provider Chef::Provider::Package::Dpkg

      notifies :delete, resources(:file => path)
      notifies :create, "ruby_block[enable-dynamic-scripting]"
      notifies :create, "ruby_block[create-symbolic-links]"

      not_if "which elasticsearch"
    end
  end # each

  ruby_block 'enable-dynamic-scripting' do
    block do
      config_file = File.new '/etc/elasticsearch/elasticsearch.yml', 'a'
      config_file.write "\n# Enable dynamic scripting\nscript.disable_dynamic: false\n"
      config_file.flush
    end
    action :nothing
  end

  ruby_block 'create-symbolic-links' do
    block do
      Dir.foreach("/usr/share/elasticsearch/bin") do |file|
        File.symlink "/usr/share/elasticsearch/bin/#{file}", "/usr/local/bin/#{file}" unless File.exist? "/usr/local/bin/#{file}"
      end
    end
    action :nothing
  end

  service "elasticsearch" do
    supports :restart => true, :status => true

    if node.elasticsearch.service.enabled
      action [:enable, :start]
    else
      action [:disable, :start]
    end
  end
end
