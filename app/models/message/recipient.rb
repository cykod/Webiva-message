

module Message::Recipient

  def recipients_display
    return @recipients_display if @recipients_display
    if self.recipient_ids.blank?
      @recipients_display = []
    else
      user_id_list, group_id_list,  full_group_id_list = recipient_arrays
      
      @recipients_display = EndUser.find(:all,:conditions => ['id in (?)',user_id_list ])
      @recipients_display += SocialUnit.find(:all,:conditions => ['id IN (?)',full_group_id_list])
      @recipients_display
    end
  end
  
  def recipient_id_array
    recipient_id_array = self.recipient_ids.to_s.split(",").map { |elm| elm = elm.strip; elm.blank? ? nil : elm }.compact
  end
    
  
  def recipient_arrays
   full_id_list = recipient_id_array
      
      group_id_list = []
      full_group_id_list = []
      user_id_list = full_id_list.map do |elm| 
        elm =~ /^(.*)\_([0-9]+)$/
        case $1
        when 'end_user':
          $2
        when 'social_unit':
          group_id_list << $2
          full_group_id_list << $2
          nil
        else
          group_id = $2
          group = $1
          group =~ /^([^_]+)\_(.*)$/
          group_id_list << [ group_id, $1 ]
          full_group_id_list << group_id
          nil
        end
      end.compact
      
      [ user_id_list, group_id_list, full_group_id_list ]
  end
  
  def update_recipient_ids
    user_id_list, group_id_list, full_group_id_list = recipient_arrays
    
    users = []
    self.recipients.to_s.split(",").each do |recipient|
    
      recipient.strip!
      usr = EndUser.find(:first,:conditions => ['full_name =? AND id IN (?)',recipient, user_id_list])
      
      if !usr
        name_parts = recipient.split(" ")
        partial_name = name_parts[0..-2].join(" ")
        sub_group = name_parts[-1]
        if group = SocialUnit.find(:first,:conditions => ['name=? AND id IN (?)',recipient,full_group_id_list ])
         if group.is_member?(self.from_user)
            users << group.full_identifier
          else
            self.errors.add(:recipients,'could not be found: ' + recipient) 
          end
        elsif group = SocialUnit.find(:first,:conditions => ['name=? AND id IN (?)',partial_name,full_group_id_list ])
         if group.is_member?(self.from_user)
             users << sub_group.underscore.downcase + "_" + group.full_identifier
         else
           self.errors.add(:recipients,'could not be found: ' + recipient) 
         end
        else
          self.errors.add(:recipients,'could not be found: ' + recipient)
        end
      else
        users << usr.full_identifier
      end
    end
   
    self.recipient_ids = users.join(",")
  end
  
  
  def recipient_users
    user_id_list, group_id_list, full_group_id_list = recipient_arrays
    
    users = []
    self.recipients.to_s.split(",").each do |recipient|
    
      recipient.strip!
      usr = EndUser.find(:first,:conditions => ['full_name =? AND id IN (?)',recipient, user_id_list])
      
      if !usr
        name_parts = recipient.split(" ")
        partial_name = name_parts[0..-2].join(" ")
        sub_group = name_parts[-1]
        if sub_group.blank? && group = SocialUnit.find(:first,:conditions => ['name=? AND id IN (?)',recipient,full_group_id_list ])
          if group.is_member?(self.from_user)
            users += group.users.select { |usr| usr.id != self.from_user_id }
          else
            self.errors.add(:recipients,'could not be found: ' + recipient) 
          end
        elsif group = SocialUnit.find(:first,:conditions => ['name=? AND id IN (?)',partial_name,full_group_id_list ])
          sub_group = sub_group.underscore.downcase
          if group.sub_groups.include?(sub_group) && group.is_member?(self.from_user)
            users += group.users(sub_group).select { |usr| usr.id != self.from_user_id }       
          else
            self.errors.add(:recipients,'could not be found: ' + recipient) 
          end
        else
          self.errors.add(:recipients,'could not be found: ' + recipient)
        end
      else
        users << usr
      end
    end
   
    users
  end
  
end
