#########################################################################################################
#########################################################################################################
#########################################################################################################
#
# Allows to sned looped IQ queries to check features
#
#########################################################################################################
#########################################################################################################
#########################################################################################################


require 'rubygems'
require 'redgreen'

require 'xmpp4r'
require 'xmpp4r/muc'
require 'xmpp4r/roster'
require 'xmpp4r/client'

require 'lib/jabber_extend'

include Jabber
Jabber::debug = true

BOTJID = "fulanito@dev.triviapad.com/bot"
BOTPASSWD = "fulanito"
#HOST_NODE = "triviarooms.dev.triviapad.com"
HOST_JID = "server@dev.triviapad.com"

puts Color.red("Conecting...")

jid = Jabber::JID::new(BOTJID)
jclient = Jabber::Client.new(jid)
jclient.connect
jclient.auth(BOTPASSWD)

puts Color.red("Authenticated!")

jclient.send(Jabber::Presence.new.set_type(:available))

puts Color.red("Presence announced as available")

# jclient.add_xml_callback do |xml|
#   puts "DEBUG:: XML received => #{xml.from} =>> #{xml.to_s}"
# end

# jclient.add_stanza_callback do |stanza|
#   puts "DEBUG:: STANZA received => #{stanza.from} =>> #{stanza.to_s}"
# end
# 
# jclient.add_iq_callback do |iq|
#   puts "DEBUG:: IQ received => #{iq.from} =>> #{iq.to_s}"
#   #send_message(msg.from, "I'm a bot. Leave me alone!")
# end
# 
jclient.add_message_callback do |msg|
  puts Color.red("Message received => #{msg.from} --> #{msg.type}")
  case msg.type
  when :roomlist
    if msg.body.query
      puts Color.blue("Roomlist received -> #{msg.body.query.inspect}")
    end
  when :chat
    #send_message(msg.from, "I'm a bot. Leave me alone!")
  end
  #send_message(msg.from, "I'm a bot. Leave me alone!")
end

# iq = Jabber::Iq.new(:get, HOST_NODE)
# iq.from = jid
# iq.id = 'iq001'
# iq.add_element('ping', { 'xmlns' => 'urn:xmpp:ping'} )
# iq.add_element('query', {'xmlns' => 'http://jabber.org/protocol/disco#items'})


msg = Jabber::Message.new_by_type(:roomlist, HOST_JID)
#msg.type = :roomlist
msg.from = jid
msg.id = 'roomlist001'
msg.add_element('query', {'xmlns' => xmlns='rooms#disco#items'})


puts Color.red("LOOPED REQUEST SENDING => #{msg.class} =>> #{msg.inspect}")


exit = false
loop {
  puts "Querying..."
  jclient.send(msg)
  sleep(10)
} until exit

puts "XDEBUG :: I'm done!"