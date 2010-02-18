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
  
  end  
end
