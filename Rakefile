require 'rubygems'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

task :push do
  sh "vmc push --no-start --runtime=ruby19"
  sh "vmc env-add gaar DB_VERSION=1"
  sh "vmc start gaar"
end

task :update do
  sh "vmc update"
end

