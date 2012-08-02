#!/usr/bin/env ruby

require 'fileutils'

def usage
  puts "USAGE: makeplot.rb [DIRECTORY]"
  exit false
end

def contents(title, list, output="out.png")
  content = "
  # output as png image
  set terminal png size 1024, 768

  # save file to #{output}
  set output \"#{output}\"

  # graph title
  set title \"#{title}\"

  # nicer aspect ratio for image size
  set size 1, 1

  # y-axis grid
  set grid y

  # x-axis label
  set xlabel \"request\"

  # y-axis label
  set ylabel \"response time (ms)\"\n\n"

  plots = ''

  if output == "summary.png" then
    plots = "plot \"#{list}\" using 9 smooth frequency title \"request\", \
    \"#{list}\" using 7 smooth frequency title \"connect\""
  elsif output == "out.png" then
    files = list.dup  
    return nil if files.nil?

    if files.count > 0 then
      first_file = files.pop
      without_ext = first_file.sub(File.extname(first_file), '')
      line = "plot \"#{first_file}\" using 9 smooth frequency title \"#{without_ext}\""
      plots += line
    end
  
    files.each do |file|
      without_ext = file.sub(File.extname(file), '')
      line = ", \"#{file}\" using 9 smooth frequency title \"#{without_ext}\""
      plots += line
    end
  end
  
  plotfile = content + plots
  
  plotfile
end

args = ARGV
directory = args.shift 

usage if directory.nil?

dir = Dir.open(directory)

files = []
print "Find and unzip files..\n"
dir.each do |file|  
  if File.extname(file) == ".zip" then
    `unzip "#{directory}/#{file}"`
    `rm #{directory}/#{file}`
    file.sub!(".zip", ".plot")
    files.push(file)
    puts "pushing #{file}"
  end
end

print "Generate gnuplot file..\n"
dirname = directory.sub('/', '')
content = contents(dirname, files)

File.open(dirname + '.p', "w") do |file|
  file.write(content)
end
print "Creating big one..\n"

fp = []
files.each do |f|
  fd = File.open(f, "r")
  fp.push(fd)
end

File.open("total.plot", "w+") do |file|
  totalsize = 0
  fp.each do |f|
    totalsize += f.size 
  end
  while file.size < totalsize do
    begin
      fp.each do |p|
        line = p.readline
        file.write(line)
      end
    rescue => ex
      puts "#{ex.message}"
    end
  end
end  

content = contents(dirname + "-summary", "total.plot", "summary.png")

File.open('total.p', "w") do |file|
  file.write(content)
end

print "Generate graph image..\n"
`gnuplot #{dirname}.p`
`gnuplot total.p`

begin
  FileUtils.mv(files + [dirname+'.p', "total.p", "total.plot", "out.png", "summary.png"], dirname)
rescue => ex
  puts "#{ex.message}"
end
print "End.\n"
print "You can see the report image in #{dirname}/out.png\n"

exit true

