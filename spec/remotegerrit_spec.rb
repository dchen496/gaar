require 'spec_helper'
require 'remotegerrit'

class RemoteGerrit
  attr_accessor :ssh
end

describe RemoteGerrit do
  before :each do
    Net::SSH.stub(:start) do
      net_ssh = double('net_ssh')

      net_ssh.stub(:exec!) do |command|
        case command
        when 'gerrit ls-projects'
          <<RESPONSE
a_project
another_project
a-project-with-dashes
a project with spaces
RESPONSE

        when 'gerrit query status:open --format=json'
          <<RESPONSE
{"project":"test_repo_one"}
{"project":"test_repo_two"}
{"type":"stats","rowCount":2,"runTimeMilliseconds":4}
RESPONSE

        when 'gerrit query invalid:option --format=json'
          '{"type":"error","message":"a Gerrit error"}'

        when 'gerrit set-reviewers invalid'
          'fatal: "invalid" is not a valid change'
        end
      end

    net_ssh
    end

    @gerrit = RemoteGerrit.new('host', '1234', 'user', 'key_data')
  end

  describe 'initialize' do
    it 'should connect to SSH' do
      Net::SSH.should_receive(:start).with(
        'host',
        'user',
        :port => 1234,
        :key_data => ['key_data'],
        :keys_only => true,
        :keys => []
      )

      RemoteGerrit.new('host', 1234, 'user', 'key_data')
    end
  end

  describe 'ls_projects' do
    it 'should call "gerrit ls-projects"' do
      @gerrit.ssh.should_receive(:exec!).with('gerrit ls-projects')
      @gerrit.ls_projects
    end

    it 'should return an array of projects' do
      result = ['a_project', 'another_project',
        'a-project-with-dashes', 'a project with spaces']
      @gerrit.ls_projects.should eql result
    end
  end

  describe 'is_project?' do
    it 'should return true if a project exists' do
      @gerrit.is_project?('a_project').should eql true
    end

    it 'should return false if a project does not exist' do
      @gerrit.is_project?('not_a_project').should eql false
    end
  end

  describe 'query' do
    it 'should call "gerrit query" with arguments' do
      @gerrit.ssh.should_receive(:exec!).with(
        "gerrit query status:open --format=json"
      )
      @gerrit.query('status:open')
    end

    it 'should return an array of changes' do
      @gerrit.query('status:open').should eql(
        [{"project" => "test_repo_one"}, {"project" => "test_repo_two"}]
      )
    end

    it 'should raise error if the query is invalid' do
      expect { @gerrit.query('invalid:option') }.to raise_error
    end
  end

  describe 'set_reviewers' do
    it 'should call "gerrit set-reviewers" with reviewers to add/remove' do
      @gerrit.ssh.should_receive(:exec!).with(
        %Q/gerrit set-reviewers -p "a_project" -a "reviewer_to_add" \
-a "reviewer2" -r "reviewer_to_remove" -r "reviewer4" I123456/
      )
      @gerrit.set_reviewers('a_project',
        ['reviewer_to_add', 'reviewer2'],
        ['reviewer_to_remove', 'reviewer4'],
        'I123456'
      )
    end
  end
end
