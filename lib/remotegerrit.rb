require 'rubygems'
require 'bundler/setup'

require 'net/ssh'
require 'json'

require 'logger'

class RemoteGerrit
  def initialize(host, port, user, key)
    @log = Logger.new(STDOUT)
    @log.level = Logger::WARN
    @ssh = Net::SSH.start(host, user, :port => port,
             :key_data => [key], :keys_only => true, :keys => [])
  end

  def command(c)
    @log.info c
    response = @ssh.exec! c
    @log.debug response
    response
  end

  def ls_projects
    command("gerrit ls-projects").to_s.split($/)
  end

  def is_project?(project)
    ls_projects.include? project
  end

  def query(query)
    out = command("gerrit query #{query} --format=json")
    objs = out.each_line.map { |line| JSON.parse line }
    raise 'Invalid query' if objs.last['type'] == 'error'
    objs[0..-2]
  end

  def set_reviewers(project, add, remove, changeid)
    s = "gerrit set-reviewers "
    s << "-p \"#{project}\" " unless project.nil?
    add.each { |r| s << "-a \"#{r}\" "}
    remove.each { |r| s << "-r \"#{r}\" "}
    s << changeid
    command(s)
  end

end
