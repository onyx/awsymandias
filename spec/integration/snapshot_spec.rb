require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Snapshot do
    before :all do
      raise "No Awsymandias keys available.  Please set ENV['AMAZON_ACCESS_KEY_ID'] and ENV['AMAZON_SECRET_ACCESS_KEY']" unless ENV['AMAZON_ACCESS_KEY_ID'] && ENV['AMAZON_SECRET_ACCESS_KEY'] 
      Awsymandias.access_key_id = ENV['AMAZON_ACCESS_KEY_ID'] 
      Awsymandias.secret_access_key = ENV['AMAZON_SECRET_ACCESS_KEY']
      @ec2   = Rightscale::Ec2.new ENV['AMAZON_ACCESS_KEY_ID'], ENV['AMAZON_SECRET_ACCESS_KEY']
      @created_snapshots = []
      @availability_zone = "us-east-1b"
      @default_volume = @ec2.create_volume nil, 1, @availability_zone
    end 
    
    after :all do
      @created_snapshots.each do |snapshot|
        begin
          @ec2.delete_snapshot snapshot[:aws_id]
        rescue Exception => ex
          puts "Cannot delete snapshot #{snapshot[:aws_id]}: #{ex.inspect}"
        end
      end
      @ec2.delete_volume @default_volume[:aws_id]
    end

    def create_snapshot(volume, description = nil)
      snapshot = @ec2.create_snapshot volume[:aws_id], description
      @created_snapshots << snapshot
      snapshot
    end
    
    it "should only find snapshots by description" do
      description = 'some unique description 123'
      snapshot_with_description         = create_snapshot @default_volume, description
      snapshot_with_same_description    = create_snapshot @default_volume, description
      snapshot_with_another_description = create_snapshot @default_volume, 'some unique description 456'
      snapshot_without_description      = create_snapshot @default_volume
      
      found_snapshot_ids = Awsymandias::Snapshot.find_by_description(description).map(&:id).sort
      expected_snapshot_ids = [snapshot_with_description[:aws_id], snapshot_with_same_description[:aws_id]].sort
      
      found_snapshot_ids.should == expected_snapshot_ids
    end
    
    it "uses the right version of the EC2 API" do
      ::RightAws::Ec2.api.should == "2009-11-30"
    end
  end
end