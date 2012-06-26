require 'rubygems'
require 'bundler/setup'

require 'active_record'

class CreateSettings < ActiveRecord::Migration
  def self.up
    create_table :configurations do |t|
      t.string :host
      t.integer :port
      t.string :user
      t.text :privatekey
      t.text :publickey
      t.integer :interval
      t.string :httpuser
      t.string :httppass
      t.boolean :enable
    end

    Configuration.create(
      :port => 29418,
      :privatekey => File.read('keys/id_rsa'),
      :publickey => File.read('keys/id_rsa.pub'),
      :httpuser => 'user',
      :httppass => 'pass',
      :interval => 120,
      :enable => false
    )

    create_table :projects do |t|
      t.string :name
      t.text :reviewers
    end

    create_table :changes do |t|
      t.string :changeid
    end
  end

  def self.down
    drop_table :configurations
    drop_table :projects
    drop_table :changes
  end
end

