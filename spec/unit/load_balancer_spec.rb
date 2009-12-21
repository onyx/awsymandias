require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe LoadBalancer do

    before :each do
      Awsymandias::RightElb.should_receive(:connection).any_number_of_times.and_return(@elb_connection = mock('connection'))
      @elb_connection.should_receive(:configure_health_check).any_number_of_times.and_return(lambda { @lb.health_check })
    end
        
    def raises_error(message)
      @error_raised = false
      yield
    rescue => error
      @error_raised = true      
      fail "Expected an exception to be raised with message '#{message}' but got '#{error.message}'" if message != error.message
    ensure
      fail "Expected an exception to be raised with message '#{message}' but no exception was raised" unless @error_raised
    end
        
    DEFAULT_LB_ATTRIBUTES = {:aws_created_at => nil,
                            :availability_zones => ["us-east-1b"],
                            :dns_name => nil,
                            :name => "RobTest",
                            :instances => ["i-5752453e"],
                            :listeners => [{:protocol=>"HTTP", :load_balancer_port=>80, :instance_port=>3080},
                                          {:protocol=>"HTTP", :load_balancer_port=>8080, :instance_port=>3081}
                                          ],
                            :health_check => { :healthy_threshold=>10,
                                               :unhealthy_threshold=>3,
                                               :interval=>31,
                                               :target=>"TCP:3081",
                                               :timeout=>6
                                             }
                           }
                           
    def populated_load_balancer(attribs = {})
      @lb = LoadBalancer.new DEFAULT_LB_ATTRIBUTES.merge(attribs)
      @lb
    end

    describe "valid_load_balancer_name" do
      it "should return true for a valid load balancer name" do
        LoadBalancer.valid_load_balancer_name?('balancer-1').should == true
      end

      it "should return false for a load balancer name containing an underscore" do
        LoadBalancer.valid_load_balancer_name?('balancer_1').should == false
      end

      it "should return false for a load balancer name containing a period" do
        LoadBalancer.valid_load_balancer_name?('balancer.1').should == false
      end

      it "should return false for a load balancer name containing a colon" do
        LoadBalancer.valid_load_balancer_name?('balancer:1').should == false
      end

      it "should return false for a load balancer name containing a slash" do
        LoadBalancer.valid_load_balancer_name?('balancer/1').should == false
      end

      it "should return false for an invalid load balancer name that is a symbol" do
        LoadBalancer.valid_load_balancer_name?(:balancer_1).should == false
      end
    end
    
    describe 'initialize' do
      it "should initialize new HealthCheck and Listener objects" do
        lb = populated_load_balancer
        lb.health_check.is_a?(LoadBalancer::HealthCheck).should == true
        lb.listeners.first.is_a?(LoadBalancer::Listener).should == true
      end
      
      it "should raise an error when trying to initialize a load balancer with an invalid name" do
        raises_error("Load balancer name can only contain alphanumeric characters or a dash.") do
          lb = populated_load_balancer :name => "invalid_name"
        end
      end
      
      it "should populate unregistered_instances and set instances to an empty array if the load balancer is not launched" do
        lb = populated_load_balancer :dns_name => nil, :instances => [:an_instance]
        lb.instance_variable_get("@instances").should == []
        lb.instance_variable_get("@unregistered_instances").should == [:an_instance]
      end
      
      it "should populate instances and set unregistered_instances to an empty array if the load balancer is launched" do
        lb = populated_load_balancer :dns_name => :something, :instances => [:an_instance]
        lb.instance_variable_get("@unregistered_instances").should == []
        lb.instance_variable_get("@instances").should == [:an_instance]
      end
    end
    
    describe "availability_zones=" do
      it "should remove availability_zones that are not in the passed list but are enabled in the load balancer" do
        lb = populated_load_balancer :dns_name => :something, :availability_zones => [:zone_1, :zone_2]
        
        desired_zones = [:zone_2]
    
        @elb_connection.should_receive(:disable_availability_zones_for_lb).with(lb.name, [:zone_1]).and_return(desired_zones)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:availability_zones => desired_zones}])
        lb.availability_zones = desired_zones
      end
      
      it "should add availability_zones that are in the passed list but not already in the load balancer" do
        lb = populated_load_balancer :dns_name => :something, :availability_zones => [:zone_1]
        
        desired_zones = [:zone_1, :zone_2]
        
        @elb_connection.should_receive(:enable_availability_zones_for_lb).with(lb.name, [:zone_2]).and_return(desired_zones)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:availability_zones => desired_zones}])
    
        lb.availability_zones = desired_zones
      end      
    
      it "should update the availability_zones attribute" do
        lb = populated_load_balancer :dns_name => :something, :availability_zones => [:zone_1]
        
        desired_zones = [:zone_1, :zone_2]
        
        @elb_connection.should_receive(:enable_availability_zones_for_lb).with(lb.name, [:zone_2]).and_return(desired_zones)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:availability_zones => desired_zones}])
        
        lb.availability_zones = desired_zones
        lb.availability_zones.should == desired_zones
      end
    end
    
    describe "find" do
      it "should return an array of Awsymandias::LoadBalancer objects." do
        names = ['elb-1','elb-1']
        @elb_connection.should_receive(:describe_lbs).with(names).and_return([{:name => 'elb-1', :instances => anything }, {:name => 'elb-2', :instances => anything }])
        
        load_balancers = LoadBalancer.find(*names)
        load_balancers.size.should == 2
      end
    end
      
    describe "health_check=" do
      it "should not call save if the load_balancer is not launched" do        
        health_check = LoadBalancer::HealthCheck.new populated_load_balancer
        LoadBalancer::HealthCheck.should_receive(:new).and_return(health_check)
        health_check.should_receive(:save).never
        
        lb = populated_load_balancer :dns_name => nil
      end
      
      it "should try to configure health check with new parameters" do
        custom_settings = {:healthy_threshold => :custom_healthy_threshold, 
                           :unhealthy_threshold => :custom_unhealthy_threshold, 
                           :interval => :custom_interval, 
                           :target => :custom_target, 
                           :timeout => :custom_timeout
                          }
        
        lb = populated_load_balancer
        health_check = LoadBalancer::HealthCheck.new lb, custom_settings
        
        custom_settings.each_pair { |setting_name, value| health_check.send(setting_name).should == value }
      end
      
      it "should use defaults for attributes that are not passed in" do
        lb = populated_load_balancer
        health_check = LoadBalancer::HealthCheck.new lb
        
        LoadBalancer::HealthCheck::DEFAULT_SETTINGS.each_pair { |setting_name, value| health_check.send(setting_name).should == value }
      end
    end
    
    describe "instances=" do
      it "should deregister instances that are not in the passed list but are registered with the load balancer" do
        lb = populated_load_balancer :dns_name => :something, :instances => [:instance_1, :instance_2]
        
        desired_instances = [:instance_2]
        
        @elb_connection.should_receive(:deregister_instances_from_lb).with(lb.name, [:instance_1]).and_return(desired_instances)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:instances => desired_instances}])
        lb.instances = desired_instances
      end
      
      it "should register instances that are in the passed list but are not registered with the load balancer" do
        lb = populated_load_balancer :dns_name => :something, :instances => [:instance_1]
        
        desired_instances = [:instance_1, :instance_2]
        
        @elb_connection.should_receive(:register_instances_with_lb).with(lb.name, [:instance_2]).and_return(desired_instances)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:instances => desired_instances}])
        lb.instances = desired_instances
      end      
      
      it "should update the instances attribute" do
        lb = populated_load_balancer :dns_name => :something, :instances => [:instance_1]
        
        desired_instances = [:instance_1, :instance_2]
        
        @elb_connection.should_receive(:register_instances_with_lb).with(lb.name, [:instance_2]).and_return(desired_instances)
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([{:instances => desired_instances}])
        
        lb.instances = desired_instances
        lb.instances.should == desired_instances
      end
    end
    
    describe "launch" do
      it ", the class method, should instantiate a new load balancer and launch it" do
        listener_hash = {:protocol => 'HTTP', :load_balancer_port => 80, :instance_port => 8080}
        @elb_connection.should_receive(:create_lb).with(:lbname, [:some_availability_zones], [ listener_hash ])
        @elb_connection.should_receive(:describe_lbs).and_return([{:instances => anything }])
        LoadBalancer.launch({:name => :lbname, 
                             :availability_zones => [:some_availability_zones], 
                             :listeners => [ listener_hash ]})
      end
      
      it "should raise an error if you try to launch a load balancer with no availability zones" do
        lb = populated_load_balancer :availability_zones => []
        raises_error("Load balancers must have at least one availability zone defined.") do
          lb.launch
        end
      end
    
      it "should raise an error if you try to launch a load balancer with no listeners" do
        lb = populated_load_balancer :listeners => []
        raises_error("Load balancers must have at least one listener defined.") do
          lb.launch.should 
        end
      end
      
      it "should set the dns_name when launched" do
        lb = populated_load_balancer :dns_name => nil
        @elb_connection.should_receive(:create_lb).and_return(:a_dns_name)
        @elb_connection.should_receive(:register_instances_with_lb)
        @elb_connection.should_receive(:describe_lbs).and_return([{:instances => anything }])
        lb.launch
        lb.dns_name.should == :a_dns_name
      end
    end
    
    describe "reload" do
      it "should not try to refresh if not launched" do
        lb = populated_load_balancer :dns_name => nil
        @elb_connection.should_receive(:describe_lbs).never
        lb.reload
      end
      
      it "should refresh itself from AWS data" do
        last_hour = Time.now - 1.hour
        lb = populated_load_balancer :aws_created_at => last_hour.to_s, :dns_name => :something
        
        time_now = Time.now
        expected_attributes = DEFAULT_LB_ATTRIBUTES.merge({ :aws_created_at => time_now.to_s })
        @elb_connection.should_receive(:describe_lbs).with([lb.name]).and_return([expected_attributes])
        
        lb.aws_created_at.to_s == last_hour.to_s
        lb.reload
        lb.aws_created_at.to_s.should == time_now.to_s
      end
    end

    describe "terminate!" do
      it "should do nothing if the load balancer is not launched" do
        lb = populated_load_balancer
        lb.should_receive(:destroy).never
        lb.terminate!
      end
      
      it "should call destroy and set the terminated instance variable" do
        lb = populated_load_balancer :dns_name => 'lb_launched'
        @elb_connection.should_receive(:delete_lb).and_return(:lb_launched)
        lb.should_receive(:destroy)
        lb.terminated?.should be_false
        lb.terminate!        
        lb.terminated?.should be_true
      end
    end
  end
end