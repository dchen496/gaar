require 'rubygems'
require 'bundler/setup'

require 'json'

require_relative 'remotegerrit'
require_relative 'db'
require_relative 'log'

class Worker
  def task
    c = Configuration.first
    if !c.enable
      interval = c.interval
      ActiveRecord::Base.clear_active_connections!
      $log.info "worker not enabled, sleeping #{interval} seconds..."
      sleep interval
      return
    end

    $log.info "****************"
    $log.info Time.now.inspect
    $log.info "worker running..."

    gerrit = RemoteGerrit.new(c.host, c.port, c.user, c.privatekey)

    Project.find_each do |project|
      $log.debug "project: #{project.name}"
      if !gerrit.is_project? project.name
        $log.warn "project not in Gerrit, destroying"
        project.destroy
        next
      end

      # Reviewers are added to changes if the change
      # 1. is open and Verified=1 on last patchset
      # 2. is not WIP according to the last patchset's commit message
      # 3. never had Code Reviews on any patchset 
      #    at a time when condition #1 was satisfied
      # 4. never had reviewers added before
      changes = gerrit.query "project:\"#{project.name}\" status:open Verified=1 --all-approvals --commit-message" 
      changes ||= []
      changes.each do |change|
        change['id'] ||= ''
        $log.debug "change: #{change['id']}"

        if !Change.where(changeid:change['id']).first.nil?
          $log.debug "change already done, skipping"
          next
        end

        change['commitMessage'] ||= ''
        if change['commitMessage'] =~ /\bWIP\b/
          $log.debug "change is WIP, skipping"
          next
        end

        approvals = []
        change['patchSets'] ||= []
        change['patchSets'].each do |patchset|
          patchset['approvals'] ||= []
          approvals += patchset['approvals']
        end
        has_code_reviews = approvals.any? do |approval|
          approval['type'] == 'CRVW' 
        end
        if !has_code_reviews
            gerrit.set_reviewers(project.name, project.reviewers, [], change['id']) 
        else
          $log.debug "change already has code reviews, skipping"
        end
        
        Change.create(changeid:change['id'])
      end
    end
    interval = c.interval
    $log.info "done, sleeping #{interval} seconds..."
    sleep interval
  rescue Exception => e
    $log.error e.message
    $log.error e.backtrace.inspect
    sleep interval?interval:90 #don't flood the logs if interval is undefined for some reason
  ensure
    ActiveRecord::Base.clear_active_connections!
  end
end

