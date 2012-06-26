require 'spec_helper'
require 'worker'

describe Worker do
  before :each do
    Configuration.stub(:first) do
      c = double('configuration',
                 :enable => true,
                 :interval => 0,
                 :host => 'host',
                 :user => 'user',
                 :port => 1234,
                 :privatekey => 'privatekey'
                )
    end

    RemoteGerrit.stub(:new) do
      gerrit = double('gerrit')

      gerrit.stub(:query) do |arg|
        [
          {'id' => 'done'},
          {'id' => 'WIP', 'commitMessage' => 'WIP'},
          {'id' => 'hasreviews',
            'patchSets' => [{'approvals' => [{'type' => 'CRVW'}]}]},
          {'id' => 'ok',
            'patchSets' => [{'approvals' => [{'type' => 'VRIF'}]}]}
        ]
      end

      gerrit.stub(:is_project?) do |arg|
        arg == 'a_project' || arg == 'another_project'
      end

      @set_reviewers_count = {}
      gerrit.stub(:set_reviewers) do |_, _, _, id|
        @set_reviewers_count[id] ||= 0
        @set_reviewers_count[id] += 1
      end

      gerrit
    end

    @projects = [double('a_project',
                        :name => 'a_project',
                        :reviewers => ['reviewer'],
                        :destroy => nil)]

    Project.stub(:find_each).and_yield(@projects[0])

    Change.stub(:where) do |hash|
      case hash[:changeid]
      when 'done'
        [true]
      else
        []
      end
    end

    @change_create_count = {}
    Change.stub(:create) do |hash|
      @change_create_count[hash[:changeid]] ||= 0
      @change_create_count[hash[:changeid]] += 1
    end

    @worker = Worker.new
  end

  it "should destroy projects in database but not in Gerrit" do
    @projects << double('not_a_project',
                        :name => 'not_a_project',
                        :reviewers => ['reviewer'],
                        :destroy => nil)
    Project.stub(:find_each).and_yield(@projects[0]).and_yield(@projects[1])
    @worker.task
  end

  it "should not add reviewers to changes already done" do
    @worker.task
    @set_reviewers_count['done'].should eql nil
  end

  it "should not re-add changes that are done" do
    @worker.task
    @set_reviewers_count['done'].should eql nil
  end

  it "should not add reviewers to WIP changes" do
    @worker.task
    @set_reviewers_count['WIP'].should eql nil
  end

  it "should not add WIP changes to change database" do
    @worker.task
    @set_reviewers_count['WIP'].should eql nil
  end

  it "should not add reviewers to a change with reviews" do
    @worker.task
    @set_reviewers_count['hasreviews'].should eql nil
  end

  it "should add changes with reviews to the change database" do
    @worker.task
    @change_create_count['hasreviews'].should eql 1
  end

  it "should add reviewers to verified changes with no reviewers/WIP" do
    @worker.task
    @set_reviewers_count['ok'].should eql 1
  end

  it "should add changes that had reviewers added to the change database" do
    @worker.task
    @change_create_count['ok'].should eql 1
  end
end
