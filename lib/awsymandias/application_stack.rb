module Awsymandias
  class ApplicationStack
    include Awsymandias::Taggable
    include Awsymandias::Notable
    attr_reader :name, :simpledb_domain, :unlaunched_instances, :instances, :volumes, :roles, :unlaunched_load_balancers, :load_balancers

    DEFAULT_SIMPLEDB_DOMAIN = "application-stack"

    class << self
      def find(name)
        returning(new(name)) do |stack|
          stack.send(:reload_from_metadata!)
          return nil unless stack.launch_begun?
        end
      end

      def launch(name, opts={})
        returning(new(name, opts)) do |stack|
          stack.launch
        end
      end

      def define(name, &block)
        definition = StackDefinition.new(name)
        yield definition if block_given?
        definition.build_stack
      end
    end

    def initialize(name, opts={})
      opts.assert_valid_keys :instances, :simpledb_domain, :volumes, :roles, :load_balancers

      @name = name
      @simpledb_domain = opts[:simpledb_domain] || DEFAULT_SIMPLEDB_DOMAIN
      @instances  = {}
      @unlaunched_instances = {}
      @volumes    = {}
      @roles = {}
      @load_balancers = {}
      @unlaunched_load_balancers = {}
      @terminating = false
      @terminating_instances = {}
      
      if opts[:roles]
        @roles = opts[:roles]
        @roles.keys.each { |role| define_methods_for_role(role) }
      end
      
      if opts[:instances]
        @unlaunched_instances = opts[:instances].stringify_keys
        opts[:instances].each { |name, configuration| define_methods_for_instance(name) }
      end
    
      opts[:volumes].each { |name, configuration| volume(name.to_s, configuration) } if opts[:volumes]
      
      if opts[:load_balancers]
        opts[:load_balancers].each_pair { |lb_name, config| @unlaunched_load_balancers[lb_name.to_s] = config }
      end
    end
    
    def has_instance_called?(inst_name)
      !@instances[inst_name].nil?
    end
    
    def instances
      !@instances.empty? ? @instances.values : {}
    end

    def volume(name, opts = {})
      opts.assert_valid_keys :volume_id, :instance, :unix_device, :snapshot_id, :role, :all_instances
      @volumes[name] = opts
    end

    def define_methods_for_instance(instance_name)
      if !self.metaclass.respond_to?(instance_name)
        self.metaclass.send(:define_method, instance_name) { @instances[instance_name] }
      end
    end

    def define_methods_for_role(role_name)
      self.metaclass.send(:define_method, role_name) do
        @roles[role_name].map { |instance_name| @instances[instance_name] }
      end
    end

    def launch
      store_app_stack_metadata!

      @unlaunched_instances.each_pair do |instance_name, params|
        @instances[instance_name] = Awsymandias::Instance.launch(params)
        @instances[instance_name].name = instance_name
        @unlaunched_instances.delete instance_name
      end
      store_app_stack_metadata!
      
      sleep 2 # There may be a race condition where the instance has been launched but the web service doesn't know about it yet.
      
      @unlaunched_load_balancers.each_pair do |lb_name, params|
        instance_names = params[:instances]
        
        if params[:instances]
          params[:instances].each do |instance_name|
            raise "Load balancer #{lb_name} wants to register instance #{instance_name} but that instance is not launched." if @instances[instance_name.to_s].nil?
          end
          params[:instances] = params.delete(:instances).map { |instance_name| @instances[instance_name.to_s].instance_id } 
        end
        params[:name] = lb_name
        @load_balancers[lb_name] = Awsymandias::LoadBalancer.launch(params)
        @unlaunched_load_balancers.delete lb_name
      end
      store_app_stack_metadata!
      
      attach_volumes
      store_app_stack_metadata!
      
      self
    end
    
    def attach_volumes
      @volumes.each do |volume, options|
        if options[:instance]
          attach_volume_to_instance options
        elsif options[:role]
          create_and_attach_volumes_to_instances send(options[:role]), options
        elsif options[:all_instances]
          create_and_attach_volumes_to_instances instances, options
        else
          raise "Neither role, instance, or all_instances was specified for #{volume} volume"
        end
      end
    end
    
    def attach_volume_to_instance(options)
      volume = Awsymandias::RightAws.describe_volumes([options[:volume_id]]).first
      volume.attach_to_once_running @instances[options[:instance]], options[:unix_device]
    end
    
    def create_and_attach_volumes_to_instances(instances, options)                  
      volumes = instances.map do |i|
        if already_attached_volume = i.volume_attached_to_unix_device(options[:unix_device])
          raise "Another volume (#{already_attached_volume.aws_id}) is already attached to " + 
                "instance #{i.instance_id} at #{options[:unix_device]}."
        end
        
        target_snapshot = Awsymandias::Snapshot.find(options[:snapshot_id]).first
        if target_snapshot
          new_vol = Awsymandias::RightAws.wait_for_create_volume(target_snapshot.id, i.aws_availability_zone)
          new_vol.aws_notes << "Snapshot tags: #{target_snapshot.aws_tags.join(',')}"
          new_vol.aws_notes << "Created for stack '#{@name}'"
          new_vol.aws_notes.save
          new_vol
        end
      end
      
      sleep 2 # There seems to be a race condition between when the volume says it is available and actually being able to attach it
              
      instances.zip(volumes).each do |i, volume|
        volume.attach_to_once_running i, options[:unix_device]
      end
    end
    
    def reload
      raise "Can't reload unless launched" unless (launch_begun? || terminating?)
      @instances.values.each(&:reload)
      @terminating_instances.values.each(&:reload)
      @load_balancers.values.each(&:reload)
      self
    end

    def terminate!
      @terminating = true
      store_app_stack_metadata!
      instances.each do |instance|
        instance.terminate! if instance.running?
        @terminating_instances[instance.name] = @instances.delete(instance.name)
      end
      
      load_balancers.values.each do |load_balancer|
        load_balancer.terminate! if load_balancer.launched?
        @load_balancers.delete(load_balancer.name)
      end
      
      remove_app_stack_metadata!
      destroy
      self
    end

    def terminating?
      @terminating
    end

    def terminated?
      @instances.empty? && @terminating_instances.values.all?(&:terminated?)
    end

    def launch_begun?
      instances.any?
    end

    def launch_complete?
      unlaunched_instances.empty? && unlaunched_load_balancers.empty? && !@instances.empty?
    end

    def running?
      launch_complete? && @instances.values.all?(&:running?)
    end

    def port_open?(port)
      instances.all? { |instance| instance.port_open?(port) }
    end

    def running_cost
      return Money.new(0) unless launch_complete?
      @instances.values.sum { |instance| instance.running_cost }
    end

    def summarize
      output = []
      output << "Stack '#{name}'"
      @instances.each_pair do |name, instance| 
        output << instance.summarize
        output << ''
      end
      @load_balancers.each_pair do |lb_name, lb| 
        output << lb.summarize 
        output << ''
      end
      output.flatten.join("\n")
    end

    private

    def store_app_stack_metadata!
      metadata = {}
      
      [:unlaunched_instances, :unlaunched_load_balancers, :roles].each do |item_name|
        metadata[item_name] = instance_variable_get "@#{item_name}"
      end

      [:instances, :load_balancers].each do |collection|
        metadata[collection] = {}
        instance_variable_get("@#{collection}").each_pair do |item_name, item| 
          metadata[collection][item_name] = item.to_simpledb
        end
      end

      Awsymandias::SimpleDB.put @simpledb_domain, @name, metadata
    end

    def remove_app_stack_metadata!
      Awsymandias::SimpleDB.delete @simpledb_domain, @name
    end

    def reload_from_metadata!
      metadata = Awsymandias::SimpleDB.get @simpledb_domain, @name 
    
      unless metadata.empty?
        metadata[:unlaunched_load_balancers] ||= []
        metadata[:load_balancers] ||= []
        @unlaunched_load_balancers = metadata[:unlaunched_load_balancers]
        unless metadata[:load_balancers].empty?
          live_lbs = Awsymandias::LoadBalancer.find(*metadata[:load_balancers].keys).index_by(&:name)
          metadata[:load_balancers].each_pair do |lb_name, lb|
            if live_lbs[lb_name]
              @load_balancers[lb_name] = live_lbs[lb_name]
            else
              @load_balancers.delete lb_name
            end
          end
        end
        
        @unlaunched_instances = metadata[:unlaunched_instances]
      
        unless metadata[:instances].empty?
          live_instances = Awsymandias::Instance.find(:all, :instance_ids =>                                   
                                                      metadata[:instances].values.map { |inst| inst[:aws_instance_id] }
                                                     ).index_by(&:instance_id)
          metadata[:instances] = metadata[:instances]
          metadata[:instances].each_pair do |instance_name, instance_metadata|
            if live_instances[instance_metadata[:aws_instance_id]]
              @instances[instance_name] = live_instances[instance_metadata[:aws_instance_id]]
              @instances[instance_name].name = instance_name
              define_methods_for_instance(instance_name)
            else
              @instances.delete instance_name
            end
          end
        end
        
        @roles = metadata[:roles]
        @roles.keys.each { |role| define_methods_for_role(role) }          
      end
    end
  end
end
