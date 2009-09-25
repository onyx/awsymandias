require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Notable do
    class DummyClass
      include Awsymandias::Notable
      def initialize(name = 'dummy-1'); @name = name; end
      def id; @name; end
    end

    context "simpledb_key" do
        it "should build SimpleDB keys properly with defaults for identifier and prefix" do
          Notable::Notes.simpledb_key(DummyClass.new).should == 'DummyClass__dummy-1'
        end

        it "should build SimpleDB keys properly with custom identifier and prefix" do
          class DummyClass2
            include Awsymandias::Notable
            metadata_options :identifier => :funky_id, :prefix => 'Foo'
            def funky_id; 'my_funky_id'; end
          end

          Notable::Notes.simpledb_key(DummyClass2.new).should == 'Foo__my_funky_id'
        end
    end

    context "get_metadata" do
      it "should get notes properly" do
        Awsymandias::SimpleDB.should_receive(:get).with(Notable::Notes.simpledb_domain, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return( :notes_for_object => ['a','b','c'] )
        Notable::Notes.get_metadata(DummyClass.new).should == ['a','b','c']
      end

      it "should return an empty array if simpledb returns no metadata" do
        Awsymandias::SimpleDB.should_receive(:get).with(Notable::Notes.simpledb_domain, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return( nil )
        Notable::Notes.get_metadata(DummyClass.new).should == []
      end
    end

    context "put_metadata" do
      it "should set the notes for the main object" do
        obj = DummyClass.new
        Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
          key.should == 'DummyClass__dummy-1'
          stuff.should == {:notes_for_object => ["a"]}
        end
        Notable::Notes.put_metadata DummyClass.new, ['a']
      end

      it "should delete from SimpleDB if there are no notes" do
        Awsymandias::SimpleDB.should_receive(:get).and_return(:notes_for_object => [])
        Awsymandias::SimpleDB.should_receive(:delete).with(Notable::Notes.simpledb_domain,'DummyClass__dummy-1')
        obj = DummyClass.new
        obj.aws_notes.save
      end
    end

    context "Tags class" do
      it "should save notes for the object to SimpleDB" do
        obj = DummyClass.new
        Notable::Notes.should_receive(:get_metadata).with(obj).and_return([])
        Notable::Notes.should_receive(:put_metadata).with(obj, ['a','b'])

        obj.aws_notes.instance_variable_get(:@aws_notes).should == []      
        obj.aws_notes = ['a','b']
        obj.aws_notes.instance_variable_get(:@aws_notes).should == ['a','b']
        obj.aws_notes.save
      end

      it "should reload the metadata from SimpleDB" do
        obj = DummyClass.new
        Awsymandias::SimpleDB.should_receive(:get).with(Notable::Notes.simpledb_domain, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return({:notes_for_object => ['a','b','c']}, 
                                                                                         {:notes_for_object => ['e','f','g']})
        obj.aws_notes.instance_variable_get(:@aws_notes).should == ['a','b','c']      
        obj.aws_notes.reload
        obj.aws_notes.instance_variable_get(:@aws_notes).should == ['e','f','g']
      end
    end

    context "destroy" do
      it "should be defined and call destroy_metadata if the class being extended by Notable does not already have a destroy method" do
        class DummyClassWithoutDestroy
          include Awsymandias::Notable
          def initialize(name = 'dummy-1'); @name = name; end
          def id; @name; end
        end

        obj = DummyClassWithoutDestroy.new
        obj.respond_to?(:destroy).should == true
        obj.should_receive(:destroy_metadata)
        obj.destroy
      end

      it "should be defined and call destroy_metadata and then the native destroy if the class being extended by Notable has a destroy method" do
        class DummyClassWithDestroy
          include Awsymandias::Notable
          def initialize(name = 'dummy-1'); @name = name; end
          def destroy;  true;  end
          def id; @name; end

          def self.find(ids); ids ;end
        end

        obj = DummyClassWithDestroy.new
        obj.should_receive(:destroy_metadata)
        obj.destroy
      end
    end
    
  end
end