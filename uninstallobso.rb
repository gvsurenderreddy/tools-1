#!/usr/bin/ruby -Ku
# -*- coding: utf-8 -*-
#
# This program scans through your CVS working copy for the packages and
# lists binary packages names with the file OBSOLETE in its directory.
#
# Copyright 2003 Momonga Project <admin@momonga-linux.org>
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#

require 'getoptlong'

options = [
  ["-L", "--alter",        GetoptLong::NO_ARGUMENT],
  ["-n", "--nonfree",      GetoptLong::NO_ARGUMENT],
  ["-O", "--orphan",       GetoptLong::NO_ARGUMENT],
  ["-o", "--obsolete",     GetoptLong::NO_ARGUMENT],
  ["-s", "--skip",         GetoptLong::NO_ARGUMENT],
  ["-h", "--help",         GetoptLong::NO_ARGUMENT],
]

def show_usage()
  print <<END_OF_USAGE
Usage: ../tools/uninstall [options]
  -L, --alter           delete alter packages.
  -n, --nonfree         delete nonfree packages.
  -O  --orphan          delete orphan packages.
  -o  --obsolete        delete obsolete packages.
  -s  --skip            delete skipped packages.
  -h  --help            show this message
END_OF_USAGE
  exit
end


flag_files = Array.new
begin
  GetoptLong.new(*options).each do |on, ov|
    case on
    when "-L"
      flag_files << 'TO.Alter'
    when "-n"
      flag_files << 'TO.Nonfree'
    when "-O"
      flag_files << 'TO.Orphan'
    when "-o"
      flag_files << 'OBSOLETE'
    when "-s"
      flag_files << 'SKIP'
    when "-h"
      show_usage
    end
  end
rescue
  exit 1
end

$:.unshift(File.dirname($0))
require 'rpm'
require 'environment'

# check where we are... should we cd to the $PKGDIR?
if File.expand_path($PKGDIR) != File.expand_path(Dir.getwd)
	puts "Run in pkgs/ dir."
	exit 1
end

# for Ruby/RPM
RPM.readrc( './rpmrc' )
RPM.readrc( '/usr/lib/rpm/rpmrc' )
ARCH=RPM[%{_target_cpu}]

# scan through the directories
obso_pkgs = []
flag_files.each do |flag_file|
	Dir.glob( "*/#{flag_file}" ).each do |f|
		name = File.dirname( f )
		spec = RPM::Spec.open( "#{name}/#{name}.spec" )
		if spec.nil? then
			$stderr.puts "Error in reading #{name}/#{name}.spec"
			next
		end
		spec.packages.each do |pkg|
			system( "rpm -q #{pkg.name} > /dev/null" )
			if 0 == $? then	# rpm -q returns 0 if the package is installed
				obso_pkgs << pkg.name
			end
		end
	end
end

# show the result
unless obso_pkgs.empty? then
	puts "#{flag_files.join('')} packages are installed in your system, do the following if you want:"
	puts "sudo rpm -e #{obso_pkgs.join(' ')}"
else
	puts "There is no #{flag_files.join('')} packages installed in your system."
end
