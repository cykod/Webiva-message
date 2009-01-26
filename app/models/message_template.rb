

class MessageTemplate < DomainModel


 validates_presence_of :name, :subject,:message
 
 def before_save
  self.language = 'en' if self.language.blank? 
 end
 
 def self.create_message(name,from_user=nil,args = {},language = 'en') 
  args = args.clone
  
  usr = args.delete(:user) || from_user
  if usr
    args[:first_name] = usr.first_name
    args[:last_name] = usr.last_name
    args[:name] = usr.name
  end
  
  tpl = self.find_by_name_and_language(name,'en') || self.find_by_name(name)
  return nil unless tpl
  
  tpl.create_message(from_user,args)
 end
 
 def create_message(from_user=nil,args={})
   MessageMessage.new(:message => self.rendered_message(args),
                     :notification=>self.notification,
                     :subject => self.rendered_subject(args),
                     :message_template_id => self.id,
                     :from_user => from_user
                     )
 end
 
 def rendered_update(msg,args); variable_replace(self.send("#{msg}_message"),args); end
 
 def rendered_message(args); variable_replace(self.message,args); end
 def rendered_subject(args); variable_replace(self.subject,args); end
end
