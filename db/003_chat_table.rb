class ChatTable < ActiveRecord::Migration
  def self.up
  
    create_table :message_presences, :force => true do |t|
      t.integer :end_user_id
      t.timestamps
    end
    
    add_index :message_presences, [ :end_user_id, :created_at ], :name => 'user'
  
    create_table :message_chats, :force => true do |t|
      t.timestamps
    end
    
    create_table :message_chat_members, :force => true do |t|
      t.integer :message_chat_id      
      t.integer :end_user_id
      t.boolean :ended, :default => false
      t.string :session_id
    end
    
    add_index :message_chat_members, :message_chat_id, :name => 'chat_id'
    
    create_table :message_chat_messages, :force => true do |t|
      t.integer :message_chat_id
      t.integer :end_user_id
      t.integer :to_user_id
      t.string :message
      t.boolean :notification,:default => false
      t.datetime :created_at    
    end

    add_index :message_chat_messages, [ :message_chat_id, :created_at ], :name => 'chat_id'
    add_index :message_chat_messages, [ :to_user_id, :created_at ], :name => 'user_id'
    
  end

  def self.down
    drop_table :message_chats
    drop_table :message_presences
    drop_table :message_chat_members
    drop_table :message_chat_messages
  end

end
