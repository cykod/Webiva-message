class TextMessageTables < ActiveRecord::Migration
  def self.up
  
    create_table :message_txts, :force => true do |t|
      t.integer :from_user_id
      t.text :message
      t.boolean :success
      t.string :ip_address
      t.timestamps
    end

    add_index :message_txts, :from_user_id, :name => 'from_user'
    
    create_table :message_txt_recipients, :force => true do |t|
      t.integer :message_txt_id
      t.string :cell_number
      t.string :email
      t.integer :from_user_id
      t.integer :to_user_id
      t.timestamps
    end
    
    add_index :message_txt_recipients, :from_user_id, :name => 'from_user'
    
    create_table :message_txt_verifications, :force => true do |t|
      t.integer :end_user_id
      t.string :cell_number
      t.string :verification_code
      t.boolean :verified,:default => false
    end

    add_index :message_txt_verifications, :end_user_id, :name => 'from_user'

  end

  def self.down
    drop_table :message_txts
    drop_table :message_txt_recipients
    drop_table :message_txt_verifications
  end

end
