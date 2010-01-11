

class MessageThread < DomainModel

  has_many :message_messages
  has_many :message_recipients

  def message_history(user,first_message)
    self.message_recipients.find(:all,:conditions => [ "to_user_id=? AND message_recipients.id < ?",user.id,first_message.id], :order => "created_at DESC")
  end  
end
