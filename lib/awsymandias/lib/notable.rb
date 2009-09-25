require "forwardable"

module Awsymandias
  module Notable
        
    def self.included(klass)  
      klass.instance_eval { @metadata_options = {:identifier => :id, :prefix => klass.name.split("::").last } }
      klass.send :include, Awsymandias::MetadataBase
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

  end
end