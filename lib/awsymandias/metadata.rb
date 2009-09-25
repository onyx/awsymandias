module Awsymandias  
  
  module MetadataBase    
    module ClassMethods
      attr_reader :metadata_options

      def metadata_options(options = {})
        @metadata_options.merge!(options)
      end
    end
    
    def self.included(klass)
      klass.extend ClassMethods      
      klass.instance_eval do
      
        def method_added(method_name)
          if !@in_method_added_block && method_name == :destroy
            @in_method_added_block = true
            alias_method_chain :destroy, :metadata
            @in_method_added_block = false
          end
        end

        unless klass.instance_methods.include?('destroy')
            klass.class_eval "def destroy; nil; end"
        end

      end
    end

    def destroy_with_metadata
      destroy_metadata
      destroy_without_metadata
    end
    
    def destroy_metadata
      [:aws_tags, :aws_notes].each do |attrib|
        if instance_variables.include? "@#{attrib}"
          self.send("#{attrib}=", [])
          self.send("#{attrib}").save
        end
      end
    end
  end
  
  class MetadataCollection
    include Enumerable
    attr_accessor :extended_object
  
    class << self
      def collection_instance_variable_name
        "@aws_#{metadata_label.pluralize}"
      end      

      def find(extended_object)
        fetched_metadata = get_metadata(extended_object)
        collection = new fetched_metadata, extended_object
        collection.instance_variable_set "@original_#{metadata_label.pluralize}", fetched_metadata
        collection
      end

      def get_metadata(extended_object)
        raw_get = Awsymandias::SimpleDB.get(simpledb_domain, simpledb_key(extended_object), {:marshall => false})
        raw_get && !raw_get[:"#{metadata_label.pluralize}_for_object"].blank? ? raw_get[:"#{metadata_label.pluralize}_for_object"] : []
      end

      def put_metadata(extended_object, metadata)
        if metadata.empty?
          Awsymandias::SimpleDB.delete simpledb_domain, simpledb_key(extended_object)
        else
          Awsymandias::SimpleDB.put simpledb_domain, 
                                    simpledb_key(extended_object), 
                                    {:"#{metadata_label.pluralize}_for_object" => metadata}, 
                                    :marshall => false
        end
      end
  
      def simpledb_domain
        "awsymandias-#{metadata_label}".pluralize
      end
    
      def metadata_label
        'metadata'
      end

      def simpledb_key(extended_object)
        options = extended_object.class.metadata_options
        "#{options[:prefix]}__#{extended_object.send(options[:identifier])}"
      end
    end

    def initialize(new_metadata, extended_object)
      instance_variable_set collection_instance_variable_name, (new_metadata || [])
      @extended_object = extended_object
    
      class_eval <<-END
        extend ::Forwardable
        def_delegators :#{collection_instance_variable_name}, :<<, :+, :-, :first, :last, :size, :uniq, :join, :each, :inspect
      END
    end

    def reload
      instance_variable_set collection_instance_variable_name, self.class.get_metadata(@extended_object)
    end
  
    def save
      collection = instance_variable_get(collection_instance_variable_name)
      self.class.put_metadata(@extended_object, collection)
      instance_variable_set "@original_#{self.class.metadata_label.pluralize}", collection
    end

    def destroy
      self.class.put_metadata(@extended_object, [])
    end
  
    private
  
    def collection_instance_variable_name
      self.class.collection_instance_variable_name
    end      
  end
end
