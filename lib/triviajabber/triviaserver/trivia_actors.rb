module TriviaActors
  
  class Player
    
    attr_accessor :status, :score, :responses, :hits
    
    def initialize(jid)
      @jid = Jabber::JID.new(jid).strip
      @nickname = jid.node
      @score = @hits = @responses = 0
      @lifelines = {:fifty => 1, :clairvoyance => 1, :rollback => 1}
      if @jid.domain.include?('guest')
        @privilege = :guest
      else
        @privilege = :regular
      end
    rescue Exception => e
      $logger.log "EXCEPTION while initializing Player: #{e.message}", :error
    end
    
    def nickname
      @nickname
    end
    
    def jid
      @jid
    end
    
    def privilege
      @privilege
    end
    
    def responses_inc
      @responses += 1
    end
    
    def hits_inc
      @hits += 1
    end
    
    def fetch_lifeline?(type)
      if @lifelines[type] > 0
        @lifelines[type] -= 1
        return true
      else
        return false
      end
    end
    
  end
  

  class Players < Array
    
    def is_in?(player)
      !(self.detect{|p| p.jid == player.jid}).nil?
    rescue Exception => e
      $logger.log "EXCEPTION while looking up for Player: #{e.message}", :error
    end
    
    def find_by_jid(jid)
      strippedjid = Jabber::JID.new(jid).strip
      self.detect{|p| p.jid == strippedjid}
    end

    def find_by_nickname(nickname)
      self.detect{|p| p.nickname == nickname}
    end

    def join_game(jid)
      strippedjid = Jabber::JID.new(jid).strip
      player = self.find_by_jid(strippedjid)
      if player
        player.status = :pending
      else
        player = TriviaActors::Player.new(strippedjid)
        player.status = :pending
        self.push(player)
      end
      return true
    rescue Exception => e
      $logger.log "EXCEPTION while joining Player: #{e.message}", :error
    end
    
    def accept_all_pending
      self.select{|p| p.status == :pending }.each{|p| p.status = :ingame}
    end
    
    def leave_room(nickname)
      player = self.find_by_nickname(nickname)
      if player
        player.status = :left
        return true
      else
        return false
      end
      $logger.log "Player leaving room :: nickname -> #{nickname}", :debug, 'leave_room'
    rescue Exception => e
      $logger.log "EXCEPTION while Player leaving :: #{e.message} -- #{e.backtrace}", :error, 'leave_room'
    end
    
    def mark_as_unavailable(jid)
      player = self.find_by_jid(jid)
      if player
        player.status = :unavailable
        return true
      else
        return false
      end
      $logger.log "Player marked as unavailable :: jid -> #{jid}", :debug, 'mark_as_unavailable'
    rescue Exception => e
      $logger.log "EXCEPTION while marking player as unavaliable :: #{e.message} -- #{e.backtrace}", :error, 'mark_as_unavailable'
    end
  
    def list_by_jid
      #lists only players with status :ingame
      self.select{|p| p.status == :ingame }.map{|p| p.jid}
    rescue Exception => e
      $logger.log "EXCEPTION while listing players: #{e.message}", :error
    end
    
    def count_playing
      self.select{|p| p.status == :ingame }.count
    end
    
    def count_left
      self.select{|p| p.status == :left }.count
    end
    
    
    def sort_by_score
      self.sort!{|p1, p2| p2.score <=> p1.score}
    end
    
    def find(player)
      self.select{|p| p.jid == player.jid}
    end
    
    def sumarize_score
      sum = 0
      self.each{|p| sum += p.score}
      return sum
    end
    
  end #Player
  
  
  class Response
    
    attr_accessor :score
    
    def initialize(jid, option, ok, time)
      @jid = Jabber::JID.new(jid).strip
      @nickname = jid.node
      @option = option
      @ok = ok
      @time = time
    end
    
    def jid
      @jid
    end
    
    def nickname
      @nickname
    end
    
    def time
      @time
    end
    
    def ok?
      @ok
    end
    
    def option
      @option
    end
    
    def nickname
      @nickname
    end
    
  end
  
  
  class Responses
    
    attr_accessor :status
    
    def initialize(num_players)
      @num_players = num_players
      @status = :closed
      @right = []
      @wrong = []
    end
    
    def all
      @right + @wrong
    end
    
    def right_sorted_and_scored
      right_sorted = @right.sort_by{|r| r.time}
      right_sorted.each_index{|i|
        position = i + 1
        right_sorted[i].score = (@num_players / position.to_f).ceil
      }
      return right_sorted
    end
    
    def wrong_sorted_and_scored
      wrong_sorted = @wrong.sort_by{|r| r.time}
      wrong_sorted.each_index{|i|
        position = i + 1
        wrong_sorted[i].score = -((@num_players / position.to_f) / 2).ceil
      }
      return wrong_sorted
    end
    
    
    def all_sorted_and_scored
      right_sorted_and_scored + wrong_sorted_and_scored.reverse
    end
    
    def insert(response) #sorted insert
      
      strippedjid = Jabber::JID.new(response.jid).strip
      if find_by_jid(strippedjid).nil? #avoid duplicated responses
        if response.ok?
          @right << response
          #puts "DEBUG ::::::: response added"
          
          # Responses sorting and calculating moved to method sorted_and_scored
          #@right = @right.sort_by{|r| r.time}
          # moved to
          # position = @right.index{|r| r.jid == response.jid} + 1
          #           #puts "DEBUG ::::::: position -> #{position}"
          #           response.score = (@num_players / position.to_f).ceil
          #           #puts "DEBUG ::::::: score -> #{response.score}"
        else
          @wrong << response
          #puts "DEBUG ::::::: response added"
          # Responses sorting and calculating moved to method sorted_and_scored
          # @wrong = @wrong.sort_by{|r| r.time}
          #           position = @wrong.index{|r| r.jid == response.jid} + 1
          #           #puts "DEBUG ::::::: position -> #{position}"
          #           response.score = -((@num_players / position.to_f) / 2).ceil
          #           #puts "DEBUG ::::::: score -> #{response.score}"
        end
      # puts "DEBUG ::::::: WRONG -> #{@wrong.inspect}"
      # puts "DEBUG ::::::: LIST ALL -> #{self.all.inspect}"
      else
        $logger.log "DUPLICATED RESPONSE!", :warning, "Responses.insert"
      end
    end
    
    
    def find_by_jid(jid)
      strippedjid = Jabber::JID.new(jid).strip
      found = all.detect{|r| r.jid == strippedjid}
      return found
    end
    
    def delete_by_jid(jid)
      strippedjid = Jabber::JID.new(jid).strip
      itemind = @right.index{|r| r.jid == strippedjid}
      if !itemind.nil?
        @right.delete_at(itemind)
      else
        itemind = @wrong.index{|r| r.jid == strippedjid}
        if !itemind.nil?
          @wrong.delete_at(itemind)
        end
      end
      return !itemind.nil?
    end
    
    def list_righ
      @right
    end
    
    def count
      all.size
    end
    
    def list_sorted_by_score
      all.sort_by{|r| r.score}
    end
    
    def collect_by_option
      answerscont = {1 => 0, 2 => 0, 3 => 0, 4 => 0}
      all.each{|a| answerscont[a.option] += 1 }
      return answerscont
    end
    
    def flush
      @right.clear
      @wrong.clear
    end
    
  end
  
end