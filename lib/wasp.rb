ROOT = File.expand_path(File.dirname(__FILE__))

module WASP
  autoload :Const,    	"#{ROOT}/wasp/const"
  autoload :Wasp,      	"#{ROOT}/wasp/wasp"
  autoload :QueenWasp, 	"#{ROOT}/wasp/queenwasp"
  autoload :Nest,  		"#{ROOT}/wasp/nest"
  autoload :Aws,      	"#{ROOT}/wasp/ec2"
  autoload :Config,   	"#{ROOT}/wasp/config"
  autoload :WeaponAB, 	"#{ROOT}/wasp/stingab"
end

require "#{ROOT}/wasp/core_ext"
require 'fileutils'