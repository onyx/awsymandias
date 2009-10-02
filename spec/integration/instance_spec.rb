require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

describe 'a launched instance' do
  
  before :all do
    raise "No Awsymandias keys available.  Please set ENV['AMAZON_ACCESS_KEY_ID'] and ENV['AMAZON_SECRET_ACCESS_KEY']" unless ENV['AMAZON_ACCESS_KEY_ID'] && ENV['AMAZON_SECRET_ACCESS_KEY'] 
    Awsymandias.access_key_id = ENV['AMAZON_ACCESS_KEY_ID'] 
    Awsymandias.secret_access_key = ENV['AMAZON_SECRET_ACCESS_KEY']
    
    if ENV['TEST_STACK_MANUALLY_LAUNCHED']
      @stack = Awsymandias::ApplicationStack.find('instances')
      @stack_lb = @stack.load_balancers['integration-test-balancer']
      @stack_lb_reset_info = { :instances => @stack_lb.instances,
                               :availability_zones => @stack_lb.availability_zones,
                               :health_check => @stack_lb.health_check.attributes
                             }
    else
      raise "Load Balancer should not be launched yet!" unless Awsymandias::RightElb.describe_lbs == []
      @stack = Awsymandias::ApplicationStack.define('instances') do |s|
        s.instance :box,  :image_id => 'ami-20b65349'
        s.instance :box2, :image_id => 'ami-20b65349'
        s.load_balancer "integration-test-balancer", 
                        :instances => [ :box ], 
                        :availability_zones => [ Awsymandias::EC2::AvailabilityZones::US_EAST_1B ], 
                        :health_check => { :healthy_threshold   => 2, 
                                           :unhealthy_threshold => 3,
                                           :timeout => 3,
                                           :interval => 5,
                                           :target => "TCP:22",
                                         },
                        :listeners => [{:protocol => 'TCP', 
                                        :load_balancer_port => 80, 
                                        :instance_port => 3080
                                       },
                                       {:protocol => 'TCP', 
                                        :load_balancer_port => 443, 
                                        :instance_port => 443
                                       }
                                      ]
        s.role :some_role, :box
      end
    
      @stack.launch
      Awsymandias.wait_for('stack to start', 5) { @stack.reload.running? }
    end
  end
  
  
  after :all do
    if ENV['TEST_STACK_MANUALLY_LAUNCHED']
      @stack_lb.instances = @stack_lb_reset_info[:instances]
      @stack_lb.availability_zones = @stack_lb_reset_info[:availability_zones]
      @stack_lb.health_check = @stack_lb_reset_info[:health_check]
    else
      @stack.terminate!
    end
  end
  
  it "should show the stack as running" do
    @stack.running?.should be_true
  end

  it "instances:  should be available through a method on stack" do
    @stack.box.should_not be_nil
  end

  it "instances:  should be available through the role collection" do
    @stack.send(:some_role).should == [ @stack.box ]
  end

  it "instances:  should show as running" do
    @stack.box.running?.should be_true
  end

  it "simpledb:  should be saved" do
    found_stack = Awsymandias::ApplicationStack.find('instances')
    
    found_stack.box.should_not be_nil
    found_stack.box.running?.should be_true
    
    found_stack.load_balancers['integration-test-balancer'].should_not be_nil
    found_stack.load_balancers['integration-test-balancer'].launched?.should be_true
  end
    
  it "load_balancers:  should be available through the load_balancers collection" do
    @stack.load_balancers['integration-test-balancer'].should_not be_nil
  end
  
  it "load_balancers:  should set up the load balancer with the specified health check paramaters" do
    expected_health_check = { :healthy_threshold   => 2, 
                              :unhealthy_threshold => 3,
                              :timeout => 3,
                              :interval => 5,
                              :target => "TCP:22",
                            }
                            
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.health_check.attributes.should == expected_health_check
  end
    
  it "load_balancers:  should update the health check when an assignment happens" do
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    expected_health_check = { :healthy_threshold   => 3, 
                              :unhealthy_threshold => 4,
                              :timeout => 5,
                              :interval => 10,
                              :target => "TCP:22",
                            }
                            
    found_lb.health_check.attributes.should_not == expected_health_check    
    found_lb.health_check = expected_health_check

    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.health_check.attributes.should == expected_health_check    
  end  
    
  it "load_balancers:  should add/remove instances when an assignment happens" do
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.instances.should == [ @stack.box.instance_id ] 

    found_lb.instances = [ @stack.box.instance_id, @stack.box2.instance_id ]
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.instances == [ @stack.box.instance_id, @stack.box2.instance_id ]

    found_lb.instances = [ @stack.box2.instance_id ]
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.instances == [ @stack.box2.instance_id ]
  end  
    
  it "load_balancers:  should update the availability zones when an assignment happens" do
    availability_zone_a = Awsymandias::EC2::AvailabilityZones::US_EAST_1A
    availability_zone_b = Awsymandias::EC2::AvailabilityZones::US_EAST_1B

    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.availability_zones.should == [ availability_zone_b ]

    found_lb.availability_zones = [ availability_zone_a, availability_zone_b ]
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.availability_zones == [ availability_zone_a, availability_zone_b ]

    found_lb.availability_zones = [ availability_zone_a ]
    found_lb = Awsymandias::LoadBalancer.find("integration-test-balancer").first
    found_lb.availability_zones == [ availability_zone_a ]
  end  
    
end