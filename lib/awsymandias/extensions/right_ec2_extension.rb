require 'right_aws'

module RightAws
  class Ec2
    
    class_variable_set(:@@api, "2009-11-30")
    
    def create_snapshot(volume_id, description = '')
      link = generate_request("CreateSnapshot", 
                              "VolumeId" => volume_id.to_s,
                              "Description" => description)
      request_info(link, QEc2CreateSnapshotParser.new(:logger => @logger))
    rescue Exception
      on_exception
    end
  
    def run_instances(image_id, min_count, max_count, group_ids, key_name, user_data='',  
                      addressing_type = nil, instance_type = nil,
                      kernel_id = nil, ramdisk_id = nil, availability_zone = nil, 
                      block_device_mappings = nil, subnet_id = nil) 
 	    launch_instances(image_id, { :min_count       => min_count, 
 	                                 :max_count       => max_count, 
 	                                 :user_data       => user_data, 
                                   :group_ids       => group_ids, 
                                   :key_name        => key_name, 
                                   :instance_type   => instance_type, 
                                   :addressing_type => addressing_type,
                                   :kernel_id       => kernel_id,
                                   :ramdisk_id      => ramdisk_id,
                                   :availability_zone     => availability_zone,
                                   :block_device_mappings => block_device_mappings,
                                   :subnet_id       => subnet_id
                                 }) 
    end
  
    def launch_instances(image_id, lparams={}) 
      @logger.info("Launching instance of image #{image_id} for #{@aws_access_key_id}, " + 
                   "key: #{lparams[:key_name]}, groups: #{(lparams[:group_ids]).to_a.join(',')}")
      # careful: keyName and securityGroups may be nil
      params = hash_params('SecurityGroup', lparams[:group_ids].to_a)
      params.update( {'ImageId'        => image_id,
                      'MinCount'       => (lparams[:min_count] || 1).to_s, 
                      'MaxCount'       => (lparams[:max_count] || 1).to_s, 
                      'AddressingType' => lparams[:addressing_type] || DEFAULT_ADDRESSING_TYPE, 
                      'InstanceType'   => lparams[:instance_type]   || DEFAULT_INSTANCE_TYPE })
      # optional params
      params['SubnetId']                   = lparams[:subnet_id]             unless lparams[:subnet_id].blank? 
      params['KeyName']                    = lparams[:key_name]              unless lparams[:key_name].blank? 
      params['KernelId']                   = lparams[:kernel_id]             unless lparams[:kernel_id].blank? 
      params['RamdiskId']                  = lparams[:ramdisk_id]            unless lparams[:ramdisk_id].blank? 
      params['Placement.AvailabilityZone'] = lparams[:availability_zone]     unless lparams[:availability_zone].blank? 
      params['BlockDeviceMappings']        = lparams[:block_device_mappings] unless lparams[:block_device_mappings].blank?
      unless lparams[:user_data].blank? 
        lparams[:user_data].strip! 
          # Do not use CGI::escape(encode64(...)) as it is done in Amazons EC2 library.
          # Amazon 169.254.169.254 does not like escaped symbols!
          # And it doesn't like "\n" inside of encoded string! Grrr....
          # Otherwise, some of UserData symbols will be lost...
        params['UserData'] = Base64.encode64(lparams[:user_data]).delete("\n").strip unless lparams[:user_data].blank?
      end
      link = generate_request("RunInstances", params)
        #debugger
      instances = request_info(link, QEc2DescribeInstancesParser.new(:logger => @logger))
      get_desc_instances(instances)
    rescue Exception
      on_exception
    end
  
    class QEc2DescribeSnapshotsParser < RightAWSParser #:nodoc:
      def tagstart(name, attributes)
        @snapshot = {} if name == 'item'
      end
      def tagend(name)
        case name 
          when 'volumeId'    then @snapshot[:aws_volume_id]   = @text
          when 'snapshotId'  then @snapshot[:aws_id]          = @text
          when 'status'      then @snapshot[:aws_status]      = @text
          when 'startTime'   then @snapshot[:aws_started_at]  = Time.parse(@text)
          when 'progress'    then @snapshot[:aws_progress]    = @text
          when 'description' then @snapshot[:aws_description] = @text
          when 'item'        then @result                   << @snapshot
        end
      end
      def reset
        @result = []
      end
    end

    class QEc2CreateSnapshotParser < RightAWSParser #:nodoc:
      def tagend(name)
        case name 
          when 'volumeId'    then @result[:aws_volume_id]   = @text
          when 'snapshotId'  then @result[:aws_id]          = @text
          when 'status'      then @result[:aws_status]      = @text
          when 'startTime'   then @result[:aws_started_at]  = Time.parse(@text)
          when 'description' then @result[:aws_description] = @text
          when 'progress'    then @result[:aws_progress]    = @text
        end
      end
      def reset
        @result = {}
      end
    end

    class QEc2DescribeInstancesParser < RightAWSParser #:nodoc:
      def tagstart(name, attributes)
           # DescribeInstances property
        if (name == 'item' && @xmlpath == 'DescribeInstancesResponse/reservationSet') || 
           # RunInstances property
           (name == 'RunInstancesResponse')  
            @reservation = { :aws_groups    => [],
                             :instances_set => [] }
              
        elsif (name == 'item') && 
                # DescribeInstances property
              ( @xmlpath=='DescribeInstancesResponse/reservationSet/item/instancesSet' ||
               # RunInstances property
                @xmlpath=='RunInstancesResponse/instancesSet' )
              # the optional params (sometimes are missing and we dont want them to be nil) 
            @instance = { :aws_reason       => '',
                          :dns_name         => '',
                          :private_dns_name => '',
                          :ami_launch_index => '',
                          :ssh_key_name     => '',
                          :aws_state        => '',
                          :aws_subnet_id => '',
                          :aws_vpc_id => '',
                          :aws_product_codes => [],
                          :private_ip_address => '' }
        end
      end
      def tagend(name)
        case name 
          # reservation
          when 'reservationId'    then @reservation[:aws_reservation_id] = @text
          when 'ownerId'          then @reservation[:aws_owner]          = @text
          when 'groupId'          then @reservation[:aws_groups]        << @text
          # instance  
          when 'instanceId'       then @instance[:aws_instance_id]    = @text
          when 'imageId'          then @instance[:aws_image_id]       = @text
          when 'dnsName'          then @instance[:dns_name]           = @text
          when 'privateDnsName'   then @instance[:private_dns_name]   = @text
          when 'reason'           then @instance[:aws_reason]         = @text
          when 'keyName'          then @instance[:ssh_key_name]       = @text
          when 'amiLaunchIndex'   then @instance[:ami_launch_index]   = @text
          when 'code'             then @instance[:aws_state_code]     = @text
          when 'name'             then @instance[:aws_state]          = @text
          when 'productCode'      then @instance[:aws_product_codes] << @text
          when 'instanceType'     then @instance[:aws_instance_type]  = @text
          when 'launchTime'       then @instance[:aws_launch_time]    = @text
          when 'kernelId'         then @instance[:aws_kernel_id]      = @text
          when 'ramdiskId'        then @instance[:aws_ramdisk_id]     = @text
          when 'platform'         then @instance[:aws_platform]       = @text
          when 'availabilityZone' then @instance[:aws_availability_zone] = @text
          when 'subnetId'         then @instance[:aws_subnet_id] = @text
          when 'vpcId'            then @instance[:aws_vpc_id] = @text
          when 'privateIpAddress' then @instance[:private_ip_address] = @text
          when 'item'
            if @xmlpath == 'DescribeInstancesResponse/reservationSet/item/instancesSet' || # DescribeInstances property
               @xmlpath == 'RunInstancesResponse/instancesSet'            # RunInstances property
              @reservation[:instances_set] << @instance
            elsif @xmlpath=='DescribeInstancesResponse/reservationSet'    # DescribeInstances property
              @result << @reservation
            end
          when 'RunInstancesResponse' then @result << @reservation            # RunInstances property
        end
      end
      def reset
        @result = []
      end
    end
  
  end  
end
