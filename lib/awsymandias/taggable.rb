module Awsymandias
  module Taggable
    
    module ClassMethods
      attr_reader :metadata_options

      def taggable_options(options = {})
        @metadata_options.merge!(options)
      end

      def instances_tagged_with(tag)
         Tags.instance_identifiers_tagged_with(tag).select do |object_key| 
           object_key =~ /#{@metadata_options[:prefix]}__/ 
         end.map { |object_key| object_key.gsub(/.*__/,'')}
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
      
      klass.instance_eval do
        @metadata_options = {:identifier => :id, :prefix => klass.name.split("::").last } 
      end
    end
    
    def destroy_tags
      self.aws_tags = []
      aws_tags.save
    end
    
    def aws_tags
      @aws_tags ||= Tags.find self
    end
    
    def aws_tags=(tags)
      original_tags = @aws_tags.nil? ? [] : @aws_tags.instance_variable_get("@original_tags")
      @aws_tags = Tags.new tags, self
      @aws_tags.instance_variable_set "@original_tags", original_tags
      @aws_tags
    end

    class Tags < Awsymandias::MetadataCollection
      class << self
      
        def metadata_label; 'tag'; end
        
        def instance_identifiers_tagged_with(tag)
          raw_get = Awsymandias::SimpleDB.get(simpledb_domain, "AwsymandiasTagValue__#{tag}", {:marshall => false})
          raw_get && !raw_get[:objects_with_tag].blank? ? raw_get[:objects_with_tag] : []
        end

        def put_reverse_tags(extended_object, tags)
          original_tags = extended_object.aws_tags.instance_variable_get("@original_tags") 
          if original_tags && !original_tags.empty?
            removed_tags = original_tags - tags
            removed_tags.each do |tag|
              objects_with_tag = instance_identifiers_tagged_with(tag) - [simpledb_key(extended_object)]
              if objects_with_tag.empty?
                Awsymandias::SimpleDB.delete simpledb_domain, "AwsymandiasTagValue__#{tag}"
              else
                Awsymandias::SimpleDB.put simpledb_domain, 
                                          "AwsymandiasTagValue__#{tag}", 
                                          {:objects_with_tag => objects_with_tag }, 
                                          :marshall => false
              end
            end
          end
          
          tags.each do |tag|
            objects_with_tag = instance_identifiers_tagged_with(tag)
            unless objects_with_tag.include? simpledb_key(extended_object)
              objects_with_tag << simpledb_key(extended_object)
              Awsymandias::SimpleDB.put simpledb_domain, 
                                        "AwsymandiasTagValue__#{tag}", 
                                        {:objects_with_tag => objects_with_tag }, 
                                        :marshall => false
            end
          end
        end

        def put_metadata_with_reverse(extended_object, tags)
          put_metadata_without_reverse(extended_object, tags)
          Tags.put_reverse_tags(extended_object, tags)
        end
        alias_method_chain :put_metadata, :reverse

      end
    end
    
  end
end