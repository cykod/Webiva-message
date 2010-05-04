

class MessageMessage < DomainModel

  has_many :message_recipients, :dependent => :destroy
  
  belongs_to :message_thread
  belongs_to :message_template
  
  belongs_to :from_user, :class_name => 'EndUser'
  
  attr_accessor :parent_message_id,:recipient_id_arr
  
  validates_presence_of :subject,:message
  validate_on_create :valid_recipients
  
  serialize :data

  # Set a string of recipient ids of the form
  # end_user_234###social_unit_54###
  def recipient_ids=(id_str)
    @recipient_id_arr=  id_str.to_s.split("###").map { |elm| elm = elm.strip; elm.blank? ? nil : elm }.compact
  end

  def recipient_ids
    @recipient_id_arr ? @recipient_id_arr.join("###") : ""
  end


  def valid_recipients
    self.errors.add(:recipient_ids,"are invalid") if self.recipients_display.length == 0
  end
  

  def before_save
    if self.recipients.blank?
      self.recipients = self.recipients_display.map(&:name).join(", ")
    end
    if self.message_thread_id.blank?
      self.message_thread = MessageThread.create    
    end  
  end

  def self.write_notification(options = {})
    message = MessageMessage.new(options.slice(:subject,:message,:recipient_ids))
    message.notification = true
    message
  end

  def self.write_message(from_user,options ={})
    options ||= {}
    message = MessageMessage.new(options.slice(:subject,:message,:recipient_ids))
    message.from_user =from_user

    message
  end


  def deliver_notification(nclass=nil,data={})
    if self.valid?
      self.send_notification(self.recipient_users,nclass,data)
    else
      return false
    end
  end
  
  def send_notification(to_users,nclass=nil,data={})
    if to_users.blank?
      to_users = self.recipient_users
    else
      to_users = [ to_users ] unless to_users.is_a?(Array)
      @recipients_display = to_users
    end
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

  def deliver_message(opts = {})
    self.valid? ? self.send_message(false,opts) : false
  end

  def send_message(to_users,options={ })
    if to_users.blank?
      to_users = self.recipient_users
    else
      to_users = [ to_users ] unless to_users.is_a?(Array)
      @recipients_display = to_users
    end
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
    true
  end  



  def update_message(message_name,data)
    self.message = self.message_template.rendered_update(message_name,data)
    self.handled = 1
    self.save
  end

  def recipients_display
    return @recipients_display if @recipients_display
    if !@recipient_id_arr
      @recipients_display = []
    else
      recipients_list = recipient_arrays

      @recipients_list_display = []
      @recipients_list_display += EndUser.find(:all,:conditions => ['id in (?)',recipients_list[:user_ids]]) if recipients_list[:user_ids]
      @recipients_list_display += SocialUnit.find(:all,:conditions => ['id IN (?)',recipients_list[:group_ids]]) if recipients_list[:group_ids]
      @recipients_list_display
    end

  end

  
  protected

  def recipient_arrays
    full_id_list = @recipient_id_arr

    unit_list = []
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
    { :user_ids => user_id_list,
      :group_ids => group_id_list,
      :full_group_ids => full_group_id_list
    }
  end

  def recipient_users
    recipients_list =  recipient_arrays

    users = []
    if recipients_list[:user_ids].length > 0
      recipient_users = EndUser.find(:all,:conditions => { :id => recipients_list[:user_ids] }).index_by(&:id)
      # order them in the order sent
      users +=  recipients_list[:user_ids].map { |uid| recipient_users[uid.to_i] }.compact
    end

    if recipients_list[:group_ids].length > 0
      groups = SocialUnit.find(:all,:conditions => { :id => recipients_list[:group_ids] }).index_by(&:id)

      recipients_list[:group_ids].each do |gid|
        group = groups[gid.to_i]
        if group && group.is_admin?(self.from_user) 
          users += group.users.select { |usr| usr.id != self.from_user_id }
        end
      end
    end

    users
  end

end
