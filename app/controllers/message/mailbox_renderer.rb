require 'net/http'
require 'uri'

class Message::MailboxRenderer < ParagraphRenderer

  features '/message/mailbox_feature'

  paragraph :mailbox, :ajax => true
  paragraph :notify, :ajax => true
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
    when 'inbox':   display_inbox
    when 'sent':    display_sent
    when 'message': display_message
    when 'write':   if(!display_write) 
                      display_inbox
                    end
    when 'autocomplete': 
                  return json_autocomplete(params[:keyword])
    when 'load_message'
                  return load_message(params[:load_message_id],@options.template_categories_list)
    end
    
    @view_data[:renderer] = self
    @view_data[:overlay] = false
    @view_data[:editor] = editor?
    @view_data[:paragraph_options] = @options
   
    @view_data[:mod_opts] = module_options(:message)
    feature_output = message_mailbox_mailbox_feature(@view_data)
    if ajax?
      render_paragraph :text => feature_output
    else
      render_paragraph :partial => '/message/mailbox/mailbox', :locals => {:feature_output => feature_output, :view_data => @view_data  }
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

    end_user_table_generate(@tbl,:conditions => [ "to_user_id = ? AND deleted=0 AND sent=0",myself.id],:order => 'message_recipients.created_at DESC',:per_page => 10, :joins => "LEFT JOIN end_users AS from_users ON  `from_users`.id = `message_recipients`.from_user_id", :joins => [ :message_message, :from_user ], :include => [ :message_message, :from_user] )

    @view_data = {  :tbl => @tbl, :renderer => self, :page => 'inbox' }
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
    ])
    end_user_table_action(@tbl) do |act,mids|
      if act == 'delete'
        MessageRecipient.find(:all,:conditions => { :from_user_id => myself.id, :id => mids, :sent => true }).each do |message|
          message.update_attribute(:deleted,true)
        end
      end
    end

    end_user_table_generate(@tbl,:conditions => [ "message_recipients.from_user_id = ? AND message_recipients.notification=0 AND deleted=0 AND sent=1",myself.id],:order => 'message_recipients.created_at DESC',:per_page => 10, :joins => [ :message_message ], :include => [ :message_message]  )

    @view_data = { :tbl => @tbl, :renderer => self, :page => 'sent'  }
  end
  
  
  def display_message
    message = MessageRecipient.find_by_id(params[:message_id],:conditions => ['to_user_id  = ? OR from_user_id = ?',myself.id,myself.id] )
    
    if !message
      display_inbox
      return
    end
    
    message.mark_opened! if !message.opened?

    reply = message.reply_content if message.from_user
    
    if message.notification? && params[:notify_action]
      message.notification_class_instance.process_action(params[:notify_action])
    end
    
    if request.post? && params[:reply]
      reply.attributes = params[:reply].slice(:message,:subject)
      if reply.valid?
        reply.save
        reply.send_message(message.from_user)
        flash.now[:message_sent] = "Your message has been sent".t
        display_inbox
        return
      end
    end
    
    if message.notification?
      content =  message_mailbox_notification_feature({:message => message},simple_format(message.message))
    else
      content = simple_format(h(message.message))
    end
    
    if message.message_thread
      previous_messages = message.message_thread.message_history(myself,message)
    end
    
    @view_data = { :message => message, :reply => reply, :content => content, :previous_messages => previous_messages, :page => 'message' }
  end
  
  def display_write

    message = MessageMessage.write_message(myself,params[:message])

    if request.post? && params[:message] 
      if !params[:partial] && message.valid?
        message.deliver_message(:single => @options.single_message ? true : false)
        flash.now[:message_sent] = "Your message has been sent".t
        return false
      end
    end

    if params[:recipient_id]
      message.recipient_ids = params[:recipient_id].to_s.split(",").join("###")
    end

    @suser = SocialUser.user(myself) 

    targets = @suser.social_units + EndUser.find(:all,:conditions => { :id => SocialFriend.friends_cache(myself.id) },:order => 'last_name,first_name', :include => :domain_file )

    @view_data = { :message => message, :friends => targets }
    @view_data[:message_vars] = nil

    if !@options.template_categories.blank?
      categories = @options.template_categories_list
      if categories.length > 0
        @view_data[:message_templates] = MessageTemplate.select_options(:conditions => ['category IN (?)',categories])

      end
    else
      @view_data[:message_templates] = []
    end

    @view_data[:page] = 'write'
    true
  end


  public
  
  
  def notify
    if !myself.id 
      render_paragraph :text => ''
      return
    end

    message_count = MessageRecipient.unread_count(myself)

    options = paragraph_options(:notify)
    data = { :messages => message_count, :user => myself, :mail_page_url => options.mailbox_page_url, :overlay => options.overlay == 'yes', :ajax => ajax?, :paragraph => paragraph, :editor => editor?,  :update => options.update  }
    feature_output = message_mailbox_notify_feature(data)

    require_js('prototype')
    require_js('effects')
    require_js('builder')
    if options.overlay
      require_js('redbox')
      require_css('redbox')        
      require_js('end_user_table')
      require_css('end_user_table.css')
    end
    require_js('user_application')

    render :text => feature_output
  end

  def load_message(message_id,categories,args={ })
    @message_template = MessageTemplate.find_by_id(message_id,:conditions => {  :category => categories})

    if @message_template
      vars = {:user => myself.name }
      
      @suser = SocialUser.user(myself) 
      @unit = @suser.social_units[0]
      
      vars[:group]  = @unit.name if @unit

      if args && args.is_a?(String)
        arg_values = CGI.unescape(args).split("::")

        args ={ }
        arg_values.each do |val|
          key,itm = val.split("//")
          args[key] = itm
        end
      end
      if args
        vars.merge!(args.symbolize_keys)
      end
      
      @message_template.subject = @message_template.variable_replace(@message_template.subject,vars)
      @message_template.message = @message_template.variable_replace(@message_template.message,vars)
    end

    render_paragraph :rjs => '/message/mailbox/load_message', :locals => { :message_template => @message_template }
  end

  def json_autocomplete(keywords)
    mod_opts = Message::AdminController.module_options
    if mod_opts.use_friends 
      @suser = SocialUser.user(myself) 
      @users = SocialUnit.find(:all,:conditions => ['social_unit_members.end_user_id=?', myself.id],:group => 'social_units.id', :joins => 'LEFT JOIN social_unit_members ON (social_unit_members.social_unit_id = social_units.id)' )
      @users += SocialFriend.find(:all,:conditions => ["social_friends.end_user_id=?",myself.id],:group => 'end_users.id',:joins => [ :friend_user ]).collect { |usr| usr.friend_user }
    else
      @users =EndUser.find(:all, :order => 'last_name, first_name')
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
        return load_message(params[:load_message_id],@options.template_categories_list,params[:message_vars] || { })
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
    @view_data[:message_vars] = params[:message_vars]
    
    
    if ajax?
      render_paragraph :partial => @display_partial, :locals => @view_data  
    else
      render_paragraph :partial => '/message/mailbox/mailbox', :locals => {:view_data =>  @view_data, :partial => @display_partial }
    end

      
  end


end
