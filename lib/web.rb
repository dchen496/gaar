require 'rubygems'
require 'bundler/setup'

require 'json'

require 'remotegerrit'
require 'db'
require 'worker'

set :environment, :production

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  c = Configuration.first
  [username, password] == [c.httpuser, c.httppass]
end

before do
  @c = Configuration.first

  case request.path_info
  when '/serverform'
  when '/setserver'
  else
    begin
      @gerrit = RemoteGerrit.new(@c.host, @c.port, @c.user, @c.privatekey)
    rescue
      redirect '/serverform'
    end
  end
end

get '/' do
  @title = 'Index'
  erb :index
end

get '/projectreviewers' do
  if @gerrit.is_project? params['project']
    begin
      project = Project.where(:name => params['project']).first!
    rescue
      project = Project.new(:name => params['project'])
    end

    if !params['reviewers'].nil?
      r = params['reviewers'].split(',')
      project.reviewers = r.map(&:strip)
      project.save!

    else
      if !project.reviewers.nil?
        project.reviewers.join(', ')
      end
    end
  end
end

get '/serverform' do
  @title = 'Configure Gerrit server'
  begin
    @gerrit = RemoteGerrit.new(@c.host, @c.port, @c.user, @c.privatekey)
  rescue
    @error = "Configuration is not valid: can't connect to Gerrit."
  end
  erb :serverform
end

get '/setserver' do
  @title = 'Configure Gerrit server'

  params.each_pair do |key, value|
    next unless value.is_a? String
    value = value.strip
    if value == ''
      params[key] = nil
    end
  end

  if params['publickey']
    @c.publickey = params['publickey'].gsub(/\r\n?/, "\n")
  end
  if params['publickey']
    @c.privatekey = params['privatekey'].gsub(/\r\n?/, "\n")
  end
  @c.host = params['host'] || @c.host
  @c.port = params['port'] || @c.port
  @c.user = params['user'] || @c.user
  @c.httpuser = params['httpuser'] || @c.httpuser
  @c.httppass = params['httppass'] || @c.httppass
  @c.interval = params['interval'] ? params['interval'].to_i : @c.interval
  @c.enable = !params['check'].nil?

  @c.save

  begin
  @gerrit = RemoteGerrit.new(@c.host, @c.port, @c.user, @c.privatekey)
  rescue
    @errors = "Current server configuration is not valid."
  end

  erb :setserver
end

after do
  ActiveRecord::Base.clear_active_connections!
end

Thread.new do
  worker = Worker.new
  while true
    worker.add_reviewers
  end
end
