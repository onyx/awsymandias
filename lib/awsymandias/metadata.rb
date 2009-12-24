module Awsymandias
  
  class Metadata

    class << self

      def put(domain, name, metadata, options = {})
        expand_attribute(metadata, :load_balancers)
        expand_attribute(metadata, :unlaunched_load_balancers)
        Awsymandias::SimpleDB.put(domain, name, metadata, options)
      end

      def get(domain, name, options = {})
        metadata = Awsymandias::SimpleDB.get(domain, name, options)
        collapse_attribute(metadata, :load_balancers)
        collapse_attribute(metadata, :unlaunched_load_balancers)
        metadata
      end

      def delete(domain, name)
        Awsymandias::SimpleDB.delete(domain, name)
      end

      private
      def expand_attribute(metadata, attribute)
        if(metadata[attribute])
            attributes_count = 0
        
            metadata[attribute].each_pair do |lb_name, lb|
              attributes_count = attributes_count + 1
              metadata["#{attribute.to_s.chop}#{attributes_count}".to_sym] = {lb_name => lb} 
            end  
            metadata["#{attribute}_count".to_sym] = attributes_count.to_s
            metadata.delete(attribute)
        end
        metadata
      end
      
      def collapse_attribute(metadata, attribute)
        count_key = "#{attribute}_count".to_sym
        count = metadata[count_key]
        if (count)
          metadata[attribute] = {}

          (0...count.to_i).each do |i|
            lb_name = "#{attribute.to_s.chop}#{i+1}".to_sym
            metadata[attribute].merge!(metadata[lb_name])
            metadata.delete(lb_name) 
          end  

          metadata.delete(count_key)
        end
      end  
      
    end    

  end

end