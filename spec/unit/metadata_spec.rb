require 'rubygems'
require 'spec'
require File.expand_path(File.dirname(__FILE__) + "/../../lib/awsymandias")

module Awsymandias
  describe Metadata do

    before :each do
      @simpledb_domain = 'application_stacks'
      @stack = 'test_stack'
    end

    describe "put" do

      it "should split load_balancers into multiple attributes (to workaround SimpleDB value 1024 char limit)" do

        Awsymandias::SimpleDB.should_receive(:put).with do |domain, stack, metadata| 
          load_balancers = {:elb2 => 'elb2', :elb1 => 'elb1'}
          
          metadata.should include(:load_balancer1)
          metadata.should include(:load_balancer2)
          metadata.should include(:load_balancers_count)
          load_balancers.should include(metadata[:load_balancer1])
          load_balancers.should include(metadata[:load_balancer2])
          metadata[:load_balancers_count].should == '2'
        end  
        Awsymandias::Metadata.put(@simpledb_domain, @stack, {:load_balancers => {:elb2 => 'elb2', :elb1 => 'elb1'}})
      end

      it "should not complain if load_balancers not defined" do
        metadata = {:instances => [:instance1, :instance2]}
        Awsymandias::SimpleDB.should_receive(:put).with(@simpledb_domain, @stack, metadata, {})
        Awsymandias::Metadata.put(@simpledb_domain, @stack, metadata)
      end

      it "should split unlaunched_load_balancers into multiple attributes (to workaround SimpleDB value 1024 char limit)" do
        unlaunched_load_balancers = {:unlaunched_load_balancers => {:elb2 => 'elb2', :elb1 => 'elb1'}}
        
        Awsymandias::SimpleDB.should_receive(:put).with do |domain, stack, metadata| 
          unlaunched_load_balancers = {:elb2 => 'elb2', :elb1 => 'elb1'}
          
          metadata.should include(:unlaunched_load_balancer1)
          metadata.should include(:unlaunched_load_balancer2)
          metadata.should include(:unlaunched_load_balancers_count)
          unlaunched_load_balancers.should include(metadata[:unlaunched_load_balancer1])
          unlaunched_load_balancers.should include(metadata[:unlaunched_load_balancer2])
          metadata[:unlaunched_load_balancers_count].should == '2'
        end  
        
        Awsymandias::Metadata.put(@simpledb_domain, @stack,{:unlaunched_load_balancers => {:elb2 => 'elb2', :elb1 => 'elb1'}})
      end

      it "should not complain if unlaunched_load_balancers not defined" do
        metadata = {:instances => [:instance1, :instance2]}
        Awsymandias::SimpleDB.should_receive(:put).with(@simpledb_domain, @stack, metadata, {})
        Awsymandias::Metadata.put(@simpledb_domain, @stack, metadata)
      end

    end

    describe "get" do

      it "should reconstruct load_balancers from multiple attributes (to workaround SimpleDB value 1024 char limit)" do
        load_balancers = {:load_balancers => {:elb2 => 'elb2', :elb1 => 'elb1'}}
        expanded_load_balancers = {:load_balancer1 => {:elb1 => 'elb1'}, :load_balancer2 => {:elb2 => 'elb2'}, :load_balancers_count => '2' }
        
        Awsymandias::SimpleDB.should_receive(:get).with(@simpledb_domain, @stack, {}).and_return(expanded_load_balancers)
        Awsymandias::Metadata.get(@simpledb_domain, @stack).should == load_balancers
      end
      
      it "should not complain if load_balancers not defined" do
        metadata = {:instances => [:instance1, :instance2]}
        Awsymandias::SimpleDB.should_receive(:get).with(@simpledb_domain, @stack,{}).and_return(metadata)
        Awsymandias::Metadata.get(@simpledb_domain, @stack).should == metadata
      end

      it "should reconstruct unlaunched_load_balancers from multiple attributes (to workaround SimpleDB value 1024 char limit)" do
        unlaunched_load_balancers = {:unlaunched_load_balancers => {:elb2 => 'elb2', :elb1 => 'elb1'}}
        expanded_unlaunched_load_balancers = {:unlaunched_load_balancer1 => {:elb1 => 'elb1'}, :unlaunched_load_balancer2 => {:elb2 => 'elb2'}, :unlaunched_load_balancers_count => '2' }
        
        Awsymandias::SimpleDB.should_receive(:get).with(@simpledb_domain, @stack, {}).and_return(expanded_unlaunched_load_balancers)
        Awsymandias::Metadata.get(@simpledb_domain, @stack).should == unlaunched_load_balancers
      end
      
      it "should not complain if unlaunched_load_balancers not defined" do
        metadata = {:instances => [:instance1, :instance2]}
        Awsymandias::SimpleDB.should_receive(:get).with(@simpledb_domain, @stack,{}).and_return(metadata)
        Awsymandias::Metadata.get(@simpledb_domain, @stack).should == metadata
      end
      
      it "should not complain if metadata not found" do
        Awsymandias::SimpleDB.should_receive(:get).with(@simpledb_domain, @stack,{}).and_return({})
        Awsymandias::Metadata.get(@simpledb_domain, @stack).should == {}
      end
      
    end
          
    describe "delete" do
      it "should delete metadata from SimpleDB" do
        Awsymandias::SimpleDB.should_receive(:delete).with(@simpledb_domain, @stack)
        Awsymandias::Metadata.delete(@simpledb_domain, @stack)
      end
    end
    
  end
end