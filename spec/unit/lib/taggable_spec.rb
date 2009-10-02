require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../../lib/awsymandias")

module Awsymandias
  describe Taggable do
    
    class DummyClass
      include Awsymandias::Taggable
      def initialize(name = 'dummy-1'); @name = name; end
      def id; @name; end
    end
    
    describe "find_by_tag" do
      it "should call find with the ids from find_instances_by_tag if the class has a find method" do
        class DummyClassWithFind
          include Awsymandias::Taggable
          def initialize(name = 'dummy-1'); @name = name; end
          def id; @name; end
          def self.find(ids); end;
        end
        DummyClassWithFind.should_receive(:instances_tagged_with).with('some_tag').and_return(['some_id'])
        DummyClassWithFind.should_receive(:find).with(['some_id']).and_return( [ mock(:id => 'some_id') ] )
        DummyClassWithFind.find_by_tag('some_tag').map(&:id).should == [ 'some_id' ]
      end

      it "should return an array of ids from find_instances_by_tag if the class does not have a find method" do
        DummyClass.should_receive(:instances_tagged_with).with('some_tag').and_return(['some_id'])
        DummyClass.find_by_tag('some_tag').should == ['some_id']
      end

      it "should not call find if find_instances_by_tag returns no ids" do
        DummyClass.should_receive(:instances_tagged_with).with('some_tag').and_return(nil)
        DummyClass.should_receive(:find).never
        DummyClass.find_by_tag('some_tag').should be_nil
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

    context "instance_identifiers_tagged_with" do
      it "should return an array of object names with that tag" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags.simpledb_domain, 
                                                        'AwsymandiasTagValue__some tag', 
                                                        {:marshall => false}).and_return( :objects_with_tag => ['DummyClass__dummy-1'] )
        Taggable::Tags.instance_identifiers_tagged_with('some tag').should == ['DummyClass__dummy-1']
      end

      it "should return an empty array if simpledb returns no objects with that tag" do
        Awsymandias::SimpleDB.should_receive(:get).with(Taggable::Tags.simpledb_domain, 
                                                        'AwsymandiasTagValue__some tag', 
                                                        {:marshall => false}).and_return( nil )
        Taggable::Tags.instance_identifiers_tagged_with('some tag').should == []
      end
    end

    context "put_metadata" do
      it "should also call put_reversetags" do
        obj = DummyClass.new
        Taggable::Tags.should_receive(:put_reverse_tags)
        Awsymandias::SimpleDB.should_receive(:put) do |domain, key, stuff, options|
          key.should == 'DummyClass__dummy-1'
          stuff.should == {:tags_for_object => ["a"]}
        end
        Taggable::Tags.put_metadata DummyClass.new, ['a']
      end
    end
    
    context "destroy" do
      it "should destroy tags" do
        class DummyClassWithoutDestroy
          include Awsymandias::Taggable
          def initialize(name = 'dummy-1'); @name = name; end
          def id; @name; end
        end

        obj = DummyClassWithoutDestroy.new
        Notable::Notes.should_receive(:put_metadata).with(obj, [])
        Taggable::Tags.should_receive(:put_metadata).with(obj, [])
        obj.destroy
      end
    end    
    
  end
end