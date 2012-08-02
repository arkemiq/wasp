require 'optparse'
require File.dirname(__FILE__) + '/wasp'

module WASP

  class Nest
    attr_reader   :key
    attr_reader   :options
    attr_reader   :args
    attr_reader   :wasps
    attr_reader   :queenwasp
    attr_reader   :optionhelp
  
    def info
      puts "be aware of me"
    end
  
    def parse_options!

      opts_parser = OptionParser.new do |opts|
        opts.banner = "\nAvailable options:\n\n"
          
        opts.on('-k', '--key PRIVATE-KEY', 
        'The ssh key pair name to use to connect to the new servers.') do |key| 
           @options[:key] = key 
         end
        opts.on('-s', '--servers NUM-SERVERS', 
        'The number of servers to start (default: 5).') do |server|
          @options[:server] = server 
        end
        opts.on('-g', '--group SECURITY-GROUP', 
        'The security group to run the instances under (default: default).') do |group|  
          @options[:group] = group 
        end
        opts.on('-z', '--zone AVAILABILITY-ZONE',
        "The availability zone to start the instances in (default: us-east-1).") do |zone|   
          @options[:zone] = zone 
        end
        opts.on('-a', '--ami AMI', 
        "The ami-id to use for each server from (default: ami-bfb473d6).") do |ami|
          @options[:ami] = ami
        end
        opts.on('-u', '--url URL', 'URL of the target to attack.') do |url|
          @options[:url] = url
        end
        opts.on('-p', '--pattern PATTERN', 
        'The pattern of concurrent wasps are growing and time (default: 5000(wasps):60(secs)).') do |pattern|
          @options[:pattern] = pattern 
        end
        opts.on('-t', '--time TIME', 
        'The time to make to the target (seconds).') do |time|
          @options[:time] = time
        end        
        opts.on('-i', '--cookie', 
        'The request doesn\'t include a cookie which have fake session id. (default: with sessionID).') do
          @options[:wo_cookie] = true
        end                
        opts.on('-H', '--header HEADER', 
        'Append extra headers to the request. (i.e.: "Accep-Encoding: zip/zop;8bit").') do |header|
          @options[:header] = header
        end
        opts.on('-n', '--numreq NUM-REQUEST', 
        'The number of total connections to make to the target (default: 1000).') do |num|
          @options[:num] = num 
        end
        opts.on('-c', '--concurrent CONCURRENT',
        'The number of concurrent connections to make to the target (default: 100).') do |conn|
          @options[:conn] = conn
        end
        opts.on('-l', '--login LOGINID',
        'The ssh username name to use to connect to the new servers (default: ubuntu).') do |login|
          @options[:login] = login
        end
        opts.on('-w', '--weapon WEAPON',
        'The name of weapon to attack (default: ab).') do |weapon|
          @options[:weapon] = weapon
        end
        opts.on('-e', '--keepalive', 'Use keep-alive option for weapon.') do
          @options[:keepalive] = true
        end        
        opts.on('-o', '--compact', 'Use compact version of results.') do
          @options[:compact] = true
        end
     
        opts.on('-v', '--version')                { puts "wasp " + "#{WASP::Const::VERSION}\n".green; exit(true) }
        opts.on('-h', '--help')                   { @optionhelp = true; help }
    
        opts.on_tail('--options')                 { puts "#{opts}\n" }
      end

      begin
        @args = opts_parser.parse!(@args)
      rescue => ex
        print "[WARN]".yellow + " #{ex.message}\n"
        @optionhelp = true
        help
      end
      self
    end
  
    def command_usage
      puts "Usage:".green + " wasps COMMAND [options]"
    <<-USAGE
    
  Wasps with Rain of Stings (ruby version of waspswithmachineguns)

  A utility for arming (creating) many wasps (small EC2 instances) to attack
  (load test) targets (web applications).

  commands:
    set       Set credential file for AWS. 
    up        Start a batch of load testing servers.
    equip     Check and install weapon to wasps.
    attack    Begin the attack on a specific url.
    rattack   Begin the attack incrementally growing up wasps during the period.
    down      Shutdown and deactivate the load testing servers.
    status    Report the status of the load testing servers.
    regions   Get AWS regions for the wasps.
    help      Show options.
    
 To set config file:
  $ wasp set aws.yml
    
 To launch 6 wasps:
  - launch 6 instances in us-east zone with private key named wasps
  $ wasp up -k wasps -s 6 
  
  - launch 5 instances in us-west-2 zone with ami-8cb33ebc AMI, username ubuntu and private key named wasps
  $ wasp up -k wasps -z us-west-2 -a ami-8cb33ebc -s 5 -l ubuntu
 
 To equip weapon(apachebench):
  $ wasp equip -w ab
 
 To attack target with 1000 requests and 100 concurrent wasps:
  $ wasp attack -n 1000 -c 100 -u http://target_site
  
 To attack target with incrementally increase wasps from 1 to 10000 during 60 seconds:
  $ wasp rattack -p 10000:60 -u http://target_site  
  
 To sleep wasps:
  $ wasp down
    
  USAGE
  
    end
    
    def lost_wasps
      File.exists?("#{ENV["HOME"]}/.nest")
      false
    end
  
    def parse_command!
      verb = @args.shift
      case verb
    
      when 'set'
        file = @args.shift
        
        help('nofile') if file.nil?
        
        file = File.absolute_path(file)
        
        begin
          FileUtils.cp(file, ENV["HOME"] + "/.waspaws.yml")
        rescue => ex
          puts "#{ex.message}"
          exit false
        end
        puts "AWS credential is set."
      
      when 'up'   
        if lost_wasps then
          puts "[WARN]".yellow + " There are lost wasps in the air. They need to go home first. [./nest down]"
          exit(false)
        end
      
        
        if @options[:key].nil? then 
          help("nokey")
        end
      
        puts 'Breeding wasps..'
        
        @wasps = WASP::Wasp.new(@options)
        @wasps.ready
        @wasps.breed
            
        #puts 'Breeding queen wasp..'
        #@queenwasp = WASP::QueenWasp.new(num_wasps)
        
      when 'equip'
        puts "Check wasps weapon.."
        
        @wasps = WASP::Wasp.new(@options)
        @wasps.equip
      
      when 'rattack'        
        puts "Connecting to the nest"
        
        if @options[:url].nil? then
          help("nourl")
        end
        
        if @options[:pattern].nil? then
          @options[:pattern] = "5000:60"
        end
        
        pattern = @options[:pattern]
        to, time, keep = pattern.split(":")
        
        help if time.nil? or to.nil?

        if keep == 'keep' then
          keep = true 
        else
          keep = false
        end
        @wasps = WASP::Wasp.new(@options)   
        @wasps.rangeattack(to.to_i, time.to_i, @options[:url], keep)
        
      when 'attack'
        puts "Connecting to the nest"
        
        if @options[:url].nil? then
          help("nourl")
        end
                
        num = if @options[:num].nil? then
                WASP::Const::DEFAULT_NUMBER_OF_REQUESTS
              else
                @options[:num].to_i
              end
        
        time = @options[:time]
                
        # number of requests would be ignored if time parameter have given
        num = nil if not time.nil?
              
        conn = if @options[:conn].nil? then
                WASP::Const::DEFAULT_CONCURRENT_OF_CONNECTIONS
              else
                @options[:conn].to_i
              end
              
        @wasps = WASP::Wasp.new(@options)   
        @wasps.attack(num, conn, @options[:url], time)
      
      
      when 'down'
        puts "Connecting to the nest."
        @wasps = WASP::Wasp.new(@options)
        @wasps.down
      
      when 'status'
        puts 'Report the wasp..'
        @wasps = WASP::Wasp.new(@options)
        @wasps.status
        
      when 'regions'
        puts 'Searching airfield..'
        @wasps = WASP::Wasp.new(@options)
        @wasps.airfield
    
      when 'help'
        @optionhelp = true
        help
      else
        help
      end
    end
  
  def help (errcode = nil)
    case errcode
    
    when 'nokey'
      puts "[Error]".red + " : AWS private key is required.\n";
      
    when 'nourl'
      puts "[Error]".red + " : Target url is required.\n";
    
    when 'nofile'
      puts "[Error]".red + " : Config file not found.\n";
      
    end
      puts command_usage
      if @optionhelp then
        @args = @args.unshift('--options')
        parse_options!
      end
      exit(true)
    end
  
    def cleanup
      puts "Clean up.."
      exit(true)
    end
  
    def wakeup
      trap('TERM') { print '\nTerminated\n'; exit(false)}
    
      parse_options!
      
      WASP::Config.output ||= STDOUT
      
      parse_command!
    end
  
    def initialize(args)
      @args = args
      @options = { :colorize => true }
      @wasps = []
      @queenwasp = nil
      @optionhelp = false
    end
    
    def self.wakeup(args)
      new(args).wakeup
    end
  end
  
end