require 'rubygems'
require 'redgreen'

require 'xmpp4r'
require 'xmpp4r/muc'
require 'xmpp4r/roster'
require 'xmpp4r/client'
require "xmpp4r/pubsub"

require 'lib/jabber_extend'

include Jabber
Jabber::debug = true

def roomlistxml
  require 'yaml'
  
  roomlist_xml = REXML::Element.new('rooms')
  roomlist = File.open( 'rooms.yml' ) { |yml| YAML::load(yml) }
  roomlist.each{|room|
                 roomlist_xml.add_element('room', {'jid' => room["jid"], 'name' => room["name"]})
               }
  return roomlist_xml
end

TRIVIAROOMS_USER = "triviarooms@dev.triviapad.com"
TRIVIAROOMS_PASS = "roomstrivia"
TRIVIAROOMS_SERVICE = 'pubsub.dev.triviapad.com'
TRIVIAROOMS_NODE = 'triviapad/rooms'

@jclient = Jabber::Client.new(Jabber::JID::new(TRIVIAROOMS_USER))
puts Color.yellow("Connecting...")
@jclient.connect
puts Color.yellow("Connected to server as #{TRIVIAROOMS_USER}")
@jclient.auth(TRIVIAROOMS_PASS)
puts Color.yellow("Authenticated!")

@jclient.send(Jabber::Presence.new.set_type(:available))

pubsub = Jabber::PubSub::ServiceHelper.new(@jclient, TRIVIAROOMS_SERVICE)
pubsub.delete_node(TRIVIAROOMS_NODE)
puts Color.yellow("Node #{TRIVIAROOMS_NODE} deleted")

pubsub.create_node(TRIVIAROOMS_NODE)
puts Color.yellow("Node #{TRIVIAROOMS_NODE} created ok")

#fetch rooms
# item = Jabber::PubSub::Item.new()
# item.add_attributes('name' => 'triviaroom')
# item.add_attributes('jid' => 'triviaroom@dev.triviapad.com')
# #item.add(roomlistxml)
# puts Color.yellow("Item prepared -> #{item.to_s}")


item = Jabber::PubSub::Item.new
item.add_attributes('jid' => 'trivianerds@dev.triviapad.com')
item.add_element('room', {'type' => 'trial', 'name' => 'TriviaNerds', 'jid' => 'trivianerds@dev.triviapad.com', 'muc' => 'chatrooms@dev.triviapad.com/trivianerds', 'topic' => 'Miscelanea', 'question' => '11', 'questions' => '20', 'players' => '16'})


puts Color.yellow("Room prepared for publishing -> #{item.to_s}")

# publish item
pubsub.publish_item_with_id_to(TRIVIAROOMS_NODE, item, 'trivianerds')
puts Color.yellow("Item published!")


@jclient.add_xml_callback do |xml|
  puts Color.white("EVENT ::: XML received => #{xml.from} =>> #{xml.to_s}")
end

@jclient.add_stanza_callback do |stanza|
  puts Color.white("EVENT ::: STANZA received => #{stanza.from} =>> #{stanza.to_s}")
end

@jclient.add_presence_callback do |pres|
  puts Color.yellow("EVENT ::: Presence received from (#{pres.from}) => #{pres.to_s}")
end

@jclient.add_iq_callback do |iq|
  puts Color.blue("EVENT ::: IQ Callback -> #{iq.inspect}")
  # response = Iq.new(:result, iq.from)
  # response.id = iq.id
  # response.add_element('query', {'xmlns' => xmlns='http://jabber.org/protocol/disco#items'}).add_element('item', {'id' => 'item01', 'name' => 'room 01'})
  # @jclient.send(response)
end


@jclient.add_message_callback do |msg|
  puts Color.red("EVENT ::: Message received from (#{msg.from}) => #{msg.inspect}")
  case msg.type
  when :roomlist
    roomlist_xml = REXML::Element.new('rooms')
    roomlist = File.open( 'rooms.yml' ) { |yml| YAML::load(yml) }
    roomlist.each{ |room|
                   roomlist_xml.add_element('room', {'jid' => room["jid"], 'name' => room["name"]})
                 }
    response = Message.new_by_type(:roomlist, msg.from)
    response
    response.add_element('query', {'xmlns' => xmlns='rooms#disco#items'})
    puts Color.red("RESPONSE :: #{response.inspect}")
    @jclient.send(response)
  when :chat
    #send_message(msg.from, "I'm a bot. Leave me alone!")
  end
end


puts Color.red("Entering looped listening...")

exit = false
loop {
  sleep(1)
} until exit
