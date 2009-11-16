

class Message::MailboxController < ParagraphController

  editor_header 'Message Paragraphs'
  
  editor_for :mailbox, :name => "Mailbox"
  editor_for :text_message, :name => 'Text Messaging'
  editor_for :notify, :name => 'Notification Bar', :features => [:message_mailbox_notify]

  editor_for :write, :name => 'Write Message Overlay'

  class MailboxOptions < HashModel
  end
  
  class NotifyOptions < HashModel
    attributes :mailbox_page_id => nil, :overlay => 'yes', :text_message_page_id => nil, :update => true

    boolean_options :update
    
    integer_options :mailbox_page_id, :text_message_page_id
    
    page_options :mailbox_page_id, :text_message_page_id
    
  end

  class WriteOptions < HashModel
    attributes :single_message => false, :template_categories => nil

    boolean_options :single_message

    def template_categories_list
      self.template_categories.to_s.split(",").map {  |elm| elm.strip.blank? ? nil : elm.strip }.compact
    end
  end


  
end
