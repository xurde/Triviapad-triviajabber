require 'singleton'

include Jabber
Thread.abort_on_exception = false
#Jabber::debug = true

# MAIN_BOT_USER = "triviarooms@raw.triviapad.com"
# MAIN_BOT_PASS = "roomstrivia"
# PUBSUB_HOST = 'pubsub.raw.triviapad.com'
# PUBSUB_NODE = "triviapad/rooms"
  

module TriviaServer
  
  SECS_LOOP_STATUS = 15
  
  class Server
    include Singleton
    
    #Class variables
    # @jclient -> Jabber::Client
    # @roomlist -> Array
    # @rooms -> Array[Room]
    
    def initialize

      #Load Datamapper models
      require TRIVIAJABBER_PATH + 'trivia_models'

      #Load room list
      @rooms = []
      @status = :initializing
      @logger = EventLogger.new("main-server-thread")
      @logger.log "Initializing main server thread", :debug, 'Server Initialize'
      @jclient = Jabber::Client.new(Jabber::JID::new(MAIN_BOT_USER))
      @logger.log "Connecting main BOT as #{MAIN_BOT_USER}...", :info, 'Initialize'
      @jclient.connect
      @logger.log "Connected to server as #{MAIN_BOT_USER}", :info, 'Initialize'
      @jclient.auth(MAIN_BOT_PASS)
      @logger.log "Authenticated!", :info, 'Initialize'
      
      @jclient.send(Jabber::Presence.new.set_type(:available))
            
      @jclient.add_message_callback do |msg|
        @logger.log "Message received from (#{msg.from}) => #{msg.inspect}", :info, 'Initialize'
        send_message(msg.from, "I'm a bot. Leave me alone!")
      end
      
      if restore_pubsub_node
        @logger.log "PubSub node (#{PUBSUB_NODE}) initialized", :info, 'Initialize'
      else
        @logger.log "PubSub node (#{PUBSUB_NODE}) NOT initialized", :info, 'Initialize'
      end
      
      if create_rooms
        @logger.log "Rooms created", :info, 'Initialize'
      end
      
      @jclient.on_exception do |e, stream, context|
        @logger.log "Jabber Stream Exception :: #{!e.nil? ? e.message : "- no message -"} : #{context}", :warn, 'jclient_on_exception'
        if @status != :offline
          old_status = @status
          @status = :offline
          begin
            sleep(2)
            @logger.log "Connecting to server as #{@botjid}", :info, 'jclient_on_exception'
          	@jclient.connect
          	@jclient.auth(@botpasswd)
          	@logger.log "Authenticated as #{@jclient.jid}!", :info, 'jclient_on_exception'
          	@jclient.send(Jabber::Presence.new.set_type(:available))
          	@status = old_status
          rescue
            @logger.log "Unable to reconnect. Retrying in 1 sec... ", :warn, 'jclient_on_exception'
            sleep(1)
          end until @status != :offline
        end
      end
    rescue Exception => e
      if @logger
        @logger.log "Excpetion while Initializing main thread: #{e.message} -- #{e.backtrace}", :fatal, 'initialize'
      else
        puts "Excpetion while Initializing main thread: #{e.message} -- #{e.backtrace}", :fatal, 'initialize'
      end
    end #initialize
    
    def stop
      #send term signal to all rooms
      @rooms.each{|r| r.stop}
      @status = :stopped
    end
    
    def restore_pubsub_node
      #reset and re-create node
      pubsub = PubSub::ServiceHelper.new(@jclient, PUBSUB_HOST)
      #begin
        begin
          pubsub.delete_node(PUBSUB_NODE)
        rescue
        end
        pubsub.create_node(PUBSUB_NODE)
        return true
      # rescue
      #   return false
      # end
    end
    
    def create_rooms
      roomlist = Room.all( :status => 'A')
      roomlist.each{ |room|
          @logger.log "Creating room id #{room.name}", :info, 'create_rooms'
          new_room = TriviaRoom::Room.new(room, @jclient)
          new_room.launch
          @rooms << new_room
          sleep(5)
      }
      return true
    end
    
    
    def send_signal_to_rooms
      roomlist = Room.all( :status => 'A')
      roomlist.each{ |room|
          if room.signal && !room.signal.empty?
            r = @rooms.detect{|r| r.bot == room.bot}
            if r
              signal = room.signal
              if signal == 'CONFIG'
                r.update_config(room)
              else
                r.send_signal(signal)
              end
              @logger.log "Sending signal '#{signal}' to room #{room.name}", :info, 'send_signals_to_rooms'
              room.signal = nil
              room.save
            end
          end
      }
    rescue Exception => e
      @logger.log "Exception while sending signal to room. #{e.message} - #{e.backtrace}", :error, 'send_signals_to_rooms'
    end
    
    
    def rooms
      @rooms
    end
    
    def status
      @logger.log "SERVER STATUS - #{@status} - Rooms:#{@rooms.count}".bold.yellow, :info, 'Status'
      @logger.log "SERVER STATUS - #{@status} - Rooms:#{@rooms.size}".bold.yellow, :info, 'Status'
      rooms.collect{|r|
                      @logger.log "#{r.name.white} -> #{r.info}", :info, 'Status'
                    }
    end
    
    
    def doloop #Main Loop
      @status = :running
      loop {
        status
        send_signal_to_rooms
        sleep(SECS_LOOP_STATUS)
        ObjectSpace.garbage_collect
      }
      
    end
    
  end # Server
  
end