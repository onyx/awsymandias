require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

describe 'snapshots' do
  before :all do
    raise "No Awsymandias keys available.  Please set ENV['AMAZON_ACCESS_KEY_ID'] and ENV['AMAZON_SECRET_ACCESS_KEY']" unless ENV['AMAZON_ACCESS_KEY_ID'] && ENV['AMAZON_SECRET_ACCESS_KEY'] 
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
  
  def create_snapshot(volume, description = '')
    snapshot = @ec2.create_snapshot volume[:aws_id], description
    @created_snapshots << snapshot
    snapshot
  end
  
  it "should create a snapshot with the specified description" do
    new_snapshot = create_snapshot @default_volume, 'some test description'
    sleep 1
    described_snapshot = @ec2.describe_snapshots(new_snapshot[:aws_id]).first
    described_snapshot[:aws_description].should == 'some test description'
  end

  it "should create a snapshot with no description if none is passed" do
    new_snapshot = create_snapshot @default_volume
    sleep 1
    described_snapshot = @ec2.describe_snapshots(new_snapshot[:aws_id]).first
    described_snapshot[:aws_description].should == ''
  end
end