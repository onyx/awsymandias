require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Notable do 
    class DummyClass
      include Awsymandias::Notable
      metadata_options :prefix => "IntegrationTestDummyClass"
      def initialize(name = 'dummy1'); @name = name; end
      def id; @name; end
    end
  
    def clean_up_notes
      Awsymandias::SimpleDB.query('awsymandias-notes', '').select do |key| 
        key.match(Regexp.new('integration_?test', Regexp::IGNORECASE)) != nil 
      end.each do |key|
        Awsymandias::SimpleDB.delete 'awsymandias-notes', key
      end
    end
  
    before :all do
      if ENV['AMAZON_ACCESS_KEY_ID']  && ENV['AMAZON_SECRET_ACCESS_KEY'] 
        Awsymandias.access_key_id = ENV['AMAZON_ACCESS_KEY_ID'] 
        Awsymandias.secret_access_key = ENV['AMAZON_SECRET_ACCESS_KEY']
      else
        raise "No Awsymandias keys available.  Please set ENV['AMAZON_ACCESS_KEY_ID'] and ENV['AMAZON_SECRET_ACCESS_KEY']"
      end
    end 
    
    before :each do
      clean_up_notes 
    end

    after :all do
      clean_up_notes 
    end
  
    it "should properly add notes to an object" do
      dummy = DummyClass.new
    
      dummy.aws_notes = [ 'integration_test_note' ]
      dummy.aws_notes.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-notes','IntegrationTestDummyClass__dummy1')[:notes_for_object].should == ['integration_test_note']
    end
    
    it "should properly modify notes on an object" do
      dummy = DummyClass.new
    
      dummy.aws_notes = [ 'integration_test_note' ]
      dummy.aws_notes.save
    
      dummy.aws_notes = [ 'integration_test_note2' ]
      dummy.aws_notes.save
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-notes','IntegrationTestDummyClass__dummy1')[:notes_for_object].should == ['integration_test_note2']
    end
    
    it "should delete notes when an object is destroyed" do 
      dummy = DummyClass.new
      dummy.aws_notes = [ 'integration_test_note' ]
      dummy.aws_notes.save
      dummy.destroy
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-notes','IntegrationTestDummyClass__dummy1').should == {}
    end

    it "should delete notes when an object is destroyed and the object has its own destroy method" do 
      class DummyClassWithDestroy     
        include Awsymandias::Notable
        metadata_options :prefix => "IntegrationTestDummyClass"
  
        def self.find(ids = []); ids; end
        def initialize(name = 'dummy1'); @name = name; end
        def destroy; end
        def id; @name; end
      end
      
      dummy = DummyClassWithDestroy.new
      dummy.aws_notes = [ 'integration_test_note' ]
      dummy.aws_notes.save
      dummy.destroy
      sleep 1
      Awsymandias::SimpleDB.get('awsymandias-notes','IntegrationTestDummyClassWithDestroy__dummy1').should == {}
    end
  end
end