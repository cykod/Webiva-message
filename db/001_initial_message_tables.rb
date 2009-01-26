class InitialMessageTables < ActiveRecord::Migration
  def self.up
  
    create_table :message_recipients, :force => true do |t|
      t.integer :from_user_id
      t.integer :to_user_id
      t.boolean :system_message, :default=>false
      t.boolean :notification, :default =>false
      
      t.boolean :opened, :default => false
      t.boolean :replied, :default => false
      t.boolean :important, :default => false
      
      t.boolean :deleted, :default => false
      
      t.boolean :sent, :default => false
      
      t.timestamps
      t.integer :message_message_id
      t.integer :message_thread_id
    end
    
    add_index :message_recipients, [:from_user_id,:created_at], :name => 'from_index'
    add_index :message_recipients, [:to_user_id,:created_at], :name => 'to_index'

    create_table :message_messages, :force => true do |t|
      t.text :recipients      
      t.string :subject
      t.text :message
      t.integer :message_thread_id
      t.boolean :handled, :default => false

      t.boolean :notification, :default =>false
      t.string :notification_class
      
      t.integer :message_template_id
      
      t.integer :from_user_id
      
      t.text :data
      
      t.timestamps
    end
    
    add_index :message_messages, [:message_thread_id,:created_at], :name => 'thread_index'
    
    create_table :message_threads, :force => true do |t|
      t.timestamps
    end
    
    create_table :message_templates, :force => true do |t|
      t.string :name 
      t.string :subject
      t.text :message
      t.boolean :notification, :default => false
      t.boolean :system_message, :default => false
      t.string :language
      t.text :success_message
      t.text :failure_message
      t.text :other_message
      t.timestamps
    end
 
  end

  def self.down
    drop_table :message_messages
    drop_table :message_recipients
    drop_table :message_threads
    drop_table :message_templates
  end

end
