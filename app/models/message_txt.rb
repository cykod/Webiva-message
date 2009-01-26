

class MessageTxt < DomainModel

  has_many :message_txt_recipients
  belongs_to :from_user, :class_name => 'EndUser'
  
  validates_presence_of :from_user,:message
  
  attr_accessor :recipient_ids, :recipients
  

  def self.generate_message(msg,from_user)
     mod_opts = Message::AdminController.module_options  
    "#{mod_opts.message_header.gsub("%%name%%",from_user.name)}\n#{msg}\n#{mod_opts.message_footer}"
  end
  
  def self.empty_message_length(from_user)
    self.generate_message('',from_user).length
  end

  def send_message(to_users) 
    
    @mod_opts = Message::AdminController.module_options
    
    cell_numbers = []
    emails = []
    
    recipient_list = to_users.map do |usr|
      cell_number = usr.cell_phone.to_s.strip.gsub(/[^0-9]/,'')
      if cell_number.length == 10
        cell_numbers << "1" + cell_number
        { :to_user_id => usr.id, :cell_number => cell_number, :from_user_id => self.from_user_id }
      else
        emails << usr
        { :to_user_id => usr.id, :email => usr.email, :from_user_id => self.from_user_id }
      end
    end
    
    if cell_numbers.length > 0
      cell_nubmers = cell_numbers.join(",")
    else
      cell_numbers = nil
    end

    msg = self.class.generate_message(self.message,self.from_user)
    
    cnt = MessageTxtRecipient.count(:all,:conditions => [ 'created_at > ? AND from_user_id=?',Time.now-1.days,from_user.id])
    if cnt >= @mod_opts.daily_limit.to_i
      errors.add(:message,' not sent: daily message limit reached')
      return false
    end
    
    if msg.length > 160
      errors.add(:message,"too long: please remove #{(msg.length - 160)} characters")
      return false
    end
    
    
    
    if cell_numbers
      req_data = { :user => @mod_opts.clickatel_user, :password => @mod_opts.clickatel_password, :api_id => @mod_opts.clickatel_api_id, :to => cell_numbers, :text => msg }
      
      url = URI.parse('https://api.clickatell.com/http/sendmsg')
      
      post = Net::HTTP::Post.new(url.path)
      post.set_form_data(req_data)
      
      req = Net::HTTP.new(url.host,url.port)
      req.use_ssl = true
      
      result = req.start { |http| http.request(post) }
      case result
      when Net::HTTPSuccess, Net::HTTPRedirection
        self.success = true
      else
        self.success = false
      end
    end
    
    if emails.length > 0
      emails.each do |email|
        smsg = MessageTemplate.create_message('text_message', self.from_user,{  :message =>  msg })
        smsg.send_notification(email,nil)      
      end
    end
    
    self.save
    recipient_list.each do |to_usr| 
      self.message_txt_recipients.create(to_usr)
    end
    
    true
  end
  
  include Message::Recipient

end
