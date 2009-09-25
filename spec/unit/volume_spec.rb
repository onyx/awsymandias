require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Volume do
    DEFAULT_VOLUME_ATTRIBUTES = {:aws_size              => 94,
                                 :aws_device            => "/dev/sdc",
                                 :aws_attachment_status => "attached",
                                 :zone                  => "merlot",
                                 :snapshot_id           => nil,
                                 :aws_attached_at       => Date.parse("Wed Jun 18 08:19:28 UTC 2008"),
                                 :aws_status            => "in-use",
                                 :aws_id                => "vol-60957009",
                                 :aws_created_at        => Date.parse("Wed Jun 18 08:19:20s UTC 2008"),
                                 :aws_instance_id       => "i-c014c0a9"}
    
    def test_volume(attribs = {})
      @volume = Volume.new DEFAULT_VOLUME_ATTRIBUTES.merge(attribs)
      @volume
    end
    
    describe "find" do
      it "should return an array of Awsymandias::Volume objects." do
        connection = mock('connection')
        connection.should_receive(:describe_volumes).and_return(
          [{:aws_id => :some_volume_id}, {:aws_id => :another_volume_id}]
        )
        Awsymandias::RightAws.should_receive(:connection).and_return(connection)
        
        volumes = Volume.find
        volumes.map(&:aws_id).should == [:some_volume_id, :another_volume_id]
        volumes.map(&:class).uniq.should == [Awsymandias::Volume]
      end
    end

    describe "terminate!" do
      it "should do nothing if attached to an instance" do
        volume = test_volume :aws_attachment_status => 'attached'
        volume.should_receive(:destroy).never
        volume.terminate!
      end
      
      it "should delete the volume and call destroy" do
        volume = test_volume :aws_attachment_status => 'not_attached'        
        volume.should_receive(:destroy)
        connection = mock('connection')
        connection.should_receive(:delete_volume).with(test_volume.id)
        Awsymandias::RightAws.should_receive(:connection).and_return(connection)
        volume.terminate!
      end
    end
      
  end
end