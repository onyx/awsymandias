module Awsymandias
  class Snapshot
    include Awsymandias::Taggable
    include Awsymandias::Notable
    hash_initializer :aws_progress, :aws_status, :aws_id, :aws_volume_id, :aws_started_at, :stack
    attr_reader      :aws_progress, :aws_status, :aws_id, :aws_volume_id, :aws_started_at

    def self.find(ids)
      Awsymandias::RightAws.connection.describe_snapshots(ids).map { |s| Awsymandias::Snapshot.new s }
    end
    
    def id; aws_id; end
    
    def size
      Awsymandias::RightAws.connection.describe_volumes([connection.describe_snapshots([snapshot_id]).first[:aws_volume_id]]).first[:aws_size]
    end
    
    def tag(name)
      SimpleDB.put('snapshots', name, :snapshot_id => id)
    end
    
    def to_simpledb; id; end
    
    def terminate!
      destroy
      Awsymandias::RightAws.delete_snapshot id
    end
  end
end