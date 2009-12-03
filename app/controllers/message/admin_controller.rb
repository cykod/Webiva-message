

class Message::AdminController < ModuleController

  component_info 'Message', :description => 'User Messaging support', 
                              :access => :private
                              
  # Register a handler feature
  register_permission_category :message, "Message" ,"Permissions related to User Messaging"
  
  register_permissions :message, [ [ :manage, 'Manage Messaging', 'Manage Messaging' ],
                                  [ :config, 'Configure Messaging', 'Configure Messaging' ]
                                  ]

  register_handler :navigation, :emarketing, "Message::MessageTemplateController"
  
  register_handler :members, :view,  "Message::ManageController"

  cms_admin_paths "options",
                   "Options" =>   { :controller => '/options' },
                   "Modules" =>  { :controller => '/modules' },
                   "Messaging Options" => { :action => 'index' }
 
 public 
 
 def options
    cms_page_path ['Options','Modules'],"Messaging Options"
    
    @options = self.class.module_options(params[:options])
    
    if request.post? && params[:options] && @options.valid?
      Configuration.set_config_model(@options)
      flash[:notice] = "Updated Message module options".t 
      redirect_to :controller => '/modules'
      return
    end    
  
  end
  
  def self.module_options(vals=nil)
    Configuration.get_config_model(Options,vals)
  end
  
  class Options < HashModel
    attributes :overlay => true, :inbox_page_id => nil, 
    :use_friends => false, :clickatel_api_id  => nil,:clickatel_user => nil, :clickatel_password => nil, :message_footer => '', :daily_limit => 30, :message_header => 'Msg from %%name%%:', 
    :message_template_id => nil, :sms_page_id => nil,
    :admin_message_category_templates => nil
    
    integer_options :inbox_page_id, :message_template_id
    boolean_options :overlay, :use_friends 
    
    page_options :inbox_page_id, :sms_page_id
 
    def admin_message_category_list
      self.admin_message_category_templates.to_s.strip.split(",").map(&:strip).reject(&:blank?)
    end
  end
  

end
