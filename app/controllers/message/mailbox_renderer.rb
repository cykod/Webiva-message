require 'net/http'
require 'uri'

class Message::MailboxRenderer < ParagraphRenderer

  features '/message/mailbox_feature'

  paragraph :mailbox, :ajax => true
  paragraph :notify, :ajax => true
  paragraph :text_message, :ajax => true
  paragraph :write, :ajax => true
  
  include EndUserTable::Controller

  def mailbox
    @options = paragraph_options(:mailbox)

    data = {}
    
    page = params[:page]
    page = 'inbox' if !ajax?
    page = 'sent' if params[:message_sent] || params[:update_table].to_s == 'message_sent'
    page ||= 'inbox'
    
    case page
    when 'inbox'
      display_inbox
    when 'sent'
      display_sent
    when 'message'
      display_message
    when 'write'
      if(!display_write) 
        display_inbox
      end
    when 'autocomplete'
      json_autocomplete(params[:keyword])
      return
    when 'load_message'
      load_message(params[:load_message_id],@options.template_categories_list)
      return
    end
    
    @view_data[:renderer] = self
    @view_data[:overlay] = false
    @view_data[:editor] = editor?
   
    @view_data[:mod_opts] = module_options(:message)
    if ajax?
      render_paragraph :partial =>@display_partial, :locals => @view_data  
    else
      render_paragraph :partial => '/message/mailbox/mailbox', :locals => {:view_data =>  @view_data, :partial => @display_partial  }
      require_ajax_js
      require_js('end_user_table.js')
      require_css('end_user_table.css')

      require_js('protomultiselect/protomultiselect.js') 
      require_css('/javascripts/protomultiselect/css/style.css')
    end
    
  end
  
  protected
  
  def display_inbox
  
  
 @tbl = end_user_table( :message_list,
                             MessageRecipient, 
                             [ EndUserTable.column(:blank),
                               EndUserTable.column(:blank),
                               EndUserTable.column(:static,'subject',:label => 'Subject'),
                               EndUserTable.column(:order,'end_users.first_name,end_users.last_name', :label => 'From'),
                               EndUserTable.column(:order,'message_messages.created_at', :label => 'Sent At')
                              ]
                        )
    end_user_table_action(@tbl) do |act,mids|
      if act == 'delete'
        MessageRecipient.find(:all,:conditions => { :to_user_id => myself.id, :id => mids }).each do |message|
          message.update_attribute(:deleted,true)
        end
      end
    end
    
    end_user_table_generate(@tbl,:conditions => [ "to_user_id = ? AND deleted=0 AND sent=0",myself.id],:order => 'message_recipients.created_at DESC',:per_page => 10, :joins => "LEFT JOIN end_users AS from_users ON  `from_users`.id = `message_recipients`.from_user_id", :include => [ :message_message, :from_user ])
  

    @view_data = {
                :tbl => @tbl,
                :renderer => self
                 }
            
      
    @display_partial = '/message/mailbox/display_inbox'
  
    
  end
  
  def display_sent
  
 @display_partial = '/message/mailbox/display_inbox'    
   @tbl = end_user_table( :message_sent,
                             MessageRecipient, 
                             [ EndUserTable.column(:blank),
                               EndUserTable.column(:blank),
                               EndUserTable.column(:order,'subject',:label => 'Subject'),
                               EndUserTable.column(:order,'recipients', :label => 'To'),
                               EndUserTable.column(:order,'message_messages.created_at', :label => 'Sent At')
                              ]
                        )
    end_user_table_action(@tbl) do |act,mids|
      if act == 'delete'
        MessageRecipient.find(:all,:conditions => { :from_user_id => myself.id, :id => mids, :sent => true }).each do |message|
          message.update_attribute(:deleted,true)
        end
      end
    end
    
    end_user_table_generate(@tbl,:conditions => [ "message_recipients.from_user_id = ? AND message_recipients.notification=0 AND deleted=0 AND sent=1",myself.id],:order => 'message_recipients.created_at DESC',:per_page => 10, :include => [ :message_message ] )
  
    @view_data = {
                :tbl => @tbl,
                :renderer => self
                 }
            
    
    @display_partial = '/message/mailbox/display_sent'
 
  end
  
  
  def display_message
    
    
    message = MessageRecipient.find_by_id(params[:message_id],:conditions => ['to_user_id  = ? OR from_user_id = ?',myself.id,myself.id] )
    
    
    if !message.opened?
      message.reload(:lock => true)
      message.update_attribute(:opened,1)
    end

    reply = message.reply_content if message.from_user
    
    if message.notification? && params[:notify_action]
      message.notification_class_instance.process_action(params[:notify_action])
    end
    
    if request.post? && params[:message]
      reply.message = params[:message][:message]
      reply.subject = params[:message][:subject]
      if reply.valid?
        reply.save
        reply.send_message(message.from_user)
        flash.now[:message_sent] = true
        display_inbox
        return
      end
    end
    
    if message.notification?
      content =  message_mailbox_notification_feature({:message => message},simple_format(message.message))
    else
      content = simple_format(h(message.message))
    end
    
    
    @view_data = { :message => message, :reply => reply, :content => content }
    
    @display_partial = '/message/mailbox/message'
  end
  
  def display_write
 
    message = MessageMessage.new()
    
    if request.post? && params[:message] 
      message.attributes = params[:message]
      message.from_user = myself
      
      valid_users = []
      
      if !params[:partial]
        message.valid?
        message.recipient_users.each do |usr|
         valid_users << usr
          # May need to check if user is a friend...
        end
        if valid_users.length == 0
          message.errors.add(:recipient_ids,' must be selected')
        end
        
        if message.errors.length == 0
          message.save
          message.send_message(valid_users,:single => @options.single_message ? true : false)
          flash.now[:message_sent] = true
          return false
        end
      end
    end
    
    if params[:recipient_id]
      message.recipient_ids = params[:recipient_id].to_s.split(",").join("###")
    end
    
    @suser = SocialUser.user(myself) 

    targets = @suser.social_units + EndUser.find(:all,:conditions => { :id => SocialFriend.friends_cache(myself.id) },:order => 'last_name,first_name', :include => :domain_file )
    
    @view_data = { :message => message, :friends => targets }

    if !@options.template_categories.blank?
      categories = @options.template_categories_list
      if categories.length > 0
        @view_data[:message_templates] = MessageTemplate.select_options(:conditions => ['category IN (?)',categories])

      end
    else
      @view_data[:message_templates] = []
    end
  
    
    @display_partial = '/message/mailbox/write'
    
    true
  end

  
  public
  
 def text_message
  
  
    case params[:page]
    when 'autocomplete'
      display_autocomplete
      return
    end
    
    message = MessageTxt.new((params[:message]||{}).slice(:recipient_ids,:recipients,:message))
    
   if params[:recipient_id]
      message.recipient_ids = params[:recipient_id]
      new_recipients =[]
      message.recipients = message.recipients_display.collect do |usr| 
        if usr.is_a?(SocialUnit)
          if(usr.sub_groups[0]) 
            new_recipients << "#{usr.sub_groups[0].underscore}_#{usr.full_identifier}"
            usr.name + " " + usr.sub_groups[0].humanize.capitalize
          else
            new_recipients << usr.full_identifier
            usr.name
          end
        else
          new_recipients << usr.full_identifier
          usr.name
        end
      end.join(", ")
      message.recipient_ids = new_recipients.join(",")
      
    end    

    @suser = SocialUser.user(myself) 
    targets = @suser.social_units + EndUser.find(:all,:conditions => { :id => SocialFriend.friends_cache(myself.id) },:order => 'last_name,first_name', :include => :domain_file )

    data = { :message => message,:renderer => self, :message_length => MessageTxt.empty_message_length(myself), :friends => targets }
    
    if ajax?
      mod_opts = module_options(:message)
  
      message.from_user = myself
      message.ip_address = request.remote_ip

      message.valid?
      valid_users = []
      message.recipient_users.each do |usr|
        if SocialFriend.is_friend?(myself,usr)
          valid_users << usr
        else
          message.errors.add(:recipients,'are not your friends: ' + usr.name)
        end
      end
      
      if message.errors.length == 0 && message.send_message(valid_users)
        render_paragraph :partial => '/message/mailbox/text_message_sent'
      else
        render_paragraph :partial => '/message/mailbox/text_message_form', :locals => data
      end
      
    else
      render_paragraph :partial => '/message/mailbox/text_message', :locals => data
      
      require_js('prototype.js')
      require_js('builder')
      require_js('redbox')
      require_css('redbox')        
      require_js('effects.js')
      require_js('controls.js')
      require_js('user_application.js')
      require_js('end_user_table.js')
    end
  end  
  
  
  def notify
    if !myself.id 
      render_paragraph :text => ''
      return
    end
    
    if ajax? && params[:new_chat]
      chat = MessageChat.start_chat(myself.id,params[:new_chat])
      render_paragraph :partial => '/message/mailbox/chat_window', :locals => { :chat => chat }
    else
      message_count = MessageRecipient.unread_count(myself)
      
      present_friends = MessagePresence.present_users(SocialFriend.friends_cache(myself))

      MessagePresence.present!(myself)
      
      options = paragraph_options(:notify)
      data = { :messages => message_count, :user => myself, :mail_page_url => options.mailbox_page_url, :text_page_url => options.text_message_page_url , :overlay => options.overlay == 'yes', :ajax => ajax?, :paragraph => paragraph, :editor => editor?, :present_friends => present_friends, :update => options.update  }
      
      session[:message_browsers] ||= {}
      
      
      if ajax?
        window_id = params[:window_id].to_s

        last_check = session[:message_browsers][window_id] || Time.now - 4.days

        if params[:closed_chats]
          MessageChat.end_chat(myself,params[:closed_chats])
        end

        # find all new messages, index them by chat id,
        chats = MessageChat.active_chats(myself,params[:active_chats] || [])
        MessageChat.close_non_present_chats(myself,chats,present_friends) if chats.length > 0
        
        new_messages = MessageChat.user_messages(myself,params[:active_chats] || [],last_check)

        if params[:message]
          msg = MessageChat.send_message(myself,params[:chat_id],params[:message])
          new_messages << msg if msg
          if msg
            last_check = msg.created_at 
          else
            last_check = Time.now
          end
        else 
          last_check = Time.now
        end

      else
        # get all active chats
        chats = MessageChat.active_chats(myself,[])
        MessageChat.close_non_present_chats(myself,chats,present_friends) if chats.length > 0
        last_check = Time.now
        new_messages = []

        window_id = rand(1000000000).to_s # Used for different browser windows of same user
      end
      
      session[:message_browsers][window_id] = last_check
      
      if ajax?
        updated = render_to_string :partial => '/message/mailbox/notify', :locals => { :feature => message_mailbox_notify_feature(data), :chats => chats,  :new_messages => new_messages, :ajax => ajax?, :renderer => self, :paragraph => paragraph, :editor => editor?, :window_id => window_id }
        render_paragraph :text => <<-EOF
          <script>
            Element.update("notify_#{paragraph.id}","#{jh updated}");
          </script>
        EOF
      else
        render_paragraph :partial => '/message/mailbox/notify', :locals => { :feature => message_mailbox_notify_feature(data), :chats => chats,  :new_messages => new_messages, :ajax => ajax?, :renderer => self, :paragraph => paragraph, :editor => editor?, :window_id => window_id, :update => options.update }
      end
      
      require_js('prototype')
      require_js('effects')
      require_js('builder')
      require_js('redbox')
      require_css('redbox')        
      require_js('effects')
      require_js('dragdrop')
      require_js('controls')
      require_js('cookiejar')
      require_js('resize')
      require_css('/components/message/stylesheets/chat.css')
      require_js('overlib/overlib.js')
      require_js('user_application')
      require_js('end_user_table')
      require_css('end_user_table.css')
      
    end
  end

  def load_message(message_id,categories)
    @message_template = MessageTemplate.find_by_id(message_id,:conditions => {  :category => categories})
    render_paragraph :rjs => '/message/mailbox/load_message', :locals => { :message_template => @message_template }
  end

  def json_autocomplete(keywords)
    mod_opts = Message::AdminController.module_options
    if mod_opts.use_friends 
      @suser = SocialUser.user(myself) 
      @users = SocialUnit.find(:all,:conditions => ['social_unit_members.end_user_id=?', myself.id],:group => 'social_units.id', :joins => 'LEFT JOIN social_unit_members ON (social_unit_members.social_unit_id = social_units.id)' )
      @users += SocialFriend.find(:all,:conditions => ["social_friends.end_user_id=?",myself.id],:group => 'end_users.id',:joins => [ :friend_user ]).collect { |usr| usr.friend_user }
    else
      @users = EndUser.find(:all, :order => 'last_name, first_name')
    end
    values = @users.map {  |elm| {  :caption => elm.name, :value => "end_user_#{elm.id}"} }
    render_paragraph :text => values.to_json()
  end
  
  
  def write
    @options = paragraph_options(:write)

    if ajax? 
      if params[:keyword]
        return json_autocomplete(params[:keyword])
      elsif params[:load_message_id]
        return load_message(params[:load_message_id],@options.template_categories_list)
      end

    end

    display_message =  display_write()

    if !display_message
      render_paragraph :partial => '/message/mailbox/message_sent'
      return
    end



    @view_data[:renderer] = self
    @view_data[:overlay] = true
    @view_data[:editor] = editor?
    @view_data[:mod_opts] = module_options(:message)
    
    
    if ajax?
      render_paragraph :partial => @display_partial, :locals => @view_data  
    else
      render_paragraph :partial => '/message/mailbox/mailbox', :locals => {:view_data =>  @view_data, :partial => @display_partial }
    end

      
  end


end
