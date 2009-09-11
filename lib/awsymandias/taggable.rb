module Awsymandias
  module Taggable
    
    module ClassMethods
      attr_reader :tag_options

      def taggable_options(options = {})
        @tag_options.merge!(options)
      end

      def instances_tagged_with(tag)
         Tags.instance_identifiers_tagged_with(tag).select { |object_key| object_key =~ /#{@tag_options[:tag_prefix]}__/ }.map { |object_key| object_key.gsub(/.*__/,'')}
      end
    end
    
    module ClassMethodsWithFind
        def find_instances_by_tag(tag)
          find instances_tagged_with(tag)
        end
    end
    
    def self.included(klass)
      klass.extend ClassMethods      
      klass.extend ClassMethodsWithFind if klass.respond_to?(:find)

      if klass.instance_methods.include?('destroy')
        klass.class_eval <<-END
          def destroy_with_tags
            destroy_tags
            destroy_without_tags
          end
        
          alias_method_chain :destroy, :tags
          END
        else
          klass.class_eval "def destroy; destroy_tags; end"
        end
      
      klass.instance_eval { @tag_options = {:identifier => :id, :tag_prefix => klass.name.split("::").last } }
    end

    
    def destroy_tags
      tags = []
    end

    def aws_tags
      @aws_tags ||= Tags.find self
    end

    def aws_tags=(tags)
      @aws_tags = Tags.new tags, self
      @aws_tags
    end

    class Tags
      include Enumerable
      attr_accessor :tagged_object, :original_tags

      SIMPLEDB_TAG_DOMAIN = 'awsymandias-tags'

      class << self
        def get_tags(tagged_object)
          raw_get = Awsymandias::SimpleDB.get(SIMPLEDB_TAG_DOMAIN, simpledb_tags_key(tagged_object), {:marshall => false})
          raw_get && !raw_get[:tags_for_object].blank? ? raw_get[:tags_for_object] : []
        end

        def instance_identifiers_tagged_with(tag)
          raw_get = Awsymandias::SimpleDB.get(SIMPLEDB_TAG_DOMAIN, "AwsymandiasTagValue__#{tag}", {:marshall => false})
          raw_get && !raw_get[:objects_with_tag].blank? ? raw_get[:objects_with_tag] : []
        end

        def put_reverse_tags(tagged_object, tags)
          removed_tags = tagged_object.aws_tags.original_tags - tags
          removed_tags.each do |tag|
            objects_with_tag = instance_identifiers_tagged_with(tag) - [simpledb_tags_key(tagged_object)]
            if objects_with_tag.empty?
              Awsymandias::SimpleDB.delete SIMPLEDB_TAG_DOMAIN, "AwsymandiasTagValue__#{tag}"
            else
              Awsymandias::SimpleDB.put SIMPLEDB_TAG_DOMAIN, 
                                        "AwsymandiasTagValue__#{tag}", 
                                        {:objects_with_tag => objects_with_tag }, 
                                        :marshall => false
            end
          end
          
          tags.each do |tag|
            objects_with_tag = instance_identifiers_tagged_with(tag)
            unless objects_with_tag.include? simpledb_tags_key(tagged_object)
              objects_with_tag << simpledb_tags_key(tagged_object)
              Awsymandias::SimpleDB.put SIMPLEDB_TAG_DOMAIN, 
                                        "AwsymandiasTagValue__#{tag}", 
                                        {:objects_with_tag => objects_with_tag }, 
                                        :marshall => false
            end
          end
        end

        def put_tags(tagged_object, tags)
          if tags.empty?
            Awsymandias::SimpleDB.delete SIMPLEDB_TAG_DOMAIN, simpledb_tags_key(tagged_object)
          else
            Awsymandias::SimpleDB.put SIMPLEDB_TAG_DOMAIN, 
                                      simpledb_tags_key(tagged_object), 
                                      {:tags_for_object => tags}, 
                                      :marshall => false
          end
          Tags.put_reverse_tags(tagged_object, tags)
        end

        def find(tagged_object)
          fetched_tags = get_tags(tagged_object)
          collection = new fetched_tags, tagged_object
          collection.original_tags = fetched_tags
          collection
        end
      
        def simpledb_tags_key(tagged_object)
          options = tagged_object.class.tag_options
          "#{options[:tag_prefix]}__#{tagged_object.send(options[:identifier])}"
        end
      end
      
      
      def initialize(new_tags, tagged_object)
        @aws_tags = new_tags || []
        @tagged_object = tagged_object
      end

      def destroy
        Tags.put_tags(@tagged_object, [])
      end
      
      def each
        @aws_tags.each { |tag| yield tag }
      end
      
      def inspect
        @aws_tags.inspect
      end
      
      def reload
        @aws_tags = Tags.get_tags(@tagged_object)
      end
      
      def save
        Tags.put_tags(@tagged_object, @aws_tags)
      end
    end
    
  end
end