

class MessageChatMember < DomainModel

 belongs_to :message_chat
 belongs_to :end_user

end
