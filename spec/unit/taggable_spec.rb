require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Taggable do
    
    class DummyClass
      include Awsymandias::Taggable
      def initialize(name = 'dummy-1'); @name = name; end
      def id; @name; end
    end
    
    context "simpledb_tags_key" do
        it "should build SimpleDB tag keys properly with defaults for identifier and tag_prefix" do
          Taggable::Tags.simpledb_tags_key(DummyClass.new).should == 'DummyClass__dummy-1'
        end
      
        it "should build SimpleDB tag keys properly with custom identifier and tag_prefix" do
          class DummyClass2
            include Awsymandias::Taggable
            taggable_options :identifier => :funky_id, :tag_prefix => 'Foo'
            def funky_id; 'my_funky_id'; end
          end
      
          Taggable::Tags.simpledb_tags_key(DummyClass2.new).should == 'Foo__my_funky_id'
        end
    end
      
    context "get_tags" do
      it "should get tags properly" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return( :tags_for_object => ['a','b','c'] )
        Taggable::Tags.get_tags(DummyClass.new).should == ['a','b','c']
      end
    
      it "should return an empty array if simpledb returns no tags" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return( nil )
        Taggable::Tags.get_tags(DummyClass.new).should == []
      end
    end
    
    context "instance_identifiers_tagged_with" do
      it "should return an array of object names with that tag" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN, 
                                                        'AwsymandiasTagValue__some tag', 
                                                        {:marshall => false}).and_return( :objects_with_tag => ['DummyClass__dummy-1'] )
        Taggable::Tags.instance_identifiers_tagged_with('some tag').should == ['DummyClass__dummy-1']
      end
    
      it "should return an empty array if simpledb returns no objects with that tag" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN, 
                                                        'AwsymandiasTagValue__some tag', 
                                                        {:marshall => false}).and_return( nil )
        Taggable::Tags.instance_identifiers_tagged_with('some tag').should == []
      end
    end
   
    context "put_tags" do
      it "should set the tags for the main object" do
        obj = DummyClass.new
        Taggable::Tags.should_receive(:put_reverse_tags)
        Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
          key.should == 'DummyClass__dummy-1'
          stuff.should == {:tags_for_object => ["a"]}
        end
        Taggable::Tags.put_tags DummyClass.new, ['a']
      end
            
      it "should delete from SimpleDB if there are no tags" do
        Awsymandias::SimpleDB.should_receive(:get).and_return(:tags_for_object => [])
        Awsymandias::SimpleDB.should_receive(:delete).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN,'DummyClass__dummy-1')
        obj = DummyClass.new
        obj.aws_tags.save
      end
    end
       
    context "put_reverse_tags" do
      it "should add the key of the object to the reverse tag" do
       return_from_get_a = { :objects_with_tag => []   }
       Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
         key.should == 'DummyClass__dummy-1'
         Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
           key.should == 'AwsymandiasTagValue__a'
           Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
             key.should == 'AwsymandiasTagValue__a'
             stuff.should == {:objects_with_tag => ["DummyClass__dummy-1"] }
           end
           return_from_get_a
         end
         return_from_get_a
       end
 
       Taggable::Tags.put_reverse_tags DummyClass.new, ['a']
      end
     
      it "should not do re-put the reverse tag if the object is already in the reverse tag" do
        return_from_get_a = { :objects_with_tag => ['DummyClass__dummy-1']   }
          
        Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
          key.should == 'DummyClass__dummy-1'
          Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
            key.should == 'AwsymandiasTagValue__a'
            Awsymandias::SimpleDB.should_receive(:put).never
            
            return_from_get_a
          end
          { :objects_with_tag => [] }
        end
          
        Taggable::Tags.put_reverse_tags DummyClass.new, ['a']
      end
       
      it "should append the key of the object to the reverse tag" do
        return_from_get_a = { :objects_with_tag => ['DummyClass__dummy-123'] }
        
        Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
          key.should == 'DummyClass__dummy-1'
          Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
            key.should == 'AwsymandiasTagValue__a'
            Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
              key.should == 'AwsymandiasTagValue__a'
              stuff.should == {:objects_with_tag => ['DummyClass__dummy-123', "DummyClass__dummy-1"] }
            end
          
            return_from_get_a
          end
          { :objects_with_tag => [] }
        end
        
        Taggable::Tags.put_reverse_tags DummyClass.new, ['a']
      end
       
      it "should remove the object from reverse tags when tags are removed from the object" do
        return_from_get_a = { :objects_with_tag => ['DummyClass__dummy-123'] }
        return_from_get_b = { :objects_with_tag => ['DummyClass__dummy-123', 'DummyClass__dummy-1'] }
        
        obj = DummyClass.new
        
        Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
          key.should == 'DummyClass__dummy-1'
    
          Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
            key.should == 'AwsymandiasTagValue__b'
            Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
              key.should == 'AwsymandiasTagValue__b'
              stuff.should == {:objects_with_tag => ['DummyClass__dummy-123'] }
              Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
                key.should == 'AwsymandiasTagValue__a'
                Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
                  key.should == 'AwsymandiasTagValue__a'
                  stuff.should == {:objects_with_tag => ['DummyClass__dummy-123', "DummyClass__dummy-1"] }
                end        
                return_from_get_a
              end        
            end
            return_from_get_b
          end
          { :tags_for_object => ['a','b'] }
        end
        
        Taggable::Tags.put_reverse_tags obj, ['a']
      end
       
      it "should delete reverse tags instead of store them if they contain no objects" do
        return_from_get_a = { :objects_with_tag => ['DummyClass__dummy-1'] }
      
        obj = DummyClass.new
      
        Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
          key.should == 'DummyClass__dummy-1'
    
          Awsymandias::SimpleDB.should_receive(:get) do |domain, key, options|
            key.should == 'AwsymandiasTagValue__a'
            Awsymandias::SimpleDB.should_receive(:delete) do |domain, key, stuff, options|
              key.should == 'AwsymandiasTagValue__a'
            end
        
            return_from_get_a
          end
          { :tags_for_object => ['a'] }
        end
       
        Taggable::Tags.put_reverse_tags obj, []
      end
    end
    
    context "Tags class" do
      it "should save tags for the object to SimpleDB" do
        obj = DummyClass.new
        Taggable::Tags.should_receive(:get_tags).with(obj).and_return([])
        Taggable::Tags.should_receive(:put_tags).with(obj, ['a','b'])
    
        obj.aws_tags.instance_variable_get(:@aws_tags).should == []      
        obj.aws_tags = ['a','b']
        obj.aws_tags.instance_variable_get(:@aws_tags).should == ['a','b']
        obj.aws_tags.save
      end
    
      it "should reload the tags from SimpleDB" do
        obj = DummyClass.new
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags::SIMPLEDB_TAG_DOMAIN, 
                                                        'DummyClass__dummy-1', 
                                                        {:marshall => false}).and_return({:tags_for_object => ['a','b','c']}, 
                                                                                         {:tags_for_object => ['e','f','g']})
        obj.aws_tags.instance_variable_get(:@aws_tags).should == ['a','b','c']      
        obj.aws_tags.reload
        obj.aws_tags.instance_variable_get(:@aws_tags).should == ['e','f','g']
      end
    end
    
    context "instances_tagged_with" do
      it "should return an array of instance identifiers tagged with the specified tag" do
        Taggable::Tags.should_receive(:instance_identifiers_tagged_with).with(:a_tag).and_return(['DummyClass__dummy1','DummyClass__dummy2'])
        DummyClass.instances_tagged_with(:a_tag).should == ['dummy1', 'dummy2']
      end
    
      it "should not return instance identifiers that aren't for this class" do
        Taggable::Tags.should_receive(:instance_identifiers_tagged_with).with(:a_tag).and_return(['DummyClass__dummy1','OtherClass__some_instance'])
        DummyClass.instances_tagged_with(:a_tag).should == ['dummy1']
      end
      
      context "destroy" do
        it "should be defined and call destroy_tags if the class being extended by Taggable does not already have a destroy method" do
          class DummyClassWithoutDestroy
            include Awsymandias::Taggable
            def initialize(name = 'dummy-1'); @name = name; end
            def id; @name; end
          end
          
          obj = DummyClassWithoutDestroy.new
          obj.respond_to?(:destroy).should == true
          obj.should_receive(:destroy_tags)
          obj.destroy
        end

        it "should be defined and call destroy_tags and then the native destroy if the class being extended by Taggable has a destroy method" do
          class DummyClassWithDestroy
            def destroy;  true;  end
            include Awsymandias::Taggable
            def initialize(name = 'dummy-1'); @name = name; end
            def id; @name; end

            def self.find(ids); puts ids.inspect ;end
          end
          
          obj = DummyClassWithDestroy.new
          obj.should_receive(:destroy_tags)
          obj.destroy
        end
      end
    end
  end
end