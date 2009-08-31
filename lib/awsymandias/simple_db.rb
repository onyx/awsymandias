module Awsymandias
  module SimpleDB # :nodoc
    class << self
      def connection(opts={})
        @connection ||= ::RightAws::SdbInterface.new Awsymandias.access_key_id || ENV['AMAZON_ACCESS_KEY_ID'],
                                                   Awsymandias.secret_access_key || ENV['AMAZON_SECRET_ACCESS_KEY'],
                                                   { :logger => Logger.new("/dev/null") }.merge(opts)
      end

      def put(domain, name, stuff, options = {})
        options[:replace] ||= true
        options[:marshall] ||= true
        if options[:marshall]
          stuff.each_pair { |key, value| stuff[key] = value.to_yaml.gsub("\n","\\n") }
        end
        connection.put_attributes handle_domain(domain), name, stuff, options[:replace]
      end

      def get(domain, name, options = {})
        options[:marshall] ||= true
        stuff = connection.get_attributes(handle_domain(domain), name)[:attributes] || {}
        if options[:marshall]
          stuff.inject({}) do |hash, (key, value)|
            hash[key.to_sym] = YAML.load(value.first.gsub("\\n","\n"))
            hash
          end
        end
      end

      def delete(domain, name)
        connection.delete_attributes handle_domain(domain), name
      end

      def query(domain_name, query_expression = nil, max_number_of_items = nil, next_token = nil)
        connection.query(domain_name, query_expression, max_number_of_items, next_token)[:items]
      end

      def query_with_attributes(domain_name, attributes=[], query_expression = nil, max_number_of_items = nil, next_token = nil)
        connection.query_with_attributes(domain_name, attributes=[], query_expression, max_number_of_items, next_token)[:items]
      end

      private

      def domain_exists?(domain)
        connection.list_domains[:domains].include?(domain)
      end      

      def handle_domain(domain)
        returning(domain) { connection.create_domain(domain) unless domain_exists?(domain) }
      end
    end
  end  
end
