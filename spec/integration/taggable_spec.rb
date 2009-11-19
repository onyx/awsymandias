require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Taggable do 
    class DummyClass      
      include Awsymandias::Taggable
      metadata_options :prefix => "IntegrationTestDummyClass"
     
      def self.find(ids = []); ids; end
      def initialize(name = 'dummy1'); @name = name; end
      def id; @name; end
    end
  
    def clean_up_tags
      Awsymandias::SimpleDB.query('awsymandias-tags', '').select do |key| 
        key.match(Regexp.new('integration_?test', Regexp::IGNORECASE)) != nil 
      end.each do |key|
        Awsymandias::SimpleDB.delete 'awsymandias-tags', key
      end
      sleep 1
    end
  
    before :all do
      raise "No Awsymandias keys available.  Please set ENV['AMAZON_ACCESS_KEY_ID'] and ENV['AMAZON_SECRET_ACCESS_KEY']" unless ENV['AMAZON_ACCESS_KEY_ID'] && ENV['AMAZON_SECRET_ACCESS_KEY'] 
      Awsymandias.access_key_id = ENV['AMAZON_ACCESS_KEY_ID'] 
      Awsymandias.secret_access_key = ENV['AMAZON_SECRET_ACCESS_KEY']
    end 
    
    before :each do
      clean_up_tags 
    end
  
    after :all do
      clean_up_tags 
    end
  
    it "should properly add tags to an object" do
      dummy = DummyClass.new
    
      dummy.aws_tags = [ 'integration_test_tag' ]
      dummy.aws_tags.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-tags','IntegrationTestDummyClass__dummy1')[:tags_for_object].should == ['integration_test_tag']
      Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag')[:objects_with_tag].should == ['IntegrationTestDummyClass__dummy1']
    end
        
    it "should properly modify tags on an object" do
      dummy = DummyClass.new
    
      dummy.aws_tags = [ 'integration_test_tag' ]
      dummy.aws_tags.save
    
      dummy.aws_tags = [ 'integration_test_tag2' ]
      dummy.aws_tags.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-tags','IntegrationTestDummyClass__dummy1')[:tags_for_object].should == ['integration_test_tag2']
    end
    
    it "should properly modify reverse tags that have more than one object" do
      dummy1 = DummyClass.new 
      dummy1.aws_tags = [ 'integration_test_tag' ]
      dummy1.aws_tags.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag')[:objects_with_tag].should == ['IntegrationTestDummyClass__dummy1']
       
      dummy2 = DummyClass.new 'dummy2'
      dummy2.aws_tags = [ 'integration_test_tag' ]
      dummy2.aws_tags.save
      sleep 1

      dummy3 = DummyClass.new 'dummy3'
      dummy3.aws_tags = [ 'integration_test_tag' ]
      dummy3.aws_tags.save
      sleep 1
      dummy3.aws_tags.delete 'integration_test_tag'
      dummy3.aws_tags.save
      sleep 1

      tagged_objects = Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag')[:objects_with_tag]
      tagged_objects.include?('IntegrationTestDummyClass__dummy1').should be_true
      tagged_objects.include?('IntegrationTestDummyClass__dummy2').should be_true
      tagged_objects.include?('IntegrationTestDummyClass__dummy3').should be_false
      tagged_objects.size.should == 2
       
      dummy2.aws_tags = [ 'integration_test_tag2' ]
      dummy2.aws_tags.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag')[:objects_with_tag].should  == ['IntegrationTestDummyClass__dummy1']
      Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag2')[:objects_with_tag].should == ['IntegrationTestDummyClass__dummy2']
    end
       
    it "should be able to find object instances by tag" do
      dummy1 = DummyClass.new 
      dummy1.aws_tags = [ 'integration_test_tag' ]
      dummy1.aws_tags.save
    
      dummy2 = DummyClass.new 'dummy2'
      dummy2.aws_tags = [ 'integration_test_tag' ]
      dummy2.aws_tags.save
     
      sleep 1
      tagged_objects = DummyClass.find_by_tag('integration_test_tag')
      tagged_objects.include?('dummy1').should be_true
      tagged_objects.include?('dummy2').should be_true
      tagged_objects.size.should == 2
    end
            
    it "should delete tags when an object is destroyed" do 
       dummy = DummyClass.new
       dummy.aws_tags = [ 'integration_test_tag' ]
       dummy.aws_tags.save
       dummy.destroy
       sleep 1
       Awsymandias::SimpleDB.get('awsymandias-tags','IntegrationTestDummyClass__dummy1').should == {}
       Awsymandias::SimpleDB.get('awsymandias-tags','AwsymandiasTagValue__integration_test_tag').should == {}
     end
       
  end
end