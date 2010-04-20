# Copyright (C) 2009 Pascal Rettig.

require  File.expand_path(File.dirname(__FILE__)) + "/../../../../../spec/spec_helper"


describe MessageMessage do

  reset_domain_tables :message_messages, :end_users, :message_threads, :message_recipients, :message_templates

  before(:each) do
    @myself = mock_user
    @user1 = Factory.create(:end_user)
    @user2 = Factory.create(:end_user)
  end
 
  it "should be able to write and send a message" do
    @message = MessageMessage.write_message(@myself,
                                  :subject => 'Subjecterama',
                                  :message => "This is the message")

    @message.send_message([ @user1,@user2 ])

    @message.reload

    @message.subject.should == 'Subjecterama'
    @message.message.should == 'This is the message'

    @message.message_recipients[0].to_user.should == @user1
    @message.message_recipients[1].to_user.should == @user2
    @message.message_recipients[2].to_user.should == @myself
    @message.message_recipients[2].sent.should be_true
    @message.notification.should be_false
  end

  it "should be able to write and deliver a message" do

    # create a fake ### separated user string

    recipient_string = "end_user_#{@user2.id}###end_user_#{@user1.id}"
    @message = MessageMessage.write_message(@myself,
                                            :subject => 'Yo Subject here',
                                            :message => 'Body here',
                                           :recipient_ids => recipient_string)
    assert_difference "MessageRecipient.count", 3 do 
      @message.deliver_message
    end

    @message.subject.should == 'Yo Subject here'
    @message.message.should == 'Body here'

    @message.message_recipients[0].to_user.should == @user2
    @message.message_recipients[1].to_user.should == @user1
    @message.message_recipients[2].to_user.should == @myself
    @message.message_recipients[2].sent.should be_true
  end


  it "should be able to write and send a notification" do
    @message = MessageMessage.write_notification(
                                  :subject => 'Notification',
                                  :message => "This is the notification message")
         
    @message.send_notification([ @user1,@user2 ])

    @message.reload

    @message.subject.should == 'Notification'
    @message.message.should == 'This is the notification message'

    @message.message_recipients[0].to_user.should == @user1
    @message.message_recipients[1].to_user.should == @user2
    @message.notification.should be_true

  end

  it "shouldn't let you send and invalid message" do 
    # create a fake ### separated user string

    recipient_string = ""
    @message = MessageMessage.write_message(@myself,
                                            :subject => 'Yo Subject here',
                                            :message => 'Body here',
                                           :recipient_ids => recipient_string)
    assert_difference "MessageMessage.count",0 do 
      @message.deliver_message.should be_false
    end
  end
    

  
end
