

class MessageMessage < DomainModel

  has_many :message_recipients, :dependent => :destroy
  
  belongs_to :message_thread
  belongs_to :message_template
  
  belongs_to :from_user, :class_name => 'EndUser'
  
  attr_accessor :recipient_ids, :parent_message_id
  
  validates_presence_of :subject,:message
  
  serialize :data
  

  def before_save
    if self.recipients.blank?
      self.recipients = self.recipients_display.map(&:name).join(", ")
    end
    if self.message_thread_id.blank?
      self.message_thread = MessageThread.create    
    end  
  end
  
  def send_notification(to_users,nclass=nil,data={})
    self.update_attributes(:notification => true,:notification_class => nclass.to_s.underscore,:data => data)

    to_users = [ to_users ] unless to_users.is_a?(Array)
    
    if from_user
      block = from_user ? SocialBlock.find(:first,:conditions => ['blocked_user_id=? AND end_user_id IN (?)',from_user.id,to_users.id]) : nil
    end
    
    unless block
      to_users.each do |to_user|
        self.message_recipients.create(:from_user => from_user,:to_user_id => to_user.id,:message_thread_id => self.message_thread_id,
                                  :notification => true)
                    
        mod_opts = Message::AdminController.module_options  
        if msg = MailTemplate.find_by_id(mod_opts.message_template_id)
          msg.deliver_to_user(to_user,{ :from => from_user ? from_user.name : 'the site', :subject => self.subject, :message => self.message.to_s.gsub(/\<cms\:button (.+)\<\/cms:button\>/mi,'') })
        end

                    
      end
    end
                                
  end
  
  def send_message(to_users,options={ })
    self.attributes = options
    self.update_attributes(:notification => false)
    to_users = [to_users] unless to_users.is_a?(Array)
    
    blocks = from_user_id ? SocialBlock.find(:all,:conditions => ['blocked_user_id=?',from_user_id]).index_by(&:end_user_id) : []
    
    to_users.uniq.each do |to_usr|
      if !blocks[to_usr.id]
        self.message_recipients.create(:from_user_id => from_user_id ? from_user_id : nil,:to_user_id => to_usr.id,:message_thread_id => self.message_thread_id)
        
        mod_opts = Message::AdminController.module_options  
        if msg = MailTemplate.find_by_id(mod_opts.message_template_id)
          msg.deliver_to_user(to_usr,{ :from => from_user ? from_user.name : 'the site', :subject => self.subject, :message => self.message.to_s.gsub(/\<cms\:button (.+)\<\/cms:button\>/mi,'') })
        end
        
      end
    end
    
    # Add one to sent messages
    if from_user_id
      self.message_recipients.create(:from_user_id => from_user_id,:to_user_id => from_user_id,:message_thread_id => self.message_thread_id,:sent => 1,:opened => 1)
    end
  end  


  
  def update_message(message_name,data)
    self.message = self.message_template.rendered_update(message_name,data)
    self.handled = 1
    self.save
  end
  
  
  include Message::Recipient
  

  
end
