

class Message::MailboxFeature < ParagraphFeature


  feature :message_mailbox_mailbox, :default_feature => <<-FEATURE
    Mailbox Feature Code...
  FEATURE
  

  def message_mailbox_mailbox_feature(data)
    webiva_feature(:message_mailbox_mailbox) do |c|
      # c.define_tag ...
    end
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
        
        c.define_link_tag('user:text_message') do |tag|
          if data[:overlay]
            { :href => 'javascript:void(0);', :onclick => "SCMS.remoteOverlay('#{data[:text_page_url]}');" }
           else
             data[:text_page_url]
          end
        end
        c.define_expansion_tag('user:messages') { |tg| data[:messages] > 0 }
          c.define_value_tag('user:messages:count') { |tg| data[:messages] }
          
        c.link_tag('user:show_chat') do |tag|
          if data[:present_friends].length > 0 
            friend_links = jvh((data[:present_friends]||[]).compact.map do |friend|
              "<a href=\"javascript:void(0);\" onclick=\"cClick(); MessageNotify.chat(#{friend.id});\">#{h friend.name}</a>"
            end.join("<br/>"))
            { :href => 'javascript:void(0);', 
              :onclick => "return overlib('#{friend_links}',STICKY,CAPTION,'Online Friends');"
            }
          else
            nil
          end
        end
          c.value_tag('user:friend_count') { |t| data[:present_friends].length }         
        
        c.define_loop_tag('user:friend') { |t| data[:present_friends] }
          c.link_tag('user:friends:chat') { |t| { :href=>'javascript:void(0);' } }
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
  
  
  def message_mailbox_notification_feature(data,feature_content)
    webiva_custom_feature(feature_content) do |c|
      c.define_tag("button") { |tg| "<button onclick='MessageViewer.submitNotification(#{data[:message].id},\"#{tg.attr['action']}\");'>#{tg.expand}</button>" }
    end
  end

end
