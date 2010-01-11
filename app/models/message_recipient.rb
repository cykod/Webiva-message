

class MessageRecipient < DomainModel

  belongs_to :message_message
  
  belongs_to :from_user, :class_name => 'EndUser',:foreign_key => 'from_user_id'
  belongs_to :to_user, :class_name => 'EndUser',:foreign_key => 'to_user_id'
  belongs_to :message_thread 

  validates_presence_of :to_user_id
   
  def subject
    self.message_message ? self.message_message.subject : 'Invalid Message'
  end
  
  def message
    self.message_message ? self.message_message.message : 'Invalid Message'
  end
  
  def recipients
    self.message_message ? self.message_message.recipients : 'Invalid Message'
  end

 def single?
    self.message_message ? self.message_message.single? : true
  end
  
  def self.unread_count(usr,options={})
    with_scope(:find => options) do 
      self.count(:all,:conditions => ['to_user_id=? AND opened=0 AND sent=0 AND deleted=0',usr.id])
    end  
  end

  def display_recipients
    ((self.recipients.blank? || self.single?) && 
     !self.sent?) ? (self.to_user ? self.to_user.name : "Deleted User ##{self.to_user.id}")  :  self.recipients
  end
  
  def reply_content
    MessageMessage.new(:subject => "Re: " + self.subject.gsub(/^Re\: /,""),:recipients => self.from_user.name,:message_thread_id => self.message_thread_id, :from_user => to_user)
  end
  
  def notification_class_instance
    if self.notification?
      self.message_message.notification_class.classify.constantize.new(self,self.message_message)
    else
      nil
    end
  end
 
  
end

