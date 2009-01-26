


class MessageTxtVerification < DomainModel



  def self.user_verification(usr,cell_number,code=nil)
    verify = self.find_by_end_user_id(usr.id) || self.new(:end_user_id => usr.id)
    
    if verify.cell_number == cell_number && verify.verified?
      true
    elsif verify.cell_number == cell_number && code == verify.verification_code
      verify.save
      true
    else
      verify.update_attributes(:verified => false,:cell_number => cell_number,:verification_code => generate_verification_code)
      false
    end
  end
  

  
  
  def self.generate_verification_code 
     letters = '123456789ACEFGHKMNPQRSTWXYZ'.split('')
     unique = false
     sec = Time.now.sec
     num = (0..7).to_a.collect { |n| letters[(rand(20000) + sec) % letters.length] }.join
  end
end

