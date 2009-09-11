require "forwardable"

module Awsymandias
  module Notable
    
    module ClassMethods
      attr_reader :metadata_options
    
      def notable_options(options = {})
        @metadata_options.merge!(options)
      end
    end
    
    
    def self.included(klass)
      klass.extend ClassMethods      
    
      if klass.instance_methods.include?('destroy')
        klass.class_eval <<-END
          def destroy_with_notes
           destroy_notes
           destroy_without_notes
          end
        
          alias_method_chain :destroy, :notes
          END
        else
          klass.class_eval "def destroy; destroy_notes; end"
        end
      
      klass.instance_eval { @metadata_options = {:identifier => :id, :prefix => klass.name.split("::").last } }
    end
    
    def destroy_notes
      self.aws_notes = []
      self.aws_notes.save
    end
    
    def aws_notes
      @aws_notes ||= Notes.find self
    end
    
    def aws_notes=(notes)
      @aws_notes = Notes.new notes, self
      @aws_notes
    end

    class Notes< Awsymandias::MetadataCollection
      def self.metadata_label; 'note'; end
    end
    #     
    #   include Enumerable
    #   extend ::Forwardable
    #   def_delegators :@aws_notes, :<<, :+, :-, :first, :last, :size, :uniq, :join
    #   
    #   attr_accessor :noted_object, :original_notes
    # 
    #   SIMPLEDB_NOTE_DOMAIN = 'awsymandias-notes'
    # 
    #   class << self
    #     def get_notes(noted_object)
    #       raw_get = Awsymandias::SimpleDB.get(SIMPLEDB_NOTE_DOMAIN, simpledb_notes_key(noted_object), {:marshall => false})
    #       raw_get && !raw_get[:notes_for_object].blank? ? raw_get[:notes_for_object] : []
    #     end
    # 
    #     def put_notes(noted_object, notes)
    #       if notes.empty?
    #         Awsymandias::SimpleDB.delete SIMPLEDB_NOTE_DOMAIN, simpledb_notes_key(noted_object)
    #       else
    #         Awsymandias::SimpleDB.put SIMPLEDB_NOTE_DOMAIN, 
    #                                   simpledb_notes_key(noted_object), 
    #                                   {:notes_for_object => notes}, 
    #                                   :marshall => false
    #       end
    #     end
    # 
    #     def find(noted_object)
    #       fetched_notes = get_notes(noted_object)
    #       collection = new fetched_notes, noted_object
    #       collection.original_notes = fetched_notes
    #       collection
    #     end
    #   
    #     def simpledb_notes_key(noted_object)
    #       options = noted_object.class.note_options
    #       "#{options[:note_prefix]}__#{noted_object.send(options[:identifier])}"
    #     end
    #   end
    #   
    #   
    #   def initialize(new_notes, noted_object)
    #     @aws_notes = new_notes || []
    #     @noted_object = noted_object
    #   end
    # 
    # 
    #   def destroy
    #     Notes.put_notes(@noted_object, [])
    #   end
    #   
    #   def each
    #     @aws_notes.each { |note| yield note }
    #   end
    #   
    #   def inspect
    #     @aws_notes.inspect
    #   end
    #   
    #   def reload
    #     @aws_notes = Notes.get_notes(@noted_object)
    #   end
    #   
    #   def save
    #     Notes.put_notes(@noted_object, @aws_notes)
    #   end
    # end
    # 
  end
end