

class MessagePresence < DomainModel

 belongs_to :end_user
 
 PRESENT_TIME = 10.minutes
 
 def self.present!(user_id)
    user_id = user_id.id if user_id.is_a?(EndUser)
    usr = self.find_by_end_user_id( user_id) || self.new(:end_user_id =>  user_id)
    usr.save
 end
 
 def self.present_users(user_ids)
    user_id = user_id.id if user_id.is_a?(EndUser)
    user_id = [user_id] unless user_id.is_a?(Array)
    
    last_update = Time.now - PRESENT_TIME
    
    MessagePresence.find(:all,:include => :end_user,
          :conditions => [ 'end_user_id IN (?) AND message_presences.updated_at > ?',user_ids,last_update ]
          ).map(&:end_user)
 end
 
 

end
