module WASPExtensions

  def say(message)
    WASP::Config.output.puts(message) if WASP::Config.output
  end

  def header(message, filler = '-')
    say "\n"
    say message
    say filler.to_s * message.size
  end

  def banner(message)
    say "\n"
    say message
  end

  def display(message, nl=true)
    if nl
      say message
    else
      if WASP::Config.output
        WASP::Config.output.print(message)
        WASP::Config.output.flush
      end
    end
  end

  def clear(size=80)
    return unless WASP::Config.output
    WASP::Config.output.print("\r")
    WASP::Config.output.print(" " * size)
    WASP::Config.output.print("\r")
    #WASP::Config.output.flush
  end

  def err(message, prefix='Error: ')
    raise WASP::CliExit, "#{prefix}#{message}"
  end

  def quit(message = nil)
    raise WASP::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end

  def uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  def pretty_size(size, prec=1)
    return 'NA' unless size
    return "#{size}B" if size < 1024
    return sprintf("%.#{prec}fK", size/1024.0) if size < (1024*1024)
    return sprintf("%.#{prec}fM", size/(1024.0*1024.0)) if size < (1024*1024*1024)
    return sprintf("%.#{prec}fG", size/(1024.0*1024.0*1024.0))
  end

end

module StringExtensions
    def red
        colorize("\e[0m\e[31m")
    end

    def green
        colorize("\e[0m\e[32m")
    end

    def yellow
        colorize("\e[0m\e[33m")
    end

    def bold
        colorize("\e[0m\e[1m")
    end

    def colorize(color_code)
        "#{color_code}#{self}\e[0m"
    end

    def blank?
        self =~ /^\s*$/
    end

    def truncate(limit = 30)
        return "" if self.blank?
        etc = "..."
        stripped = self.strip[0..limit]
        if stripped.length > limit
            stripped.gsub(/\s+?(\S+)?$/, "") + etc
        else
            stripped
        end
    end
end

class Object
  include WASPExtensions
end

class String
  include StringExtensions
end