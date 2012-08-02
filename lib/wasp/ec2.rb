require 'aws-sdk'

module WASP
  class Aws
    attr_reader   :config_path
    attr_reader   :ec2
    attr_reader   :group
    attr_reader   :key
    attr_reader   :instances
    attr_reader   :regions
    attr_reader   :instance_list
    attr_reader   :threads
    attr_reader   :login
  
    SLEEP_TIME = 1
    LINE_LENGTH = 100
  
    def initialize (args)
      config_path = ENV["HOME"] + "/.waspaws.yml"
      begin
        AWS.config(YAML.load(File.read(config_path)))
        @ec2 = AWS::EC2.new
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
        puts "[WARN]".yellow + " Please set AWS credential file."
        exit false
      end
      
      # evaluate AWS access_key and secret_access_key
      begin
        print "EC2".green + " Checking access key validation.."
        @ec2.availability_zones.each do |av| 
          av.name 
        end
        puts " OK".green
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
        puts "[WARN]".yellow + " Please copy/paste correct AWS access_key and secret_access_key to config/aws.yml file"
        exit false
      end
      
      @num_wasps = if args[:server].nil? then WASP::Const::DEFAULT_WASPS
                  else
                    args[:server].to_i
                  end
      @group = if args[:group].nil? then WASP::Const::DEFAULT_GROUP
               else
                 args[:group]
               end
      @zone = if args[:zone].nil? then WASP::Const::DEFAULT_ZONE
              else
                args[:zone]
              end              
      @ami = if args[:ami].nil? then get_default_ami(@zone)
             else
               args[:ami]
             end
      @login = if args[:login].nil? then WASP::Const::DEFAULT_USER
               else
                 args[:login]
               end     
      
      @key = args[:key]
      
      
      @regions = @ec2.regions
      @instance_list = []
      @instances = nil
    end
    
    def get_keypair 
      make_key = true
      key = @regions[@zone].key_pairs.filter('key-name', @key + '-' + @zone).first
      
      if key.nil? == false then
        if not File.exists?("#{ENV['HOME']}/.ssh/#{@key}-#{@zone}.pem") then
          key.delete 
          make_key = true
        else
          make_key = false
        end
      end
                  
      if make_key then
        key = @regions[@zone].key_pairs.create(@key + '-' + @zone)
        keyfile = "#{ENV['HOME']}/.ssh/#{@key}-#{@zone}.pem"
        begin
          File.delete(keyfile) if File.exists?(keyfile)
          File.open(keyfile, "w") do |f|
            f.write(key.private_key)
          end
          File.chmod(0400, keyfile)
        rescue => ex
          print "[WARN]".yellow + " #{ex.message}"
          exit false
        end
      end

      puts "EC2".green + " Private key is created in " + "~/.ssh/#{@key}-#{@zone}.pem".bold
    end
    
    def get_security_group
      found = false
      puts "EC2".green + " Look up existed security group [" + "#{@group}".bold + "].."
      security_groups = @regions[@zone].security_groups
      
      found = true if security_groups.filter('group-name', @group).first != nil
      
      if not found then
        puts "EC2".green + " Creating security group " + "#{@group}".bold + ".."
        wasps = security_groups.create(@group)
        puts "EC2".green + " Open inbound tcp port :#{WASP::Const::SSH_PORT}"
        wasps.authorize_ingress(:tcp, WASP::Const::SSH_PORT)
        puts "EC2".green + " Open inbound tcp port :#{WASP::Const::NATS_PORT}"
        wasps.authorize_ingress(:tcp, WASP::Const::NATS_PORT)
        puts "EC2".green + " Allow ping"
        wasps.allow_ping
      end
      
      puts "EC2".green + " Security group [#{@group}] have set.."
    end
    
    def waiting_wasp (i)
      banner = "EC2".green + " Launching wasps: "
      
      display banner, false      
      while i.status == :pending do
        print '.'
        sleep SLEEP_TIME
      end
    
      if i.status == :running then
        clear(LINE_LENGTH)
        display "#{banner}#{'OK'.green}"
        @instance_list.push(i.id)
        puts "Wasp " + "#{i.id}".yellow + " is ready to attack"
        i.tags.Name = 'a wasp!'
      else
        puts "EC2".green + " #{i.id} is going to wrong place"
      end
    end
  
    def create 
      puts "EC2".green + " #{@num_wasps} wasps will be launched.."
      
      begin
        @instances = @ec2.regions[@zone].instances.create(:image_id=>@ami,
                                              :security_groups=>[@group],
                                              :key_name=>@key + '-' + @zone,
                                              :instance_type=>'t1.micro',
                                              :count=>@num_wasps)                                      
        num_wasps = 0
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
        return false
      end
      if @instances.class == Array then
        @instances.each do |i|
          waiting_wasp(i)
        end
        num_wasps = @instances.count
      else
        waiting_wasp(@instances)
        num_wasps = 1
      end
      
      _write_to_file
    
      puts "The swarm has assembled " + "#{num_wasps}".yellow + " wasps.\n"
      true
    end
    
    def _get_instances
      status_of_wasps = {}
      if @instance_list.count == 0 then
        begin
          File.open("#{ENV["HOME"]}/.nest", "r") do |file|
            lines = file.readlines
            lines.each do |line|
              instance, key, zone, login = line.split(' ')
              
              if status_of_wasps[zone].nil? then
                status_of_wasps[zone] = {}
                status_of_wasps[zone][:instances] = []
                status_of_wasps[zone][:instances].push(instance)
                status_of_wasps[zone][:login] = login
              else
                status_of_wasps[zone][:instances].push(instance)
              end
            end
          end
        rescue => ex
          puts "There is no wasps in the air."
          
          return nil
        end
      end

      return status_of_wasps
    end
    
    def _write_to_file
      begin
        File.open("#{ENV["HOME"]}/.nest", "a+") do |file|
          if @instances.class == Array then
            @instances.each do |i|
              file.puts("#{i.id} #{i.key_name} #{i.availability_zone} #{@login}\n")
            end
          else
            file.puts("#{@instances.id} #{@instances.key_name} #{@instances.availability_zone} #{@login}\n")
          end
        end
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
      end
    end
    
    def _delete_file
      begin
        File.delete("#{ENV["HOME"]}/.nest")
      rescue => ex
        puts "[WARN]".yellow + "#{ex.message}"
        puts "There is no wasps in the air."
      end
    end
  
    def terminate
      count = 0
      
      #if @instances.nil? then
        ins = _get_instances
        
        return nil if ins.nil?
        
        
        ins.each do |region, info|
          r = get_ec2_zone(region)
          info[:instances].each do |i| 
            count += 1
            puts "Wasp" + " #{i}".yellow + " from #{region} is going home"
            begin
              @ec2.regions[r].instances[i].terminate
            rescue => e
              puts "#{e.message}"
            end
          end
        end
      
      _delete_file
      
      puts "EC2".green + " Stood down #{count} wasps.\n"
    end
    
    def get_wasps
      wasps = []
      ins = _get_instances
      
      return nil if ins.nil?
      
      count = ins.count
      ins.each do |region, info|
        r = get_ec2_zone(region)
        login = info[:login]
        info[:instances].each do |it|
          i = @ec2.regions[r].instances[it]
        
          wasps.push({:instance_id => i.id, 
                     :instance_name => i.dns_name, 
                     :region => region,
                     :login => login,
                     :key_name => i.key_pair.name,
                     :report => nil,
                     :wavereport => nil})
        end
      end
      
      wasps
    end
    
    def status
      return ins = _get_instances
    end
    
    def get_wasp_status(zone=WASP::Const::DEFAULT_ZONE , id)
      begin
        z = get_ec2_zone(zone)
        @ec2.regions[z].instances[id].status
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
        return nil
      end        
    end
    
    def get_wasp_domain(zone=WASP::Const::DEFAULT_ZONE , id)
      begin
        z = get_ec2_zone(zone)
        @ec2.regions[z].instances[id].dns_name
      rescue => ex
        puts "[WARN]".yellow + " #{ex.message}"
        return nil
      end
    end
    
    def get_ec2_zone(zone)
      case
      when zone.match(/eu-west-1/)
        "eu-west-1"
      when zone.match(/sa-east-1/)
        "sa-east-1"
      when zone.match(/us-west-1/)
        "us-west-1"
      when zone.match(/us-west-2/)
        "us-west-2"
      when zone.match(/ap-northeast-1/)
        "ap-northeast-1"
      when zone.match(/us-east-1/)
        "us-east-1"
      when zone.match(/ap-southeast-1/)
        "ap-southeast-1"
      else
        "us-east-1"
      end
    end
    
    def get_default_ami(zone)
      case
      when zone.match(/eu-west-1/)
        "ami-895069fd"
      when zone.match(/sa-east-1/)
        "ami-b673acab"
      when zone.match(/us-west-1/)
        "ami-6da8f128"
      when zone.match(/us-west-2/)
        "ami-ae05889e"
      when zone.match(/ap-northeast-1/)
        "ami-10299f11"
      when zone.match(/us-east-1/)
        "ami-baba68d3"
      when zone.match(/ap-southeast-1/)
        "ami-4296d210"
      else
        "ami-baba68d3"
      end
    end
  
    def get_regions
      regions = []
      @ec2.regions.each do |r|
        regions.push(r.name)
      end
      
      regions
    end
  end
end
