#########################################################################################################
#                                           ROOM                                                        #
#########################################################################################################

#include ObjectSpace

module TriviaRoom

  class Room
    
    # Config constants
    WAIT_BEFORE_START_GAME = 30
    MIN_PLAYERS_TO_PLAY = 1
    
    # MUC_HOST = "rooms.raw.triviapad.com"
    # MULTICAST_HOST = "multicast.raw.triviapad.com"
    # PUBSUB_HOST = 'pubsub.raw.triviapad.com'
    # PUBSUB_NODE = "triviapad/rooms"
    
    def initialize(room, superjclient = nil)
      
      #ObjectSpace.define_finalizer(self, self.class.method(:finalize).to_proc)
      
      #Class Variables
      @status = :initialized # :initialized, :onhold, :ongame, :onpause, :onkill
      @status_on_end = nil
      @question = 0
      @current_question = {}
      
      update_config(room)
      
      #Class objects
      @logger = EventLogger.new("room-#{@slug}")
      @logger.enabled = true
      $logger = @logger
      
      @players = TriviaActors::Players.new
      @superjclient = superjclient
      @redis = Redis.new
      
    	connect_and_presence
    	create_muc_room
    	set_callbacks
      update_room_pubsub
    	
    end #Room initialize
    
    def finalize # Destructor
      @logger.log "This thread is being destroyed. Run for your life!!!", :info, 'Finalize'
      # Release PubSub for the Room
    end
    
    def bot
      @room.bot
    end
  
    def start
      @logger.log "This thread is being started.", :info, 'Start'
      @thread = Thread.new(@slug){main_loop}
      @status = :onhold
    end
  
    def stop
      @muc.send_chat("This Room is shutting down in 10 seconds...")
      @logger.log "This thread is being started.", :info, 'Start'
      sleep(10)
      #remove PubSub for this room
      #remove Room for this room
      #kill Thread
      @thread.destroy
      @status = :onpause
    end
  
    def send_signal(signal)
      case signal
      when 'PAUSE'
        @status_on_end = :onpause
      else #unrecognized Signal
      end
    end
    
    def update_config(room)
      @room = room
      @id = room.id
      @name = room.name
      @slug = room.slug
      @type = room.level
      @topic = room.topic
      @botjid = Jabber::JID::new(room.bot)
      @botjid.resource = 'Triviabot'
      @botpasswd = room.botpasswd
      @questions = room.questions_per_game
      @seconds = room.seconds_per_question
    end
    
    def connect_and_presence
      @jclient = Jabber::Client.new(@botjid)
      @logger.log "Connecting to server as #{@botjid}", :info, 'Initialize'
    	@jclient.connect
    	@jclient.auth(@botpasswd)
    	@logger.log "Authenticated as #{@jclient.jid}!", :info, 'Initialize'
    	@jclient.send(Jabber::Presence.new.set_type(:available))
    end
    
  
    def set_callbacks
      # MUC Callbacks
      @muc.add_message_callback do |msg|
        muc_message_callback(msg)
      end
    
      @muc.add_join_callback do |msg|
        muc_join_callback(msg)
      end

      @muc.add_leave_callback do |msg|
        muc_leave_callback(msg)
      end
    
      @muc.add_presence_callback do |presence| #Just debugging
        @logger.log "#{presence.from} > #{presence.inspect}", :debug, 'add_presence_callback'
      end
    
      @muc.add_private_message_callback do |msg|
        if !msg.body.nil?
          @logger.log "#{msg.from} > #{msg.body}", :debug, 'add_private_message_callback'
          autorespond = Message.new(msg.from, "Leave me alone! I'm a very busy bot")
          @jclient.send(autorespond)
        end
      end
      
      #stanza callbacks for room bot. Game logic here.
      
      @jclient.add_message_callback do |msg|
        case msg.type
        when :answer
          process_answer_from_player(msg)
        when :error
          @logger.log "Error message received from #{msg.from}: #{msg.body}", :error, "add_message_callback"
          @players.mark_as_unavailable(msg.from)
        end
      end
      
      
      @jclient.add_presence_callback do |presence|
        @logger.log "#{presence.from} > #{presence.inspect}", :debug, "add_presence_callback"
        if presence.type
          case presence.type.to_sym
          when :join
            @logger.log "Player requested join game -> #{presence.from}", :debug, "add_presence_callback"
            process_join_game_request(presence)
          end
        end
      end
    
      
      @jclient.add_iq_callback do |iq|
        begin
          @logger.log "IQ Callback -> #{iq.inspect}", :debug, "add_iq_callback"
          if iq.type == :get
            case iq.first_element("x").attribute("xmlns").value # requires securization
            when 'service:room:status' # room status request from client
              process_iq_status_request(iq)
            when 'service:game:lifeline'
              process_lifeline_request(iq)
            end
          end
        rescue Exception => e
          @logger.log "IQ Callback processing -> #{e.message}", :error, "add_iq_callback"
        end
      end
      
      @jclient.on_exception do |e, stream, context|
        @logger.log "Jabber Stream Exception :: #{!e.nil? ? e.message : "- no message -"} : #{context}", :warn, 'jclient_on_exception'
        if @status != :offline
          old_status = @status
          count = 2
          @status = :offline
          begin
            sleep(count ** 2)
            @logger.log "Connecting to server as #{@botjid}", :info, 'jclient_on_exception'
          	connect_and_presence
          	create_muc_room
          	set_callbacks
            update_room_pubsub
          	@status = old_status
          rescue
            @logger.log "Unable to reconnect. Retrying in 1 sec... ", :warn, 'jclient_on_exception'
            sleep(1)
            count += 1
          end until @status != :offline
        end
      end
      
      
    end
    
    
    
    ####### MAIN LOOP #########
    
    def main_loop
      begin #main loop
        #send_chat "Waiting for players to join game...'"
        @logger.log "Waiting for players to start game...", :info, "main_loop - begin"
        @status = :onhold
        #update_room_pubsub
        
        # puts Color.red("DUMPING ALL")
        # Memprof.dump_all("myapp_heap.json")
        
        begin #wait loop
          sleep(5)
          @logger.log "Still waiting for players to join game. Currently #{@players.count}", :info, "main_loop - wait loop"
          update_room_pubsub
          send_status_to_room
          #releasing objects
          ObjectSpace.garbage_collect
        end until (@players.count >= MIN_PLAYERS_TO_PLAY)
        
        #wait for more players to join
        @logger.log "Waiting for more players to join game. Starting in #{WAIT_BEFORE_START_GAME} secs...", :info, "main_loop - extra wait"
        @status = :onwait
        @wait = WAIT_BEFORE_START_GAME
        
        #notify_status_to_players #this might became deprecated when status_to_room working
        send_status_to_room
        
        begin #Wait extra before start loop
          sleep(1)
          @wait -= 1
        end until @wait <= 0
        
        @logger.log "Creating a new Game", :info, "main_loop - Create game"
        @status = :ongame
        @game = create_game
        
        @logger.log "Sending initial players list", :info, "main_loop - send players list"
        @players.accept_all_pending
        
        send_status_to_room
        update_room_pubsub
        send_multicast_message(@players.list_by_jid, build_game_rank)
        
        #game loop
        (1..@questions).each do |q| # Game loop
          begin
             @question = q #starts new question cycle
             @logger.log "Starting question ##{q}/#{@questions}", :info, "main_loop - Starting Question Loop"
             #send_chat "Starting question ##{q}/#{@questions}"
             
             @logger.log "Sending question to players ##{q}/#{@questions}", :info, "main_loop - Question Send"
             send_multicast_message(@players.list_by_jid, build_random_question) #sends question to players
             sleep(25)
             
             #Question timeout. Reveal right answer to players
             @logger.log "Revealing answer to players... ##{q}/#{@questions}", :info, "main_loop - Send Reveal"
             send_multicast_message(@players.list_by_jid, build_reveal) #sends reveal question to players
             @responses.status = :closed
             sleep(4)
             
             #process responses array and send question rank to players
             @logger.log "Sending question ranking to players... ##{q}/#{@questions}", :info, "main_loop - Send Question Ranking"
             send_multicast_message(@players.list_by_jid, build_question_rank) #sends question ranking to players
             sleep(4)
       
             #process question results and send game rank to players including just joined
             @players.accept_all_pending
             dump_question_scorings
             
             @logger.log "Sending game ranking to players... ##{q}/#{@questions}", :info, "main_loop - Send Game Ranking"
             send_multicast_message(@players.list_by_jid, build_game_rank) #sends game ranking to players
             sleep(2)
       
             send_status_to_room
             update_room_pubsub
             
             @logger.log "Room Info => #{self.info}", :info, "main_loop - Question loop done"
             #break if @status == :onkill #kind of unpolite
          rescue Exception => e
            @logger.log "Error on game loop while question ##{q}: #{e.message} - #{e.backtrace}", :error, "main_loop - game loop"
          end
          @logger.log "Pause between questions... ##{q}/#{@questions}", :info, "main_loop - game loop"
          sleep(5) #pause between questions
        end
        begin
          
          #finish game
          close_game
          store_game
          store_scores
          
          #restart room for a new game
          @question = 0
          update_room_pubsub
          #reset players after plublishing to PubSub
          @players.clear
          send_status_to_room
          
          @logger.log "Game finished", :info, "main_loop - Game finished"
          #send_chat "Game finished! Wait for a new game to start"
          
          #releasing objects
          ObjectSpace.garbage_collect
          
          if @status_on_end
            @status = @status_on_end
            @status_on_end = nil
            @logger.log "Status set to #{@status} through @status_on_end.", :info, "main_loop - @status_on_end"
          end
          
        rescue Exception => e
          @logger.log "Error on game loop finishing: #{e.message} - #{e.backtrace}", :error, "main_loop - loop done"
        end
      end until @status == :onpause #exit main loop and finish thread
        send_chat "This Room is going on maintenance for a while", :game, "main_loop - Game finished"
      @logger.log "Main loop finished. Room going on maintenance", :info, "main_loop - Game finished"
    end
    
    
    
    def name #Room name
      @name
    end
  
    def status
      @status
    end
    
    def waiting?
      @status == :onhold
    end
    
    def playing?
      @status == :ongame
    end
    
    def is_connected?
      @jclient.is_connected?
    end
  
    def info
      "Status: #{ @status == :onpause ? @status.to_s.upcase.red : @status.to_s.upcase.green } - Jabber: #{is_connected? ? is_connected?.to_s.green : is_connected?.to_s.red} - Players(All/Playing/Left): (#{@players.count}/#{@players.count_playing}/#{@players.count_left}) - Question: #{@question}/#{@questions}"
    end
    
  
    # CALLBACKS
  
    def muc_join_callback(msg)
      @logger.log "#{msg.from} joins #{@name}", :debug, "muc_join_callback"
      send_status_to_player(msg.from)
      #send_chat "Hi! #{msg.from.resource}, be welcome to #{@name} Trivia room"
    end
  
    def muc_leave_callback(msg)
      @players.leave_room(msg.from.resource)
      @logger.log "#{msg.from} leaves #{@name}", :debug, "muc_leave_callback"
      #send_chat "Bye, #{msg.from.resource}. Be back soon!"
    end
  
    def muc_message_callback(msg)
      @logger.log "#{msg.from.inspect}> #{msg.body}", :debug, "muc_message_callback"
      case msg.body
      when 'go!'
        #start
        @logger.log "Game started by #{msg.from}", :info, "muc_message_callback"
      when 'stop!'
        #stop
        @logger.log "Game Stopped by #{msg.from}", :info, "muc_message_callback"
      end
    rescue Exception => e
      @logger.log "#{e.message}", :error
    end

  
    private
    
      def send_chat(msg)
        @muc.send(Jabber::Message.new(@bot, msg))
      end

      def send_message(jid, msg)
        @jclient.send(Jabber::Message.new(jid, msg))
      end
    
      def send_multicast_message(list, mcmsg)
        mcmsg.receivers = list
        @jclient.send(mcmsg)
      end
      
      
      def add_status_element(stanza)
        attrb = {'status' => @status.to_s, 'question' => @question, 'total' => @questions, 'players' => @players.count }
        attrb.merge!('wait' => @wait) if @status == :onwait
        attrb.merge!('message' => @status_message) if @status_message
        stanza.add_element 'status', attrb
        return stanza
      end
      
      
      def notify_status_to_players # This message became deprecated because of send_status_to_room function
        statusmsg = Presence.new
        statusmsg.from = @jid
        statusmsg.id = "status-#{Time.now.usec}"
        statusmsg.type = :join
        statusmsg = add_status_element(statusmsg)
        
        @logger.log "About to send status message to pending players", :info, "notify_status_to_players"
        @players.each{ |p|
            statusmsg.to = p.jid
            @jclient.send(statusmsg)
          }
        
      rescue Exception => e
        @logger.log "Error while sending status message --> #{statusmsg.inspect} \n #{e.message} \n #{e.backtrace}", :error, "notify_status_to_players"
      end
      
      def update_room_pubsub
        #Create Pubsub item triviapad@rooms.dev.triviapad.com
      	pubsub = Jabber::PubSub::ServiceHelper.new(@superjclient, PUBSUB_HOST)

        item = Jabber::PubSub::Item.new
              item.add_attributes('jid' => "#{@slug}@#{MUC_HOST}")
              item.add_element('room', {'type' => ROOM_LEVEL_OPTIONS.find{|l| l[1] == @type}.first, 'name' => @name, 'jid' => @botjid, 'muc' => "#{@slug}@#{MUC_HOST}", 'topic' => @topic, 'questions' => @questions, 'question' => @question, 'players' => @players.count, 'slug' => @slug })

        pubsub.publish_item_with_id_to(PUBSUB_NODE, item, @slug)
      rescue Exception => e
        @logger.log "Error while publishing Item(#{@slug}) to PubSub on node -> #{PUBSUB_NODE}  -- #{e.message}  -- #{e.backtrace}", :error, "update_room_pubsub"
      else
        @logger.log "Item(#{@slug}) successfully published to PubSub on node -> #{PUBSUB_NODE}", :info, "update_room_pubsub"
      end
      

      def create_muc_room
        @logger.log "Creating MUC room #{@name} as #{@botjid}", :info, "create_muc_room"
      	@muc = Jabber::MUC::MUCClient.new(@jclient)
      	@muc_jid = "#{@slug}@#{MUC_HOST}/#{@botjid.node}"
      	@muc.join(Jabber::JID::new(@muc_jid))
      rescue
        @logger.log "Error while creating Room(#{@muc_jid})", :error, "create_muc_room"
      end
      
      def build_status_message
        stmsg = Jabber::Message.new
        #stmsg.from = @jid
        stmsg.id = "status-#{Time.now.to_i}"
        stmsg = add_status_element(stmsg)
      end
      
      def send_status_to_player(jid)
        stmsg = build_status_message
        stmsg.type = :status
        stmsg.to = jid
      	@jclient.send(stmsg)
      	@logger.log "Sent status to Player(#{jid})", :info, "send_status_to_player"
      rescue Exception => e
        @logger.log "Error while sending status to Player(#{jid}) --> #{e.message}", :error, "send_status_to_player"
      end
      
      def send_status_to_room
        stmsg = build_status_message
        stmsg.type = :groupchat
      	if @muc.active?
      	  @muc.send(stmsg) 
      	  @logger.log "Sent status to MUC Room(#{@name})", :info, "send_status_to_room"
      	else
      	  @logger.log "Skipping sending status to MUC Room(#{@name}) for being inactive", :warn, "send_status_to_room"
      	end
      rescue Exception => e
        @logger.log "Error while sending status to Room(#{@name}) --> #{e.message} -- #{e.backtrace}", :error, "send_status_to_room"
      end
      
      
      def dump_question_scorings
        #updating game scores
        @responses.all_sorted_and_scored.each {|r|
                                    p = @players.find_by_jid(r.jid)
                                    p.score += r.score
                                    p.score = 0 if p.score < 0 #CScore can't go negative
                                    p.hits_inc if r.ok?
                                    p.responses_inc
                                  }
        @players.sort_by_score
      rescue Exception => e
        @logger.log "Error while calculating question scores -> #{e.message}", :error, "dump_question_scorings"
      end
      
      
      
      ####### CALLBACKS REQUESTS ########
      
      def process_join_game_request(request)
        #pending verify player can join game here
        
        #adding player to queue
        @players.join_game(request.from)
        
        #store player's join (if exists)
        p = Player.find_by_jid(request.from.strip.to_s)
        if p
          p.joined!
          @logger.log "Storing player join (#{p.inspect})", :debug, "process_join_game_request"
        end
        
        #sending ok response
        response = Presence.new
        response.to = request.from
        response.from = request.to
        response.id = request.id
        response.type = :join
        response.add_element 'x', {'xmlns' => 'service:game'} # <x xmlns='service:game' />
        response = add_status_element(response)
        
        @jclient.send(response)
      rescue Exception => e
        @logger.log "Exception while joining player (#{request.from}) : #{e.message} -- #{e.backtrace}", :error, "process_join_game_request"
      else
        @logger.log "#{request.from} has joined the game", :debug, "process_join_game_request"
      end
      
      
      def process_iq_status_request(iq)
        response = Iq.new(iq.from)
        response.from = @botjid
        response.type = :result
        response.id = iq.id
        reponse.add_element 'room', {'question' => @question, 'players' => @players.count }
        @logger.log "response --> #{response.inspect}", :info, "THREAD #{@name}"
        @jclient.send(response)
      rescue Exception => e
        @logger.log "Exception while responding iq status (#{iq.from}) : #{e.message}", :error, "process_iq_status_request"
      else
        @logger.log "#{iq.from} status request has been served", :debug, "process_iq_status_request"
      end
      
      
      def process_answer_from_player(msg)
        answer_id = msg.first_element("answer").attribute("id").value.to_i
        answer_time = msg.first_element("answer").attribute("time").value.to_i
        #antifake time responses here. check id, check timestamp
        @responses.insert(TriviaActors::Response.new(msg.from, answer_id, answer_id == @current_question[:option_ok], answer_time))
      rescue Exception => e
        @logger.log "Exception while processing player answer (#{msg.from}) : #{e.message} -- #{e.backtrace}", :error, "process_answer_from_player"
      end
      
      
      def process_lifeline_request(iq)
        
        iqresponse = Jabber::Iq.new
        iqresponse.from = @botjid
        iqresponse.to = iq.from
        iqresponse.id = iq.id
        
        lifelinetype = iq.first_element("x").attribute("type").value.to_sym
        if lifelinetype
          p = @players.find_by_jid(iq.from)
          if p && p.fetch_lifeline?(lifelinetype)
            case lifelinetype
            when :fifty
              @logger.log "Lifeline Fifty accepted", :debug, "process_lifeline_request"
              response = inject_lifeline_fifty(iqresponse)
              response.type = :result
            when :clairvoyance
              @logger.log "Lifeline Clairvoyance acepted", :debug, "process_lifeline_request"
              response = inject_lifeline_clairvoyance(iqresponse)
              response.type = :result
            when :rollback
              @logger.log "Lifeline Rollback accepted", :debug, "process_lifeline_request"
              if @responses.find_by_jid(iq.from)
                @responses.delete_by_jid(iq.from)
                iqresponse.add_element 'lifeline', {'type' => 'rollback', 'status' => 'ok'}
                response = iqresponse
                response.type = :result
              else
                @logger.log "Lifeline invalid", :debug, "process_lifeline_request"
                response = inject_lifeline_error(iqresponse, 'Player answer not found')
                response.type = :error
              end
            end
          else
            @logger.log "Lifeline request rejected", :debug, "process_lifeline_request"
            response = inject_lifeline_error(iqresponse, 'Player not valid or out of lifelines')
            response.type = :error
          end
          @logger.log "Sending response --> #{response.inspect}", :debug, "process_lifeline_request"
          @jclient.send(response)
        end
      rescue Exception => e
        @logger.log "Exception while processing IQ lifeline (#{iq.from}) : #{e.message} - #{e.backtrace}", :error, "process_lifeline_request"
      else
        @logger.log "#{iq.from} status request has been delivered", :debug, "process_lifeline_request"
      end
      


      def build_random_question
        quest = @room.pool.get_random_question
        qmsg = Jabber::Message.new(MULTICAST_HOST)
        qmsg.type = :question
        qmsg.id = "question-#{@question}"
        qmsg.question = {:text => quest.question, :time => 20, :count => @question, :total => @questions }
        
        answers = []
        answers << quest.answer
        answers << quest.option1 if quest.option1.present?
        answers << quest.option2 if quest.option2.present?
        answers << quest.option3 if quest.option3.present?
        answers.shuffle!
        
        qmsg.answers = answers
        option_ok = answers.index(quest.answer) + 1 #shift array index
        begin
          option_wrong = rand(4) + 1
        end until ((!option_wrong.nil?) && (option_wrong != option_ok))
        
        #cheat for bot players to respond
        qmsg.add_element 'cheat', {'id' => option_ok}
        
        @current_question[:id] = "question-#{@question}"
        @current_question[:option_ok] = option_ok
        @current_question[:option_wrong] = option_wrong
        @current_question[:timestamp] = Time.now
        @current_question[:num_players] = @players.count
        @responses = TriviaActors::Responses.new(@players.count)
        @responses.status = :open
        @logger.log "question message built -> #{qmsg.inspect}", :info, "build_random_question"
        return qmsg
      rescue Exception => e
        @logger.log "error while building question message -> #{e.message} -> #{qmsg.inspect}", :error, "build_random_question"
      end
      
      
      def build_reveal
        revmsg = Jabber::Message.new(MULTICAST_HOST)
        revmsg.type = :reveal
        revmsg.id = "reveal-question-#{@question}"
        revmsg.add_element 'reveal', {'option' => @current_question[:option_ok] }
        return revmsg
      rescue Exception => e
        @logger.log "error while building reveal answer message -> #{e.message} --> #{e.backtrace}", :error, "build_reveal"
      end
      
      
      def build_question_rank
        qrmsg = Jabber::Message.new(MULTICAST_HOST)
        qrmsg.type = :ranking
        qrmsg.id = "ranking-question-#{@question}"
        ranking = qrmsg.add_element 'ranking', {'type' => 'question', 'count' => @question, 'total' => @questions }
        cont = 0
        @responses.all_sorted_and_scored.each{|r|
                                  cont += 1
                                  ranking.add_element 'player', {'pos' => cont, 'nickname' => r.nickname, 'time' => r.time, 'score' => r.score }
                                }
        return qrmsg
      rescue Exception => e
        @logger.log "error while building question ranking message --> #{e.message} --> #{e.backtrace}", :error, "build_question_rank"
      end

      def build_game_rank
        grmsg = Jabber::Message.new(MULTICAST_HOST)
        grmsg.type = :ranking
        grmsg.id = "ranking-game-#{@question}"
        grmsg.add_element 'status', {'question' => @question, 'total' => @questions, 'players' => @players.count}
        ranking = grmsg.add_element 'ranking', {'type' => 'game', 'count' => @question, 'total' => @questions }
        grmsg = add_status_element(grmsg)
        cont = 0
        @players.each{|p|
                        cont += 1
                        ranking.add_element 'player', {'pos' => cont, 'nickname' => p.nickname, 'score' => p.score }
                      }
        return grmsg
      rescue Exception => e
        @logger.log "Error while building game ranking message -> #{e.message} backtrace --> #{e.backtrace}", :error, "build_game_rank"
        return grmsg
      end
      
      # Lifelines injects
      
      def inject_lifeline_fifty(iqresponse)
        options = [ @current_question[:option_wrong], @current_question[:option_ok]]
        options.sort! # Sorted for shuffling purposes
        lifeline = iqresponse.add_element 'lifeline', {'type' => 'fifty', 'status' =>'ok'}
        question = lifeline.add_element 'question', {'id' => @current_question[:id]}
        options.each{|op|
                      question.add_element 'option', {'id' => op.to_s}
                    }
        return iqresponse
      end
      
      
      def inject_lifeline_clairvoyance(iqresponse)
        lifeline = iqresponse.add_element 'lifeline', {'type' => 'clairvoyance', 'status' =>'ok'}
        question = lifeline.add_element 'question', {'id' => @current_question[:id], 'responses' => @responses.count}
        @responses.collect_by_option.each{|k, v|
              question.add_element 'option', {'id' => k, 'count' => v}
            }
        return iqresponse
      end
      
      def inject_lifeline_error(iqresponse, message)
        iqresponse.type = :error
        iqresponse.add_element 'error', {'status' =>'error', 'message' => message}
        return iqresponse
      end
      
      
      
      ### PERSISTENCE ###
      
      def create_game
        game = Game.new
        game.room_id = @room.id
        game.counter = (@room.games.last ? @room.games.last.counter : 0).next
        game.time_start = Time.now
        if game.save
          @logger.log "Game object created with id -> #{game.id}", :info, "create_game"
          return game
        end
      rescue Exception => e
        @logger.log "Error while creating game object -> #{e.message} backtrace --> #{e.backtrace}", :error, "create_game"
      end

      def close_game
        game = Game.find(@game.id)
        game.time_end = Time.now
        game.players_max = @players.count
        game.winner_score = @players.first.score
        game.total_score = @players.sumarize_score
        game.save!
        @logger.log "Game object with id #{game.id} has been closed", :info, "close_game"
      rescue Exception => e
        @logger.log "Error while closing game object -> #{e.message} backtrace --> #{e.backtrace}", :error, "close_game"
      end

      # Redis
      def store_game
        game = Game.find(@game.id)
        redis = Redis.new
        @players.each{|p|
                        redis.zadd "game-#{@game.id.to_s}", p.score, p.nickname
                        redis.hmset "game-#{@game.id.to_s}:#{p.nickname}", 'hits', p.hits, 'responses', p.responses
                      }
        @logger.log "Game properly stored on 'game-#{@game.id.to_s}' key", :info, "store_game"
      rescue Exception => e
        @logger.log "Error while storing game -> #{e.message} backtrace --> #{e.backtrace}", :error, "store_game"
      end

      def store_scores
        @logger.log "Storing scores...", :info, "store_scores"
        game = Game.find(@game.id)
        year = game.time_start.strftime("%Y")
        month = game.time_start.strftime("%Y-%m")
        week = game.time_start.strftime("%Y-%U")
        day = game.time_start.strftime("%Y-%m-%d")
        
        raddress = "room-#{@room.slug}"
        redis = Redis.new
        @players.each{|p|
                        unless p.privilege == :guest
                          #All time
                          redis.zincrby "#{raddress}-alltime", p.score, p.nickname
                          redis.hincrby "#{raddress}-alltime:#{p.nickname}", 'hits', p.hits
                          redis.hincrby "#{raddress}-alltime:#{p.nickname}", 'responses', p.responses
                          redis.hincrby "#{raddress}-alltime:#{p.nickname}", 'gplayed', 1
                          #Yearly
                          redis.zincrby "#{raddress}-year:#{year}", p.score, p.nickname
                          redis.hincrby "#{raddress}-year:#{year}:#{p.nickname}", 'hits', p.hits
                          redis.hincrby "#{raddress}-year:#{year}:#{p.nickname}", 'responses', p.responses
                          redis.hincrby "#{raddress}-year:#{year}:#{p.nickname}", 'gplayed', 1
                          #Monthly
                          redis.zincrby "#{raddress}-month:#{month}", p.score, p.nickname
                          redis.hincrby "#{raddress}-month:#{month}:#{p.nickname}", 'hits', p.hits
                          redis.hincrby "#{raddress}-month:#{month}:#{p.nickname}", 'responses', p.responses
                          redis.hincrby "#{raddress}-month:#{month}:#{p.nickname}", 'gplayed', 1
                          #Weekly
                          redis.zincrby "#{raddress}-week:#{week}", p.score, p.nickname
                          redis.hincrby "#{raddress}-week:#{week}:#{p.nickname}", 'hits', p.hits
                          redis.hincrby "#{raddress}-week:#{week}:#{p.nickname}", 'responses', p.responses
                          redis.hincrby "#{raddress}-week:#{week}:#{p.nickname}", 'gplayed', 1
                          #Daily
                          redis.zincrby "#{raddress}-day:#{day}", p.score, p.nickname
                          redis.hincrby "#{raddress}-day:#{day}:#{p.nickname}", 'hits', p.hits
                          redis.hincrby "#{raddress}-day:#{day}:#{p.nickname}", 'responses', p.responses
                          redis.hincrby "#{raddress}-day:#{day}:#{p.nickname}", 'gplayed', 1
                        end
                      }
                      
        @logger.log "Stores properly stored in: #{raddress}", :info, "store_scores"
      rescue Exception => e
        @logger.log "Error while storing scores -> #{e.message}. backtrace --> #{e.backtrace}", :error, "store_scores"
      end
      
      
      
  end #Class Room

end # Module TriviaRoom

