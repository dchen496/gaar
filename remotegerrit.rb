require 'rubygems'
require 'bundler/setup'

require 'net/ssh'
require 'json'

require_relative 'log'

class RemoteGerrit
  def initialize(host, port, user, key)
    @ssh = Net::SSH.start(host, user, port:port, key_data:[key], keys_only:true, keys:[])
  end

  def command(c)
    $log.info c
    @ssh.exec! c
  end

  def ls_projects
    command("gerrit ls-projects").split($/)
  end
  
  def is_project?(project)
    ls_projects.include? project
  end

  def query(query)
    r = command("gerrit query #{query} --format=json").
      each_line.map{|line| JSON.parse line}
    r[0..-2]
  end

  def set_reviewers(project=nil, add, remove, changeid)
    s = "gerrit set-reviewers "
    s << "-p \"#{project}\" " if project != nil 
    add.each{|r| s << "-a \"#{r}\" "} 
    remove.each{|r| s << "-r \"#{r}\" "}
    s << changeid 
    command(s)
  end

end

if __FILE__ == $0
host, port = 'localhost', '29418'
user = 'douglasc'
key = IO.read('id_rsa')

r = RemoteGerrit.new(host, port, user, key)

query = ARGV.join(' ')

puts r.query(query).to_s
end
