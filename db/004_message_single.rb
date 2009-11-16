class MessageSingle < ActiveRecord::Migration
  def self.up
    add_column :message_messages, :single,:boolean, :default => false
    add_column :message_templates, :category, :string
  end

  def self.down
    remove_column :message_messages, :single
    remove_column :message_templates, :category
  end
end
