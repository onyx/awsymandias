module Awsymandias
  module EC2
    class << self
      # Define the values for AMAZON_ACCESS_KEY_ID and AMAZON_SECRET_ACCESS_KEY_ID to allow for automatic
      # connection creation.
      def connection
        @connection ||= ::EC2::Base.new(
          :access_key_id     => Awsymandias.access_key_id     || ENV['AMAZON_ACCESS_KEY_ID'],
          :secret_access_key => Awsymandias.secret_access_key || ENV['AMAZON_SECRET_ACCESS_KEY']
        )
      end
      
      def instance_types
        [ 
          Awsymandias::EC2::InstanceTypes::M1_SMALL, 
          Awsymandias::EC2::InstanceTypes::M1_LARGE, 
          Awsymandias::EC2::InstanceTypes::M1_XLARGE, 
          Awsymandias::EC2::InstanceTypes::M2_2XLARGE, 
          Awsymandias::EC2::InstanceTypes::M2_4XLARGE, 
          Awsymandias::EC2::InstanceTypes::C1_MEDIUM, 
          Awsymandias::EC2::InstanceTypes::C1_XLARGE 
        ].index_by(&:name)
      end
    end
    
    InstanceType = Struct.new(:name, :price_per_hour)
    
    # All currently available instance types.
    # TODO Generate dynamically.
    module InstanceTypes
      M1_SMALL  = InstanceType.new("m1.small",  Money.new(8.5))
      M1_LARGE  = InstanceType.new("m1.large",  Money.new(34))
      M1_XLARGE = InstanceType.new("m1.xlarge", Money.new(68))

      M2_2XLARGE = InstanceType.new("m2.2xlarge", Money.new(120))
      M2_4XLARGE = InstanceType.new("m2.4xlarge", Money.new(240))

      C1_MEDIUM = InstanceType.new("c1.medium", Money.new(17))
      C1_XLARGE = InstanceType.new("c1.xlarge", Money.new(68))
    end
        
    # All currently availability zones.
    # TODO Generate dynamically.
    module AvailabilityZones
      US_EAST_1A = "us-east-1a"
      US_EAST_1B = "us-east-1b"
      US_EAST_1C = "us-east-1c"

      EU_WEST_1A = "eu-west-1a"
      EU_WEST_1B = "eu-west-1b"
    end
  
  end  
end