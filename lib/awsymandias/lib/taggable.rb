module Awsymandias
  module Taggable
    
    module ClassMethods
      def instances_tagged_with(tag)
         Tags.instance_identifiers_tagged_with(tag).select do |object_key| 
           object_key =~ /#{@metadata_options[:prefix]}__/ 
         end.map { |object_key| object_key.gsub(/.*__/,'')}
      end
      
      def find_by_tag(tag)
        ids = instances_tagged_with(tag)
        respond_to?(:find) && ids ? find(ids) : ids
      end
    end
    
    def self.included(klass)
      klass.instance_eval { @metadata_options = {:identifier => :id, :prefix => klass.name.split("::").last } }
      klass.extend ClassMethods      
      klass.send :include, Awsymandias::MetadataBase
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