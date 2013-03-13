module WASP
  class WeaponAB
    attr_reader   :ssh
    attr_reader   :ab
    attr_reader   :zip
    attr_reader   :ulimit
    
    def initialize
      @ab = false
      @zip = false
      @ulimit = false
    end
    
    def check(ssh)      
      return nil if ssh.nil?

      @ssh = ssh
      result = @ssh.exec! "ab -V"
      @ab = true if not result.match(/This is ApacheBench, Version 2/).nil?
      
      zip_result = @ssh.exec! "zip -h"      
      @zip = true if not zip_result.match(/Info-ZIP/).nil?
      
      open_files = @ssh.exec! "ulimit -n"
      @ulimit = true if open_files.to_i > 1024
      
      return @ab && @zip && @ulimit
    end
    
    def reload
      if @ssh.nil? then
        print "[Error]".red + " Check your weapon first!"
        return nil
      end
  
      if not @ab then
        command = "uname -v"
        dist = @ssh.exec! command
        case 
        when dist.match(/Ubuntu/) then
          command = 'sudo apt-get update'
          @ssh.exec! command
          command = 'sudo apt-get install apache2-utils -y'
          result = @ssh.exec! command
        end
      end
      
      if not @zip then
        command = "uname -v"
        dist = @ssh.exec! command
        case 
        when dist.match(/Ubuntu/) then
          command = 'sudo apt-get update'
          @ssh.exec! command
          command = 'sudo apt-get install zip -y'
        result = @ssh.exec! command
        end
      end     
      
      if not @ulimit then
        command = "if [ -z \"$(cat /etc/security/limits.conf| grep '^*.*[soft|hard].*nofile')\" ]; then bash -c \"echo '*   soft  nofile  65535' >>  /etc/security/limits.conf\"; bash -c \"echo '*   hard  nofile  65535' >>  /etc/security/limits.conf\"; bash -c \"echo 100000 > /proc/sys/kernel/threads-max\"; fi"
        @ssh.exec! command
      end
    end
    
    def wavefire (concurrnet_user, url, id, wave, keepalive=false, without_cookie=false, header=nil)
      if @ssh.nil? then
        print "[Error]".red + " Check your weapon first!"
        return nil
      end
      
      if wave.nil? then
        print "[Error]".red + " No wave!"
        return nil
      end
      
      header = "-H '#{header}'" if not header.nil?
      
      cookie = "-C 'sessionid=NotARealSessionID'"
      cookie = nil if without_cookie
      
      keepalive_s = ""
      keepalive_s = "-k" if keepalive

      time = WASP::Const::DEFAULT_WAVE_TIME
      
      command = "ab -t #{time} #{keepalive_s} -r #{cookie} #{header} -c #{concurrnet_user} #{url}/"
      report = @ssh.exec! command
      
      report
    end
        
    def fire (num_requests, concurrnet_user, url, id, report=false, keepalive=false, without_cookie=false, time=nil, header=nil)
      if @ssh.nil? then
        print "[Error]".red + " Check your weapon first!"
        return nil
      end
      
      keepalive_s = ""
      keepalive_s = "-k" if keepalive
      
      gnuplot = "-g #{id}.plot" if report
      
      cookie = "-C 'sessionid=NotARealSessionID'"
      cookie = nil if without_cookie
      
      header = "-H '#{header}'" if not header.nil?
      
      option = "-n #{num_requests}"
      
      option = "-t #{time}" if not time.nil?
      
      command = "ab #{keepalive_s} -r #{gnuplot} #{option} #{header} -c #{concurrnet_user} #{cookie} #{url}/"
      report = @ssh.exec! command
      
      command = "zip #{id}.zip #{id}.plot"
      @ssh.exec! command
      
      report
    end
    
    def points (report)
      return nil if report.nil?
      
      #puts report
      
      error_regex = []
      
      response = {}
      
      error_regex.push(/Too many open files/)
      error_regex.push(/Cannot use concurrency level greater than total number of requests/)
      error_regex.push(/Invalid Concurrency/)
      error_regex.push(/The timeout specified has expired/)
      
      error_regex.each do |reg|
        return nil if not report.match(reg).nil?
      end
        
      regex = /Concurrency Level:.*[\d]*/
      report.match(regex) do |data|
        response[:concurrency] = data.to_s.gsub!(/\D/, '')
        #puts response[:concurrency]
      end
      
      regex = /Time taken for tests:.*[\d]*.[\d]*.*seconds/
      report.match(regex) do |data|
        response[:time] = data.to_s.gsub!(/[a-zA-Z:\s]/, '')
        #puts response[:time]
      end
      
      regex = /Complete requests:.*[\d]*/
      report.match(regex) do |data|
        response[:complete] = data.to_s.gsub!(/\D/, '')
        #puts response[:complete]
      end
      
      regex = /Failed requests:.*[\d]*/
      report.match(regex) do |data|
        response[:failed] = data.to_s.gsub!(/\D/, '')
        #puts response[:failed]
      end
      
      regex = /Write errors:.*[\d]*/
      report.match(regex) do |data|
        response[:write_errors] = data.to_s.gsub!(/\D/, '')
        #puts response[:write_errors]
      end
      
      regex = /Non-2xx responses:.*/
      response[:non2xx] = 0
      report.match(regex) do |data|
        values = data.to_s.split(" ")
        response[:non2xx] = values[2] unless values.nil?
        #puts response[:transferred]
      end
      
      response[:ok] = response[:complete].to_i - response[:non2xx].to_i
      response[:ok] = 0 if response[:ok] < 0
      
      regex = /Total transferred:.*[\d]*.*bytes/
      report.match(regex) do |data|
        response[:transferred] = data.to_s.gsub!(/\D/, '')
        #puts response[:transferred]
      end
      
      regex = /HTML transferred:.*[\d]*.*bytes/
      report.match(regex) do |data|
        response[:html_transferred] = data.to_s.gsub!(/\D/, '')
        #puts response[:html_transferred]
      end
      
      regex = /Requests per second:.*[\d]*.[\d]*.*\[#\/sec\].*\(mean\)/
      report.match(regex) do |data|
        #response[:requests_per_second] = data.to_s.gsub!(/[a-zA-Z:#\s\[\/\]\(\)]/, '')
        response[:requests_per_second] = response[:ok].to_f / response[:time].to_f
        #puts response[:requests_per_second]
      end
      
      regex = /Time per request:.*[\d]*.[\d]*.*\[ms\].*\(mean\)/
      report.match(regex) do |data|
        response[:time_per_request] = data.to_s.gsub!(/[a-zA-Z:\s\[\]\(\)]/, '')
        #puts response[:time_per_request]
      end      
      
      regex = /Total:.*/
      report.match(regex) do |data|
        values = data.to_s.split(" ")
        response[:mean_per_request] = values[2] unless values.nil?
        response[:standard_deviation] = values[3] unless values.nil?
        #puts response[:mean_per_request]
        #puts response[:standard_deviation]
      end
      
      regex = /.*80\%.*[\d]*/
      report.match(regex) do |data|
        response[:eighty_percent] = data.to_s.gsub!(/\s*80\%\s*/, '')
        #puts response[:eighty_percent]
      end
      
      regex = /.*100\%.*[\d]*/
      report.match(regex) do |data|
        response[:hundred_percent] = data.to_s.gsub!(/\s*100\%\s*/, '')
        #puts response[:hundred_percent]
      end
      
      response
    end
    
    def compact_summary (results)
      return nil if results.nil?

      # remove nil report from results array
      reports = []
      results.each do |r|
        if not r.nil? then
          reports.push(r)
        end
      end
        
      concurrency_results = reports.map do |r| r[:concurrency].to_i end
      total_concurrency = concurrency_results.inject do |sum, r| sum + r end
      
      print " Concurrent users:\t\t" + "#{total_concurrency}".yellow   + "\n"
      
      rps_results = reports.map do |r| r[:requests_per_second].to_f end
      mean_requests = rps_results.inject do |sum, r| sum + r end
      
      print " Requests per second:\t\t" + "%.3f".green % mean_requests + " [#/sec] (mean)\n"
      
      #tpr_results = reports.map do |r| r[:time_per_request].to_f end
      #tpr = tpr_results.inject { |sum, r| sum + r } / reports.count
      
      tpr = total_concurrency / mean_requests * 1000
      print " Time per request:\t\t" + "%.3f".green % tpr + " [ms] (mean)\n"
      
      mpr_results = reports.map do |r| r[:mean_per_request].to_f end
      mean_response = mpr_results.inject { |sum, r| sum + r } / reports.count
      
      print " Connection Time:\t\t" + "%.3f".green % mean_response + " [ms] (mean)\n"
      
      eighty_results = reports.map do |r| r[:eighty_percent].to_f end
      mean_eighty = eighty_results.inject { |sum, r| sum + r } / reports.count
      
      print " Almost(80%%) response time:\t%.3f [ms] (mean)\n" % mean_eighty
    end
    
    def summary (results)
      return nil if results.nil?

      # remove nil report from results array
      reports = []
      results.each do |r|
        if not r.nil? then
          reports.push(r)
        end
      end
        
      concurrency_results = reports.map do |r| r[:concurrency].to_i end
      total_concurrency = concurrency_results.inject do |sum, r| sum + r end
      
      print " Concurrent users:\t\t" + "#{total_concurrency}".yellow   + "\n"
      
      complete_results = reports.map do |r| r[:complete].to_i end
      total_complete_requests = complete_results.inject do |sum, r| sum + r end
      
      print " Complete requests:\t\t#{total_complete_requests}\n"
      
      ok_results = reports.map do |r| r[:ok].to_i end
      total_ok_responses = ok_results.inject do |sum, r| sum + r end

      print " 20x responses:\t\t\t#{total_ok_responses}\n"      
      
      non2xx_results = reports.map do |r| r[:non2xx].to_i end
      total_non2xx_responses = non2xx_results.inject do |sum, r| sum + r end

      print " Non-2xx responses:\t\t#{total_non2xx_responses}\n"
      
      failed_results = reports.map do |r| r[:failed].to_i end
      total_failed_requests = failed_results.inject do |sum, r| sum + r end
      
      print " Failed requests:\t\t" + "#{total_failed_requests}".red + "\n"
      
      time_results = reports.map do |r| r[:time].to_f end
      time_taken = time_results.inject { |sum, r| sum + r } / reports.count
      
      print " Time taken for test:\t\t%.3f seconds (mean)\n" % time_taken
      
      rps_results = reports.map do |r| r[:requests_per_second].to_f end
      mean_requests = rps_results.inject do |sum, r| sum + r end
      
      print " Requests per second:\t\t" + "%.3f".green % mean_requests + " [#/sec] (mean)\n"
      
      #tpr_results = reports.map do |r| r[:time_per_request].to_f end
      #tpr = tpr_results.inject { |sum, r| sum + r } / reports.count
      
      tpr = total_concurrency.to_f / mean_requests.to_f * 1000.0
      
      print " Time per request:\t\t" + "%.3f".green % tpr + " [ms] (mean)\n"
      
      mpr_results = reports.map do |r| r[:mean_per_request].to_f end
      mean_response = mpr_results.inject { |sum, r| sum + r } / reports.count
      
      print " Connection Time:\t\t" + "%.3f".green % mean_response + " [ms] (mean)\n"
      
      eighty_results = reports.map do |r| r[:eighty_percent].to_f end
      mean_eighty = eighty_results.inject { |sum, r| sum + r } / reports.count
      
      print " Almost(80%%) response time:\t%.3f [ms] (mean)\n" % mean_eighty
      
      hundred_results = reports.map do |r| r[:hundred_percent].to_f end
      longest_response = hundred_results.sort.last
      
      print " The longest response time:\t%.3f [ms] (mean)\n\n" % longest_response
      
      case 
      when mean_response < 500 then
        print "Mission Assessment: Target crushed wasp offensive.\n\n"
      when mean_response < 1000 then
        print "Mission Assessment: Target successfully fended off the wasp.\n\n"
      when mean_response < 1500 then
        print "Mission Assessment: Target wounded, but operational.\n\n"
      when mean_response < 2000 then
        print "Mission Assessment: Target severely compromised.\n\n"
      else
        print "Mission Assessment: wasp annihilated target.\n\n"
      end
    end
    
  end
end
