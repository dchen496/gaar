require 'rubygems'
require 'bundler/setup'

require 'active_record'

#   credentials = {hostname:'localhost', username:'root', password:'root', database:'db', port:3306}
services = JSON.parse(ENV['VCAP_SERVICES'])
services_mysql = services.keys.select{ |service| service =~ /mysql/i }.first
credentials = services[services_mysql].first['credentials']

ActiveRecord::Base.establish_connection(
  adapter:'mysql2',
  host:credentials['hostname'],
  username:credentials['username'],
  password:credentials['password'],
  database:credentials['name'],
  port:credentials['port']
)

ActiveRecord::Base.connection_pool.instance_variable_set('@size', 15)

class Configuration < ActiveRecord::Base
end

class Project < ActiveRecord::Base
  serialize :reviewers
end

class Change < ActiveRecord::Base
end

ActiveRecord::Migrator.migrate('migrations', ENV['DB_VERSION'] ? ENV['DB_VERSION'].to_i : nil)

