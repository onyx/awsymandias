module Awsymandias
  module Taggable
    include Notable
    
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
      super
      klass.instance_eval { @metadata_options = {:identifier => :id, :prefix => klass.name.split("::").last } }
      klass.extend Awsymandias::Notable::ClassMethods
      klass.extend ClassMethods      
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
    
    def destroy_with_tags
      self.aws_tags = []
      self.aws_tags.save
      destroy_without_tags
    end
    alias_method_chain :destroy, :tags

    class Tags < Awsymandias::Notable::Notes
      class << self
      
        def metadata_label; 'tag'; end
        
        def instance_identifiers_tagged_with(tag)
          raw_get = Awsymandias::SimpleDB.get(simpledb_domain, tag_simpledb_key(tag), {:marshall => false})
          raw_get && !raw_get[:objects_with_tag].blank? ? raw_get[:objects_with_tag] : []
        end

        def put_metadata(extended_object, tags)
          super
          clear_removed_reverse_tags(extended_object, tags)
          put_current_reverse_tags(extended_object, tags)
        end

        def put_reverse_tag(tag, object_ids)
          if object_ids.empty?
            Awsymandias::SimpleDB.delete simpledb_domain, tag_simpledb_key(tag)
          else
            Awsymandias::SimpleDB.put simpledb_domain, tag_simpledb_key(tag), {:objects_with_tag => object_ids }, :marshall => false
          end
        end

        private
        
        def clear_removed_reverse_tags(extended_object, tags)
          original_tags = extended_object.aws_tags.instance_variable_get("@original_tags") || []
          (original_tags - tags).each do |tag|
            objects_to_have_tag = instance_identifiers_tagged_with(tag).reject { |object_id| object_id == simpledb_key(extended_object) }
            put_reverse_tag tag, objects_to_have_tag
          end
        end

        def put_current_reverse_tags(extended_object, tags)
          tags.each do |tag|
            objects_to_have_tag = instance_identifiers_tagged_with(tag)
            unless objects_to_have_tag.include? simpledb_key(extended_object)
              put_reverse_tag tag, objects_to_have_tag.push( simpledb_key( extended_object) ) 
            end
          end
        end

        def tag_simpledb_key(tag)
          "AwsymandiasTagValue__#{tag}"
        end

      end
    end
    
  end
end