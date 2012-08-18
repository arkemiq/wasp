require 'aws-sdk'
require 'net/ssh'
require 'net/scp'

require File.dirname(__FILE__) + '/ec2'
  
module WASP
  class Wasp
    attr_reader   :ec2
    attr_reader   :num_wasps
    attr_reader   :weapon_name
    attr_reader   :weapon
    attr_reader   :report
    
    LINE_LENGTH = 80
  
    def initialize(args)
      @num_wasps = if args[:server].nil? then WASP::Const::DEFAULT_WASPS
                  else
                    args[:server].to_i
                  end
                  
      @weapon_name = if args[:weapon].nil? then WASP::Const::DEFAULT_WASPS
                else
                  args[:weapon]
                end
      
      @header = args[:header]
                
      @report  = if args[:report].nil? then false
                 else 
                   true
                 end
                 
      @keepalive = if args[:keepalive].nil? then false
                   else
                     true
                   end
      @without_cookie = if args[:wo_cookie].nil? then false
                        else
                          true
                        end
      @compact = if args[:compact].nil? then false
           else
             true
           end
      
      @ec2 = WASP::Aws.new(args)
      @params = []
      
    end
    
    def ready
      @ec2.get_keypair
      @ec2.get_security_group
    end

    def breed
      if @ec2.create == false then
        puts "[Error]".red + " Breeding wasps failed"
        exit false
      end
    end

    def down
      puts "Calling off the wasp."
      @ec2.terminate
    end
    
    def attack(num, conn, url, time=nil)
      wasps = assemble_wasps
      maximum = wasps.count * WASP::Const::DEFAULT_MAXIMUM_STINGS  
      if conn > maximum then
        print "[WARN]".yellow + " concurrent attack exceeded maximum number of wasps.\n" 
        print "Currently maximum number of concurrent attack is " + "#{maximum}".green + ".\n"
        print "Please breed more wasps.\n"
        exit false
      end
      
      urls = url.split(';')
      
      puts "Organizing the wasp."
      
      stingless_wasps = _attack(wasps, num, conn, urls, time)
      
      print "Offensive complete.\n\n"
      
      retrive_report(stingless_wasps) if @report
      
      mission_report(stingless_wasps)
      
      puts "The wasp is awaiting new orders."
    end
    
    def rangeattack(to, time, url, keep=false)
      wasps = assemble_wasps
      maximum = wasps.count * WASP::Const::DEFAULT_MAXIMUM_STINGS  
      if to > maximum then
        print "[WARN]".yellow + " concurrent attack exceeded maximum number of wasps.\n" 
        print "Currently maximum number of attack is " + "#{maximum}".green + ".\n"
        print "Please breed more wasps.\n"
        exit false
      end
      
      urls = url.split(';')
      
      stingless_wasps, waves = _rangeattack(wasps, to, time, urls, keep)
      print "Waves are finished.\n\n"
      
      #retrive_report(stingless_wasps, true)
      
      #wave_report(stingless_wasps, waves)
      
      puts "The wasp is awaiting new orders."
    end

    def assemble_wasps
      puts "Assemling wasps."
      wasps = @ec2.get_wasps
      wasps
    end
    
    def __wave_report(stingless_wasps)
      puts "Wasps report:"
      stingless_wasps.each do |wasp|
        next if wasp[:wavereport].count == 0
        
        puts "Wasp " + "#{wasp[:instance_id]}".yellow + " report:\n"
        wasp[:wavereport].each do |w|
          puts w
        end
        print "\n"
      end      
    end

    def partial_report(stingless_wasps, wave)
      @weapon = get_weapon
      wavereport = []

      print "#{wave} ".yellow + "wave report:\n"
      stingless_wasps.each do |wasp|
        report = wasp[:wavereport]
        next if report.nil?
        case
        when report.match(/currently not installed/) then
          print "[WARN]".yellow + " Some of wasps has no weapon to attack.\n"

        when report.match(/Unknown error/) then
          print "[WARN]".yellow + " Some of wasps lost sight of the target.\n"

        when report.match(/Requests per second/) then
          wavereport.push @weapon.points(report)

        else 
          print "[WARN]".yellow + " In wave " + "#{wave}".yellow + " Some of wasps lost completely.\n"
          print "[LOG]\n"
          print "#{report}\n"
        end        
      end

      if wavereport.count < 1 then
          print "This wave has no report. Target is " + "unavailable".red + ".\n\n"
      else
        if @compact then
          @weapon.compact_summary(wavereport)
        else
          @weapon.summary(wavereport)
        end
      end

    end
    
    def wave_report(stingless_wasps, waves)
      wavereport = {}
      i = 1
      while i <= waves do
        wavereport[i.to_s] = []
        i += 1
      end
      
      @weapon = get_weapon
      
      puts "Wave report:"
      
      stingless_wasps.each do |wasp|
        next if wasp[:wavereport].nil?
        wave = 1
        wasp[:wavereport].each do |report|
          case
          when report.match(/currently not installed/) then
            print "[WARN]".yellow + " Some of wasps has no weapon to attack.\n"

          when report.match(/Unknown error/) then
            print "[WARN]".yellow + " Some of wasps lost sight of the target.\n"

          when report.match(/Requests per second/) then
            wavereport[wave.to_s].push(@weapon.points(report))        

          else 
            print "[WARN]".yellow + " In wave " + "#{wave}".yellow + " Some of wasps lost completely.\n"
            print "[LOG]\n"
            print "#{report}\n"
          end
          wave += 1
        end
      end        
      
      wavereport.keys.each do |report|
        print "#{report} ".yellow + "wave report:\n"
        if wavereport[report].count < 1 then
          print "This wave has no report. Target is " + "unavailable".red + ".\n\n"
        else
          if @compact then
            @weapon.compact_summary(wavereport[report])
          else
            @weapon.summary(wavereport[report])
          end
        end
      end
    end
    
    def mission_report(stingless_wasps)
      report = []
      @weapon = get_weapon

      puts "Wasps report:"
      stingless_wasps.each do |wasp|
        next if wasp[:rawreport].nil?
        
        case
        when wasp[:rawreport].match(/currently not installed/) then
          print "[WARN]".yellow + " Some of wasps has no weapon to attack.\n"
        
        when wasp[:rawreport].match(/Unknown error/) then
          print "[WARN]".yellow + " Some of wasps lost sight of the target.\n"
          
        when wasp[:rawreport].match(/Requests per second/) then
          report.push(@weapon.points(wasp[:rawreport]))        
          
        else 
          print "[WARN]".yellow + " Some of wasps lost completely.\n"
        end
      end
      
      if report.empty? then
        print "Nothing to report.\n\n"
      else
        @weapon.summary(report)
      end
    end
    
    def status
      wasps = @ec2.status
       
      count = 0
      if wasps.nil? == false then     
        wasps.each do |zone, info| 
          puts "Zone " + "#{zone}".green + ":"     
          threads = []
          info[:instances].each do |ins|
            threads << Thread.new(ins) { |i|
              if @ec2.get_wasp_status(zone, i) == :running then
                dns = @ec2.get_wasp_domain(zone, i)
                print "Wasp " + "#{i}".yellow + " is ready to serve. (#{dns})\n"
                count += 1
              else
                print "Wasp " + "#{i}".red + " is hanging around somewhere.\n"
              end
            }
          end
          threads.each { |aThread| aThread.join }
        end
        print "\n#{count}".green + " Wasps are ready to serve.\n"
      end    
    end
    
    def airfield
      air = @ec2.get_regions
      print "Available airfield:\n"
      if not air.empty? then
        air.each do |a|
          print "#{a}".yellow  + "\n"
        end
      else
        print "No airfield is available."
      end
    end
    
    def get_weapon
      case
      when @weapon_name == 'ab' then
        WASP::WeaponAB.new
      else
        WASP::WeaponAB.new
      end
    end
    
    def equip
      wasps = assemble_wasps
      threads = []
      print "Wasps are checking its weapon..(This will just take a minute) "
      wasps.each do |b|
        threads << Thread.new(b) { |wasp|          
          begin
            Net::SSH.start(wasp[:instance_name], wasp[:login], 
                           :keys => ENV['HOME'] + '/.ssh/' + wasp[:key_name] + '.pem', 
                           :verbose => :fatal) do |ssh|
              weapon = get_weapon
              weapon.reload if not weapon.check(ssh)
            end
          rescue => ex
            print "[WARN]".yellow + " #{ex.message}\n"
          end    
        }
      end
      
      threads.each { |aThread| aThread.join }
      puts "OK".green
    end
    
    def _rangeattack(wasps, to, time, urls, keep=false)
      count = time / WASP::Const::DEFAULT_WAVE_TIME
      awave = to / count
      wasp_count = wasps.count
      increase = awave / wasp_count
      
      coopwasps = []
      sum = increase
      
      count.times do 
        coopwasps.push(sum)
        sum += increase
      end
         
      print "Get communication channel for wasps..\n"
      threads = []
      wasps.each do |b|
        threads << Thread.new(b) { |wasp|
          begin
            wasp[:ssh] = Net::SSH.start(wasp[:instance_name], wasp[:login], 
                         :keys => ENV['HOME'] + '/.ssh/' + wasp[:key_name] + '.pem')
            print "Wasp " + "#{wasp[:instance_id]}".yellow + " is joining the wasp.\n"                       
          rescue => ex
            puts "[Error] ".red + "#{ex.message}"
            puts "Cannot reach to " + "#{wasp[:instance_id]}".yellow
          end
        }
      end      
      threads.each { |aThread| aThread.join }

      wave = 1
      if keep then
        per_wave = to
      else
        per_wave = awave
      end
      print "Total " + "#{count}".green + " waves(per *#{per_wave}/#{WASP::Const::DEFAULT_WAVE_TIME}secs) are coming..\n"
      while wave <= count do
        if keep then
          swarm = to
        else
          swarm = awave * wave
        end
        puts "#{wave}".yellow + " wave of swarm is coming (" + "#{swarm}".yellow + " wasps).."
        threads = []
        i = 0
        wasps.each do |b|
          url = urls[i%urls.count]
          i += 1
          #puts "Attack the target : #{url}"
          threads << Thread.new(b) { |wasp|
            begin                                    
  			      weapon = get_weapon
  		        if weapon.check(wasp[:ssh]) then     
  		          if keep then
  		            coop = to / wasp_count
		            else
		              coop = coopwasps[wave-1]
	              end
                wasp[:wavereport] = weapon.wavefire(coop, url, wasp[:instance_id], wave, @keepalive, @without_cookie, @header)
              else
                puts "Wasp " + "#{wasp[:instance_id]}".yellow + " has no weapon."
              end
            rescue => ex
              print "[WARN]".yellow + " #{ex.message}.\n"
            end
          }
        end
        threads.each { |aThread| aThread.join }

        partial_report(wasps, wave)

        wave += 1
        if wave <= count then
          print "Waiting " + "#{WASP::Const::DEFAULT_COOLDOWN}".yellow + " seconds for cooling down\n"
          sleep WASP::Const::DEFAULT_COOLDOWN
        else
          cool = WASP::Const::DEFAULT_COOLDOWN / 5
          print "Waiting " + "#{cool}".yellow + " seconds for cooling down\n"
          sleep cool
        end
      end
      
      wasps.each do |wasp|
        begin
          wasp[:ssh].close
        rescue => ex
          puts "[WARN]".yellow + "#{ex.message}"
        end
      end
  
      return wasps, count
    end
    
    def _attack (wasps, num, conn, urls, time=nil)
      coop = conn / wasps.count
      num = num / wasps.count if not num.nil?
      
      print "Get communication channel for wasps..\n"
      threads = []
      wasps.each do |b|
        threads << Thread.new(b) { |wasp|
          begin
            wasp[:ssh] = Net::SSH.start(wasp[:instance_name], wasp[:login], 
                         :keys => ENV['HOME'] + '/.ssh/' + wasp[:key_name] + '.pem')
            print "Wasp " + "#{wasp[:instance_id]}".yellow + " is joining the wasp.\n"                       
          rescue => ex
            puts "[Error] ".red + "#{ex.message}"
            puts "Cannot reach to " + "#{wasp[:instance_id]}".yellow
          end
        }
      end      
      threads.each { |aThread| aThread.join }
      
      threads = []
      i = 0
      wasps.each do |b|
        url = urls[i%urls.count]
        i += 1
        threads << Thread.new(b) { |wasp|
          begin
		        weapon = get_weapon
		        if weapon.check(wasp[:ssh]) then 
		          print "Wasp " + "#{wasp[:instance_id]}".yellow + " is firing its stings. Ping ping!\n"
		          
              wasp[:rawreport] = weapon.fire(num, coop, url, wasp[:instance_id], @report, @keepalive, @without_cookie, time, @header) 
              
              print "Wasp " + "#{wasp[:instance_id]}".yellow + " is out of ammo.\n"
            else
              print "Wasp " + "#{wasp[:instance_id]}".yellow + " has no weapon.\n"
            end
          rescue => ex
            print "[WARN]".yellow + " #{ex.message}.\n"
          end
        }
      end
      
      threads.each { |aThread| aThread.join }
      
      wasps.each do |wasp|
        begin
          wasp[:ssh].close
        rescue => ex
          puts "[WARN]".yellow + "#{ex.message}"
        end
      end
      
      wasps
    end
    
    def retrive_report (wasps, iswave=false)
      threads = []
      
      print "Retrieve report from wasps.."
      wasps.each do |b|
        threads << Thread.new(b) { |wasp|
          if not iswave then
            remotepath = "#{wasp[:instance_id]}.zip"
            localpath = File.dirname(__FILE__) + "/../../report/#{wasp[:instance_id]}.zip"
          else
            remotepath = "#{wasp[:instance_id]}-wave.tar.gz"
            localpath = File.dirname(__FILE__) + "/../../report/#{wasp[:instance_id]}-wave.tar.gz"
          end
          
          begin
            Net::SSH.start(wasp[:instance_name], wasp[:login], 
                           :keys => ENV['HOME'] + '/.ssh/' + wasp[:key_name] + '.pem', 
                           :verbose => :fatal) do |ssh|
              ssh.scp.download! remotepath, localpath
            end
          rescue => ex
            print "[WARN]".yellow + " #{ex.message}.\n"
          end
        }
      end
      
      threads.each { |aThread| aThread.join }
      begin
        if not iswave then
          report_files = File.dirname(__FILE__) + "/../../report/*.zip"          
        else
          report_files = File.dirname(__FILE__) + "/../../report/*.tar.gz"
        end
        now = DateTime.now.to_s
        now_dir = File.dirname(__FILE__) + "/../../report/" + now
        Dir.mkdir(now_dir)
        FileUtils.mv(Dir.glob(report_files), now_dir)
      rescue => ex
        print "[WARN]".yellow + " #{ex.message}\n"
      end
      puts "OK".green
    end
  end
end
