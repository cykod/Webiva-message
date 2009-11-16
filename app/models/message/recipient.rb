

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
    recipient_id_array = self.recipient_ids.to_s.split("###").map { |elm| elm = elm.strip; elm.blank? ? nil : elm }.compact
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
  
  def recipient_users
    user_id_list, group_id_list, full_group_id_list = recipient_arrays
    
    users = []
    self.recipient_ids.to_s.split("###").each do |recipient|
      
      recipient.strip!

      if recipient =~ /(end\_user|social\_unit)\_([0-9]+)/
        recipient_type = $1
        recipient_id = $2
        
        case recipient_type
        when 'end_user'
          usr = EndUser.find_by_id(recipient_id)
          users << usr if usr
        when 'social_unit'
          if group = SocialUnit.find_by_id(recipient_id)
            if group.is_member?(self.from_user) 
              users += group.users.select { |usr| usr.id != self.from_user_id }
            else
              self.errors.add(:recipients,'could not be found: ' + group.name)
            end
          end
        end
      end
    end

    users
  end
  
end
