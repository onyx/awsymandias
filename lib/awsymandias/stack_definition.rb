module Awsymandias
  class StackDefinition
    include Awsymandias::Taggable
    include Awsymandias::Notable
    attr_reader :name, :defined_instances, :defined_volumes, :defined_roles, :defined_load_balancers, :defined_subnet_id
    
    def initialize(name)
      @name = name.to_s
      @defined_instances = {}
      @defined_volumes = {}
      @defined_roles = {}
      @defined_load_balancers = {}
      @defined_subnet_id = nil
    end
    
    def build_stack
      Awsymandias::ApplicationStack.new(name, 
        :instances => defined_instances,
        :volumes => defined_volumes,
        :roles => defined_roles,
        :load_balancers => defined_load_balancers,
        :subnet_id => defined_subnet_id
      )
    end
    
    def id; name; end
 
    def instance(name, config={})
      extract_roles(config).each { |r| role(r, name) }
      @defined_instances[name.to_s] = config
    end
    
    def instances(*names)
      config = names.extract_options!
      roles = extract_roles(config)
      names.each do |name| 
        roles.each { |r| role(r, name.to_s) }
        instance(name.to_s, config) 
      end
    end
    
    def load_balancer(name, configuration = {})
      name = name.to_s.gsub(/[\W_]+/,'-')
      @defined_load_balancers[name] = configuration
    end
    
    def role(name, *instance_names)
      @defined_roles[name] ||= []
      @defined_roles[name] += instance_names.map { |name| name.to_s }
    end
    
    def vpc_subnet_id subnet
      @defined_subnet_id = subnet
    end
    
    def terminate!; destroy; end
    
    def volume(name, configuration={})
      configuration[:instance] = configuration[:instance].to_s if configuration[:instance]
      @defined_volumes[name.to_s] = configuration
    end
    
    def volumes(*names)
      configuration = names.extract_options!
      names.each { |name| volume(name, configuration) }
    end
   
    private
    def extract_roles(config)
      [config.delete(:roles), config.delete(:role)].flatten.compact
    end
    
  end
end