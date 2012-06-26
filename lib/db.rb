require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'logger'

if !ENV['VCAP_SERVICES'].nil?
  services = JSON.parse(ENV['VCAP_SERVICES'])
  mysql = services.keys.select{ |service| service =~ /mysql/i }.first
  credentials = services[mysql].first['credentials']
  ActiveRecord::Base.establish_connection(
    :adapter => 'mysql2',
    :host => credentials['hostname'],
    :username => credentials['username'],
    :password => credentials['password'],
    :database => credentials['name'],
    :port => credentials['port']
  )
else
  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database => ":memory:"
  )
end

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN

ActiveRecord::Base.connection_pool.instance_variable_set('@size', 15)

class Configuration < ActiveRecord::Base
end

class Project < ActiveRecord::Base
  serialize :reviewers
end

class Change < ActiveRecord::Base
end

ActiveRecord::Migrator.migrate(
  File.join($root, 'migrations'),
  ENV['DB_VERSION'] ? ENV['DB_VERSION'].to_i : nil
)

