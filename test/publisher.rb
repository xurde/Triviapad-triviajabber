#! /usr/bin/ruby
require "rubygems"
require "xmpp4r"

require "xmpp4r/pubsub"
require "xmpp4r/pubsub/helper/servicehelper.rb"
require "xmpp4r/pubsub/helper/nodebrowser.rb"
require "xmpp4r/pubsub/helper/nodehelper.rb"

include Jabber
Jabber::debug = true


TRIVIAROOMS_USER = "triviarooms@dev.triviapad.com"
TRIVIAROOMS_PASS = "roomstrivia"
PUBSUB_SERVICE = 'pubsub.dev.triviapad.com'

client = Client.new(JID.new(TRIVIAROOMS_USER))
client.connect
client.auth(TRIVIAROOMS_PASS)

client.send(Jabber::Presence.new.set_type(:available))

pubsub = PubSub::ServiceHelper.new(client, PUBSUB_SERVICE)
#reset and re-create node
pubsub.delete_node('trivia/rooms')
pubsub.create_node('triviapad/rooms')

# create item
item = Jabber::PubSub::Item.new
xml = REXML::Element.new("Trial")
xml.text = 'Trial Rooms'
item.add(xml);
xml = REXML::Element.new("Official")
xml.text = 'Official Rooms'
item.add(xml);

# publish item
node = 'trivia/rooms'
pubsub.publish_item_to(node, item)