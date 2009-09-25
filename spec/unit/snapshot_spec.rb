require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Snapshot do
    DEFAULT_SNAPSHOT_ATTRIBUTES = { :aws_progress   => "100%",
                                    :aws_status     => "completed",
                                    :aws_id         => "snap-72a5401b",
                                    :aws_volume_id  => "vol-5582673c",
                                    :aws_started_at => "2008-02-23T02:50:48.000Z" }
    
    def test_snapshot(attribs = {})
      @snapshot = Snapshot.new DEFAULT_SNAPSHOT_ATTRIBUTES.merge(attribs)
      @snapshot
    end
    
    describe "find" do
      it "should return an array of Awsymandias::Snapshot objects." do
        connection = mock('connection')
        connection.should_receive(:describe_snapshots).and_return(
          [{:aws_id => :some_snapshot_id}, {:aws_id => :another_snapshot_id}]
        )
        Awsymandias::RightAws.should_receive(:connection).and_return(connection)
        
        snapshots = Snapshot.find
        snapshots.map(&:aws_id).should == [:some_snapshot_id, :another_snapshot_id]
        snapshots.map(&:class).uniq.should == [Awsymandias::Snapshot]
      end
    end

    describe "terminate!" do
      it "should delete the snapshot and call destroy" do
        snapshot = test_snapshot
        snapshot.should_receive(:destroy)
        connection = mock('connection')
        connection.should_receive(:delete_snapshot).with(test_snapshot.id)
        Awsymandias::RightAws.should_receive(:connection).and_return(connection)
        snapshot.terminate!
      end
    end
      
  end
end