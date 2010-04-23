

class Message::MailboxFeature < ParagraphFeature


  feature :message_mailbox_mailbox, :default_css_file => '/components/message/stylesheets/mailbox.css', :default_feature => <<-FEATURE
     <cms:notification>
     <div class='message_notification'><cms:value/></div>
   </cms:notification>
   <cms:inbox>
      <div class='message_button_row'>
              <cms:write_link>+ New Message</cms:write_link>
              <cms:sent_link>Sent Messages &raquo;</cms:sent_link>
      </div>
      <cms:message_table/>
   </cms:inbox>
   <cms:sent>
     <div class='message_button_row'>
              <cms:inbox_link>Inbox &raquo;</cms:inbox_link>
     </div>
      <cms:message_table/>
   </cms:sent>
   <cms:write>
        <cms:message_form/>
   </cms:write>
   <cms:message>
     <div class='message_button_row'>
         <cms:sent><cms:sent_link>Sent Messages &raquo;</cms:sent_link></cms:sent>
         <cms:received><cms:inbox_link>Inbox &raquo;</cms:inbox_link></cms:received>
      </div>

      <div class='message_message'>
        <cms:from_user>
        </cms:from_user>
        <ul class='message_header'>
          <cms:header><li><label><cms:field/>:</label><cms:display/></li></cms:header>
        </ul>
        <div class='message_body'><cms:message_body/></div>
        <cms:reply>
          <ul class='message_reply'>
            <li class='message_header'>Reply to this message:</li>
            <cms:reply_errors>
              <li class='error'><cms:value/></li>
            </cms:reply_errors>
            <li><cms:subject_label/><cms:subject/></li>
            <li><cms:body_label/><cms:body/></li>
            <li class='button'><cms:reply_button/></li>
          </ul>
        </cms:reply>
  
        <cms:thread>
          <cms:message>
          <div class='message_thread'>
           <cms:from_user>
           </cms:from_user>
           <ul class='message_thread_header'>
             <cms:header><li><label><cms:field/>:</label><cms:display/></li></cms:header>
           </ul>
           <div class='message_thread_body'><cms:message_body/></div>
          </div>
          </cms:message>
        </cms:thread>
      </div>
   </cms:message>
  FEATURE
  

  def message_mailbox_mailbox_feature(data)
    webiva_feature(:message_mailbox_mailbox) do |c|
        c.value_tag('notification') { |t| flash[:message_sent] }

        c.expansion_tag('inbox') { |t| data[:page] == 'inbox' }      
          c.define_tag('inbox:message_table') do |t|
            render_to_string :partial => "/message/mailbox/display_inbox",:locals => data
          end
        c.expansion_tag('sent') { |t| data[:page] == 'sent' }      
          c.define_tag('sent:message_table') do |t|
            render_to_string :partial => "/message/mailbox/display_sent",:locals => data
          end

        c.expansion_tag('write') { |t| data[:page] == 'write' }      
           c.define_tag('write:message_form') do |t|
            render_to_string :partial => "/message/mailbox/write",:locals => data
           end
        c.expansion_tag('message') { |t| data[:page] == 'message' ? t.locals.message = data[:message] : nil  }      
           
          c.expansion_tag('message:sent') { |t| data[:message].sent? }
          c.expansion_tag('message:received') { |t| !data[:message].sent? }

          define_message_tags(c,'message') { |t| data[:message] }
          c.value_tag("message:message_body") { |t| data[:content] }

        c.form_for_tag("message:reply","reply") do |t|
          message = data[:message]
          unless message.from_user.blank? || (message.notification? && !message.message_message.handled?) 
            if data[:message].from_user_id != myself.id 
             { :object => data[:reply],
               :html => { :onsubmit => "MessageViewer.replyMessage(#{data[:message].id}); return false;",
                          :style => 'width:100%', 
                            :id => 'message_write_form' }
             }
            end
          end
        end
        c.form_error_tag("message:reply_errors") 
           c.field_tag("message:reply:subject")
           c.field_tag("message:reply:body",:field => "message", :control => "text_area",:rows => 10)
           c.button_tag("message:reply:reply_button",:default => "Send")

        c.expansion_tag("message:thread") { |t| data[:previous_messages].length > 0 }
          c.loop_tag("message:thread:message","messages", :local => "thread") { |t| data[:previous_messages] }
            define_message_tags(c,"message:thread:message",:local => "thread") 


        c.link_tag('write') do |t| 
            { :href=>'javascript:void(0);', :onclick => 'MessageViewer.writeMessage();' } 
        end

        c.link_tag('sent') do |t| 
            { :href=>'javascript:void(0);', :onclick => 'MessageViewer.sentMessages();' } 
        end
         c.link_tag('inbox') do |t| 
            { :href=>'javascript:void(0);', :onclick => 'MessageViewer.inbox();' } 
        end
         
        
          
    end
  end

  def define_message_tags(c,name_base,options = {}) 
    local = options.delete(:local) || 'message'
    c.expansion_tag("#{name_base}:from_user") { |t| t.locals.user = t.locals.send(local).from_user }

    c.link_tag("#{name_base}:profile") { |t| "#" }
    c.image_tag("#{name_base}:image",nil,nil,:size => 'small') { |t| t.locals.user.image }

    c.define_tag("#{name_base}:header") do |t|
      msg = t.locals.send(local)
      values = { "sent"=> [ "Sent".t, msg.created_at.to_s(:long) ],
                 "from"=> [ "From".t, msg.from_user.name ],
                 "to"=> msg.notification? ? nil : [ "To", msg.display_recipients ],
                 "subject"=> [ "Subject".t,msg.subject ]
               }
      fields = t.attr['fields'] ? t.attr['fields'].split(",").map(&:strip) : %w(sent from to subject)
      field_values = fields.map { |fld| values[fld] }.compact
      c.each_local_value(field_values,t,"header_value")
    end

    c.h_tag("#{name_base}:header:field") { |t| t.locals.header_value[0] }
    c.h_tag("#{name_base}:header:display") { |t| t.locals.header_value[1] }

    c.value_tag("#{name_base}:message_body") { |t| simple_format(h(t.locals.send(local).message)) }



  end

  feature :message_mailbox_notify, :default_feature => <<-FEATURE
   <cms:user>
    <cms:no_messages>
      <cms:mailbox_link>Messages</cms:mailbox_link>
    </cms:no_messages>
    <cms:messages>
      <cms:mailbox_link><b>Messages (<cms:count/>)</b></cms:mailbox_link>
    </cms:messages>
   </cms:user>
  FEATURE


  def message_mailbox_notify_feature(data)
    webiva_feature(:message_mailbox_notify) do |c|
      c.define_tag('user') do |t| 
        t.expand
      end
        c.define_link_tag('user:mailbox') do |tag|
         if data[:overlay]
          { :href => 'javascript:void(0);', :onclick => "SCMS.remoteOverlay('#{data[:mail_page_url]}');" }
         else
          data[:mail_page_url]
         end
        end
        
        c.define_expansion_tag('user:messages') { |tg| data[:messages] > 0 }
          c.define_value_tag('user:messages:count') { |tg| data[:messages] }
          
          c.value_tag('user:friend_count') { |t| data[:present_friends].length }         
        
        c.define_loop_tag('user:friend') { |t| data[:present_friends] }
          c.value_tag('user:friends:name') { |t| t.locals.friend.name }
          
        c.expansion_tag('user:profile') do |t|  
          if t.attr['equals']
            myself.user_profile_id == t.attr['equals'].to_i
          elsif t.attr['not']
            myself.user_profile_id != t.attr['not'].to_i
          end
        end

        c.expansion_tag('user:details') { |t| t.locals.user = myself } 
        c.define_user_details_tags('user:details',:local => 'user')

    end
  end
  
  feature :message_mailbox_notification
  
  
  def message_mailbox_notification_feature(data)
    webiva_custom_feature(:message_mailbox_notification,data) do |c|
      c.define_tag("button") { |tg| "<button onclick='MessageViewer.submitNotification(#{data[:message].id},\"#{tg.attr['action']}\");'>#{tg.expand}</button>" }
    end
  end

end
