
class Message::ManageController < ModuleController

  permit 'message_manage'

  component_info 'Message'

  def self.members_view_handler_info
    { 
      :name => "User Messages",
      :controller => '/message/manage',
      :action => 'user',
      :permit => 'message_manage'
    }
   end  

  include ActiveTable::Controller
  active_table :members_message_table, MessageRecipient,
   [ hdr(:boolean,'message_recipients.deleted',:label => 'Del'),
     hdr(:string,'message_messages.subject'),
     "From", "Recipients", :created_at ]

  def display_members_message_table(display = true)
    @user ||= EndUser.find(params[:path][0])

    @tbl = members_message_table_generate params,  :conditions => ['to_user_id = ?',@user.id], :joins => [ :message_message ], :include => [ :from_user ],:order => 'message_recipients.created_at DESC'

    render :partial => 'members_message_table' if display
  end


  def user
    @user = EndUser.find(params[:path][0])
    @tab = params[:tab]

    @message = MessageMessage.new(:recipient_ids => "end_user_#{@user.id}" )

    categories = Message::AdminController.module_options.admin_message_category_list
    if categories.length > 0
      @message_templates = MessageTemplate.select_options(:conditions => ['category IN (?)',categories])
    end

    
    if request.post? && params[:message]
      @message.attributes = params[:message]
      @message.from_user = myself
      @message.valid?
      valid_users = @message.recipient_users
      if valid_users.length == 0
        @message.errors.add(:recipient_ids,' must be selected')
      end
      

      if @message.errors.length == 0
        @message.save
        @message.send_message(valid_users)
        flash.now[:message_sent] = true
        @message = MessageMessage.new(:recipient_ids => "end_user_#{@user.id}" )
      else 
        @write = true
      end
    end

    display_members_message_table(false)

    render :partial => 'user'
  end


  def write_overlay
    @message = MessageMessage.new()

    if request.post? && params[:message] 
      @message.attributes = params[:message]
      @message.from_user = myself
      
      valid_users = []
      
      if !params[:partial]
        @message.valid?
        @message.recipient_users.each do |usr|
          valid_users << usr
        end
        if valid_users.length == 0
          @message.errors.add(:recipient_ids,' must be selected')
        end
        
        if @message.errors.length == 0
          @message.save
          @message.send_message(valid_users,:single => true)
          flash.now[:message_sent] = true
        end
      end
    end
    
    if params[:recipient_id]
      @message.recipient_ids = params[:recipient_id].to_s.split(",").join("###")
    end

    categories = Message::AdminController.module_options.admin_message_category_list
    if categories.length > 0
      @message_templates = MessageTemplate.select_options(:conditions => ['category IN (?)',categories])
    end

    render :partial => 'write_overlay'
  end

  def autocomplete
    mod_opts = Message::AdminController.module_options
    if mod_opts.use_friends 
      @suser = SocialUser.user(myself) 
      @users = SocialUnit.find(:all,:conditions => ['social_unit_members.end_user_id=?', myself.id],:group => 'social_units.id', :joins => 'LEFT JOIN social_unit_members ON (social_unit_members.social_unit_id = social_units.id)' )
      @users += SocialFriend.find(:all,:conditions => ["social_friends.end_user_id=?",myself.id],:group => 'end_users.id',:joins => [ :friend_user ]).collect { |usr| usr.friend_user }
    else
      @users = EndUser.find(:all, :order => 'last_name, first_name')
    end
    values = @users.map {  |elm| {  :caption => elm.name, :value => "end_user_#{elm.id}"} }
    render :text => values.to_json()
  end

  def load_template
    
    @message_template = MessageTemplate.find_by_id(params[:load_template_id]) 

  end

  def display_message
    @user = EndUser.find(params[:path][0])
    
    @message = MessageRecipient.find_by_id_and_to_user_id(params[:message_id],@user.id)

    render :partial => 'message', :locals => {  :message => @message }
  end
end
