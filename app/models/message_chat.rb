

class MessageChat < DomainModel

  has_many :message_chat_members
  has_many :messages, :class_name => 'MessageChatMessage', :include => [ :from_user ]


  def self.start_chat(from_user_id,to_user_id) 
  
    chat = self.create
    chat.message_chat_members.create(:end_user_id => from_user_id)
    chat.message_chat_members.create(:end_user_id => to_user_id)
    
    chat
  end
  
  def title(user)
    member = self.message_chat_members.find(:first,:conditions => ['end_user_id != ?',user.id ],:include => :end_user)
    
    member.end_user ? member.end_user.name : 'Chat'
  end
  
  def self.active_chats(user,except)
    except = [0] if except.length == 0
    MessageChatMember.find(:all,:conditions => ['end_user_id=? AND message_chat_id NOT IN (?) AND ended = 0',user.id,except],:include =>  :message_chat).map(&:message_chat)
  end
  
  def self.user_messages(user,chat_ids,since)
    return [] if chat_ids.length == 0
    MessageChatMessage.find(:all,:conditions => ['created_at > ? AND message_chat_id IN (?)',since,chat_ids],:order => 'created_at')
  end
  
  def self.send_message(user,chat_id,msg,notification=false)
    members = MessageChatMember.find(:all,:conditions => ['message_chat_id = ? AND ended = 0',chat_id])
    
    if members.detect { |member| member.end_user_id == user.id }
      chat_msg = nil
      members.each do |member|
        if member.end_user_id != user.id
          chat_msg = MessageChatMessage.create(:end_user_id => user.id,:to_user_id => member.end_user_id,:message => msg, :message_chat_id => chat_id, :notification => notification)
        end  
      end
      chat_msg
    end
  end
  
  def self.end_chat(user,chat_ids)
#     chat_ids = [ chat_ids] unless chat_ids.is_a?(Array)
     chat_ids.each do |chat_id|
       members = MessageChatMember.find(:all,:conditions => ['message_chat_id = ? AND ended = 0',chat_id])
    
       if me = members.detect { |member| member.end_user_id == user.id }
         self.send_message(user,chat_id,'has left the conversation',true)
         members.each do |member|
           member.update_attribute(:ended,true)
         end
       end
     end
  end
  
  def self.close_non_present_chats(user,chats,present_friends)
    user_ids = present_friends.map(&:id) + [ user.id ] 
    members = MessageChatMember.find(:all,:conditions => [ 'end_user_id NOT IN (?) AND message_chat_id IN (?)',user_ids,chats.map(&:id) ])
    if members.length > 0
      members.each do |member|
        self.end_chat(member.end_user,[ member.message_chat_id ])
      end
    end
  end
end


