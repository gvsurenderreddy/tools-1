#! /usr/bin/env ruby

$:.unshift(File.dirname($0))
require 'environment'
load 'updatespecdb'

#specdb �� OBSOLETES �Ͻ������Ƥ�Τǹͤ���ɬ�פʤ�
#$ �Ϥ�����Ǥ��硣

if File.expand_path($PKGDIR) != File.expand_path(Dir.getwd)
  puts "Run in pkgs/ dir."
  exit 1
end

#specdb ���� arch �Ȥ��褦�ˡ�
RPM.readrc("./rpmrc")
#ARCH=RPM[%{_target_cpu}]
ARCH=$ARCH

$DB = SpecDB.new
$Sources = {}
$Packages = {}

$DB.specs.each_value do |spec|
  nosource = false
  todir=$TOPDIR
  Dir.glob("#{spec.name}/TO.*").each do |to|
    todir += "-#{File.basename(to)[3..-1]}"
  end
  spec.sources.each do |source|
    if source.no?
      nosource = true
      ($Sources[todir]||={})[source.filename] = true
    end
  end
  p spec unless spec.packages[0]
  next unless spec.packages[0]
  if !nosource
#packages[0] �ϥ������㤦���⤢�롣
#specdb ���夤��
    ($Packages[todir]||={})["#{spec.name}-#{spec.packages[0].version}.src.rpm"] = true
  else
    ($Packages[todir]||={})["#{spec.name}-#{spec.packages[0].version}.nosrc.rpm"] = true
  end
  spec.packages.each do |pkg|
    arch = ARCH
    if spec.archs[0]
      arch = spec.archs[0]
    end
    ($Packages[todir]||={})["#{pkg.name}-#{pkg.version}.#{arch}.rpm"] = true
  end
end

$Massatu = []
Dir.glob("#{$TOPDIR}*").each do |top|
  Dir.glob("#{top}/*/*.rpm").each do |rpm|
    if !$Packages[top][File.basename(rpm)]
      $Massatu << rpm
    end
  end
  Dir.glob("#{top}/SOURCES/*").each do |src|
    if !$Sources[top][File.basename(src)]
      $Massatu << src
    end
  end
end

if $Massatu.length == 0
  exit
end

if ARGV[0] != "-f"
  $Massatu.sort.each do |file|
    print "rm #{file}\n"
  end

  printf( "�����衣 (y/N)> " )
  sAnswer = STDIN.gets().chomp().downcase()
  if( sAnswer != 'y' )
    printf( "���㡢�����ʤ���\n" )
    exit
  end
end

$Massatu.each do |file|
  File.unlink(file)
end
