

class Message::MailboxController < ParagraphController

  editor_header 'Message Paragraphs'
  
  editor_for :mailbox, :name => "Mailbox"
  editor_for :text_message, :name => 'Text Messaging'
  editor_for :notify, :name => 'Notification Bar', :features => [:message_mailbox_notify]

  class MailboxOptions < HashModel
  end
  
  class NotifyOptions < HashModel
    attributes :mailbox_page_id => nil, :overlay => 'yes', :text_message_page_id => nil
    
    integer_options :mailbox_page_id, :text_message_page_id
    
    page_options :mailbox_page_id, :text_message_page_id
    
  end

end
