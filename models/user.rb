class User < Sequel::Model
  many_to_one :node
  many_to_one :source_path
  
  def validate
    validates_presence :name
    validates_unique [:name, :source_path_id, :node_path_id]
    if (source_path_id.nil? && node_path_id.nil?) ||
      (source_path_id.present? && node_path_id.present?)
        errors.add :source_path_id, 'Ссылка либо на источник, либо на назначение'
    end
  end

end
