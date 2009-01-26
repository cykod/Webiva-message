

class Message::Notification

  attr_reader :msg, :recipient
  
  def initialize(recipient,msg)
    @msg = msg
    @recipient = recipient
  end
  
  def self.handle_actions(*acts)
    acts = acts.map { |elm| elm.to_s }
    self.send(:define_method,:valid_actions) do 
        acts
    end
  end
  
  def process_action(act)
    if self.valid_actions.include?(act)
      self.send(act)
    else 
      raise "Invalid Notification Action:" + act.to_s
    end
  end

end
