#Extending XMPP4R base classes

class Jabber::JID
  
  #Add nickname method to JID
  def nickname
    self.resource.scan(%r{^(\S+)@})
    #self.resource
  end
    
end


class Jabber::XMPPStanza
  
  # Multicast receivers
  def receivers=(tos =[], ccs =[], bccs =[])
    if !tos.empty? | !ccs.empty? | !bccs.empty?
      addresses = self.root.add_element('addresses', { 'xmlns' => 'http://jabber.org/protocol/address'})
      tos.each{|to| addresses.add_element('address', { 'type' => 'to', 'jid' => to }) } if !tos.empty?
      ccs.each{|cc| addresses.add_element('address', { 'type' => 'cc', 'jid' => cc }) } if !ccs.empty?
      bccs.each{|bcc| addresses.add_element('address', { 'type' => 'bcc', 'jid' => bcc }) } if !bccs.empty?
    end
  end
  
  
end

class Jabber::Message

  def self.new_by_type(type, to=nil, body=nil)
    msg = self.new(to, body)
    if msg
      msg.type = type
    end
    return msg
  end
  

  def type
    case super
      when 'chat' then :chat
      when 'error' then :error
      when 'groupchat' then :groupchat
      when 'headline' then :headline
      when 'normal' then :normal
      # added for Triviajabber
      when 'question' then :question
      when 'reveal' then :reveal
      when 'answer' then :answer
      when 'ranking' then :ranking
      when 'status' then :status
      else nil
    end
  end
  
  
  def type=(v)
    case v
      when :chat then super('chat')
      when :error then super('error')
      when :groupchat then super('groupchat')
      when :headline then super('headline')
      when :normal then super('normal')
      # added for Triviajabber
      when :question then super('question')
      when :reveal then super('reveal')
      when :answer then super('answer')
      when :ranking then super('ranking')
      when :status then super('status')
      else super(nil)
    end
  end
  
  
  # Question Messages
  
  def question=(question)
     if self.type == :question
       qtemp = self.root.add_element('question', {'time' => question[:time], 'count' => question[:count], 'total' => question[:total]})
       qtemp.add_text(question[:text])
       return self
     else
       raise "Only :question typed messages admit question assign"
       return nil
     end 
  end

  def media=(media)
     if self.type == :question
       self.root.add_element('media', {'type' => media[:type], 'url' => media[:url]})
     else
       raise "Only :question typed messages admit media assign"
       return nil
     end
  end
  
  def answers=(options)
     if self.type == :question
       answers = self.root.add_element('answers')
       cont = 1
       options.each{|ans|
                     answers.add_element('answer', { 'id' => cont }).add_text(ans)
                     cont += 1
                    }
       
     else
       raise "Only :question typed messages admit media assign"
       return nil
     end
  end
  
  # Answer Messages
  
  def response=(response)
    if self.type == :answer
      self.root.add_element('response', {'option' => response[:option], 'time' => response[:time]})
    else
      raise "Only answer typed messages admit response assign"
      return nil
    end
  end
  
end






class Jabber::Presence
  
  def type
    case super
      when 'error' then :error
      when 'probe' then :probe
      when 'subscribe' then :subscribe
      when 'subscribed' then :subscribed
      when 'unavailable' then :unavailable
      when 'unsubscribe' then :unsubscribe
      when 'unsubscribed' then :unsubscribed
      when 'join' then :join
      else nil
    end
  end
  
  
  def type=(v)
    case v
      when :error then super('error')
      when :probe then super('probe')
      when :subscribe then super('subscribe')
      when :subscribed then super('subscribed')
      when :unavailable then super('unavailable')
      when :unsubscribe then super('unsubscribe')
      when :unsubscribed then super('unsubscribed')
      # added for Triviajabber
      when :join then super('join')
      else super(nil)
    end
  end
  
end
