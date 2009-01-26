

class Message::MessageTemplateController < ModuleController


  permit 'message_manage'
  component_info 'Message'
  
   cms_admin_paths "content",
                   "Content" =>   { :controller => '/content' },
                   "Messaging Templates" => { :action => 'index' }
  
  
  def self.navigation_emarketing_handler_info
     {
     :pages => 
        [ [ "Messaging Templates", :message_manage, "emarketing_campaigns.gif", {  :controller => '/message/message_template' },
         "Edit the Templates for In-site Messaging and Notification" ]
        ]
    }
  end
  
  include ActiveTable::Controller
  
  
  active_table :message_templates_table, MessageTemplate, [:check,:name,:subject,:created_at,:updated_at]
                

  def display_message_templates_table(display=true)
    
    active_table_action('message') do |act,tids|
      case act
      when 'delete'
        MessageTemplate.destroy(tids)
      end
    end
    
    @tbl = message_templates_table_generate params, :order => 'message_templates.created_at DESC'
  
    render :partial => 'message_templates_table' if display
  end 

  def index
    cms_page_path [ "Content"],"Messaging Templates"
  
    display_message_templates_table(false)
  end


  def edit
    @msg = MessageTemplate.find_by_id(params[:path][0]) || MessageTemplate.new
    
    cms_page_path [ "Content", "Messaging Templates"],@msg.id  ? 'Edit Message Template' : 'Create Message Template'

    if request.post? && @msg.update_attributes(params[:msg])
      redirect_to :action => 'index'    
    end    
  end
end
