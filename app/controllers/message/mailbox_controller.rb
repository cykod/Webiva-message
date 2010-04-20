

class Message::MailboxController < ParagraphController

  editor_header 'Message Paragraphs'
  
  editor_for :mailbox, :name => "Mailbox", :feature => :message_mailbox_mailbox
  editor_for :notify, :name => 'Notification Bar', :feature => :message_mailbox_notify

  editor_for :write, :name => 'Write Message Overlay'

  class MailboxOptions < HashModel
    attributes :profile_page_id => nil, :profile_user_class_id => nil
    
    page_options :profile_page_id
  end
  
  class NotifyOptions < HashModel
    attributes :mailbox_page_id => nil, :overlay => 'yes', :update => true

    boolean_options :update
    
    page_options :mailbox_page_id
    
  end

  class WriteOptions < HashModel
    attributes :single_message => false, :template_categories => nil

    boolean_options :single_message

    def template_categories_list
      self.template_categories.to_s.split(",").map {  |elm| elm.strip.blank? ? nil : elm.strip }.compact
    end
  end


  
end
