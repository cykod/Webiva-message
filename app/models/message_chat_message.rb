



class MessageChatMessage < DomainModel

 belongs_to :message_chat
 belongs_to :end_user
 belongs_to :from_user, :class_name => 'EndUser', :foreign_key => 'end_user_id'

end
