require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../../spec/spec_helper"

add_factory_girl_path(File.join(File.expand_path(File.dirname(__FILE__)),"..",".."))


describe Message::MailboxRenderer, :type => :controller do
  
  controller_name :page

  integrate_views

  reset_domain_tables :message_messages, :end_users, :message_threads, :message_recipients, :message_templates

  before do
    @myself = mock_user
  end

  describe "Mailbox paragraph" do 

    renderer_builder '/message/mailbox/mailbox'

    it "should be able to display the inbox" do
      @rnd = mailbox_renderer
      renderer_get @rnd
      response.should render_template('message/mailbox/_display_inbox')
    end

    describe "display partial pages" do 
      before do
        @rnd = mailbox_renderer
        @rnd.should_receive(:ajax?).at_least(:once).and_return(true)
      end

      it "should be able to display the sent page via ajax" do
        renderer_get @rnd, :page => 'sent'
        response.should render_template('message/mailbox/_display_sent')
      end

      it "should display the inbox without a valid message message" do

        renderer_get @rnd, :page => 'message'
        response.should render_template('message/mailbox/_display_inbox')
      end

      it "should be able to display the write page" do
        renderer_get @rnd, :page => 'write'
        response.should render_template('message/mailbox/_write')
      end

      describe "message view" do
        before do
          @user1 = Factory.create(:end_user)
          @user2 = Factory.create(:end_user)

          @message = MessageMessage.write_message(@myself,
                                            :subject => 'Yo Subject here',
                                            :message => 'Body here')
          @message.send_message([@user1,@user2])
        end


        it "should be able to display a message" do 

          renderer_get @rnd, :page => 'message', :message_id => @message.id
          response.should include_text("Yo Subject here")
          response.should include_text(@user1.name)
          response.should include_text(@user2.name)
        end

      end

    end
  end
  
end

