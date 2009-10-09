module Awsymandias
  class LoadBalancer
    include Awsymandias::Taggable
    include Awsymandias::Notable
    attr_reader :name, :aws_created_at, :availability_zones, :dns_name, :name, :instances, :listeners, :health_check

    def self.find(*names)
      names = nil if names.is_a?(Array) && names.empty?
      Awsymandias::RightElb.connection.describe_lbs(names).map { |lb| Awsymandias::LoadBalancer.new lb }
    end

    def self.launch(attribs)
      new_lb = LoadBalancer.new(attribs)
      new_lb.launch
      new_lb
    end

    def self.valid_load_balancer_name?(lb_name);  (lb_name.to_s  =~ /\A[a-zA-Z0-9-]+\Z/) != nil; end
    
    def initialize(attribs)
      raise "Load balancer name can only contain alphanumeric characters or a dash." unless LoadBalancer.valid_load_balancer_name?(attribs[:name])
      
      @listeners = [attribs[:listeners]].flatten.map { |listener| Listener.new listener }
      @terminated = false

      [ :dns_name, :name ].each do |attribute_name| 
        instance_variable_set "@#{attribute_name.to_s}", attribs[attribute_name]
      end
      
      @availability_zones = attribs[:availability_zones]
      if launched?
        @instances = attribs[:instances]
        @unregistered_instances = []
        @health_check = HealthCheck.new self,  attribs[:health_check]
      else
        self.health_check = attribs[:health_check]
        @instances = []
        @unregistered_instances = attribs[:instances]        
      end
    end
    
    def id; name; end
    
    def initializing?; @initializing; end
    
    def availability_zones=(zones = [])
      @availability_zones ||= []
      zones = [zones].flatten
    
      zones_to_enable = zones - @availability_zones
      Awsymandias::RightElb.connection.enable_availability_zones_for_lb @name, zones_to_enable if launched? && !zones_to_enable.empty?
    
      zones_to_disable = @availability_zones - zones
      Awsymandias::RightElb.connection.disable_availability_zones_for_lb @name, zones_to_disable if launched? && !zones_to_disable.empty?
    
      @availability_zones = Awsymandias::RightElb.connection.describe_lbs([@name]).first[:availability_zones]
    end

    def health_check=(attribs)
      @health_check = HealthCheck.new(self, attribs || {})
      @health_check.save if launched?
    end

    def instances=(instance_ids = [])
      instance_ids = [instance_ids].flatten
    
      instances_to_deregister = @instances - instance_ids
      Awsymandias::RightElb.connection.deregister_instances_from_lb @name, instances_to_deregister if launched? && !instances_to_deregister.empty?
    
      instances_to_register = instance_ids - @instances
      Awsymandias::RightElb.connection.register_instances_with_lb @name, instances_to_register if launched? && !instances_to_register.empty?
    
      @instances = Awsymandias::RightElb.connection.describe_lbs([@name]).first[:instances]
    end

    def instance_health
      Awsymandias::RightElb.connection.describe_instance_health @name
    end

    def launch
      raise "Load balancers must have at least one listener defined." if @listeners.empty?
      raise "Load balancers must have at least one availability zone defined." if @availability_zones.empty?
      
      listener_params = @listeners.map { |l| l.attributes }      
      @dns_name = Awsymandias::RightElb.connection.create_lb @name, @availability_zones, listener_params
      sleep 2 # Give AWS a few seconds to learn about the new LB
      self.instances = @unregistered_instances
      @unregistered_instances = nil
      @dns_name
    end

    def launched?
      !@dns_name.nil?
    end

    def reload
      return unless launched?
      data = Awsymandias::RightElb.connection.describe_lbs([self.name]).first
      data.symbolize_keys!
      data.keys.each do |attribute_name|
        instance_variable_set "@#{attribute_name}", data[attribute_name]
      end
      self
    end
    
    def summarize
      output = []
      output << "   Load Balancer '#{name}': \t#{dns_name || "Not Launched"}"
      output << "      Health Check:  "
      health_check.attributes.each_pair {|attrib, value| output.last << "#{attrib}: #{value}\t"}
      output << "      Avail. Zones: #{availability_zones.join ", " }"
      output << "      Instances:  "
      instance_health.each_pair { |instance_id, health| output.last << "#{instance_id} (#{health[:state]}), " }
      output.last.chop!.chop!
      output << "      Listeners:"
      listeners.each do |listener|
        output << "                 "
        listener.attributes.each_pair {|attrib, value| output.last << "#{attrib}: #{value}\t"}
      end
      output.join("\n")
    end
    
    def terminate!
      return unless launched?
      Awsymandias::RightElb.connection.delete_lb name
      destroy
      @terminated = true
    end
    
    def terminated?
      @terminated
    end
    
    def to_simpledb
      name
    end
    
    class HealthCheck
      ATTRIBUTE_NAMES = [:healthy_threshold, :unhealthy_threshold, :interval, :target, :timeout]
      attr_accessor *ATTRIBUTE_NAMES
      
      DEFAULT_SETTINGS = {:healthy_threshold => 3, 
                          :unhealthy_threshold => 5, 
                          :interval => 30, 
                          :target => "HTTP:80", 
                          :timeout => 5
                          }
                          
      def initialize(lb, attribs = {})
        @lb = lb
        attribs = HealthCheck::DEFAULT_SETTINGS.merge attribs
        
        HealthCheck::DEFAULT_SETTINGS.each_pair { |key, value| instance_variable_set "@#{key}", attribs[key] }
      end
      
      def attributes
        returning({}) do |attribs|
          HealthCheck::ATTRIBUTE_NAMES.each { |attrib| attribs[attrib] = instance_variable_get "@#{attrib}"}
        end
      end
      
      def save
        Awsymandias::RightElb.connection.configure_health_check @lb.name, attributes
      end
    end
    
    class Listener
      ATTRIBUTE_NAMES = [:protocol, :load_balancer_port, :instance_port] 
      hash_initializer *ATTRIBUTE_NAMES
      attr_reader *ATTRIBUTE_NAMES
      
      def attributes
        returning({}) do |attribs|
          Listener::ATTRIBUTE_NAMES.each { |attrib| attribs[attrib] = instance_variable_get "@#{attrib}"}
        end
      end      
    end

  end
end