# -*- coding: euc-jp -*-
# by Hiromasa YOSHIMOTO <y@momonga-linux.org>

require 'lib/database.rb'
require 'lib/install.rb'

#
# �������ʤ�package������
# !!FIXME!!  ����ե�����������Ѱդ���
HOLDS = [ "kernel", "lame", "lame-devel", "usolame-devel", "usolame" ]

def upgrade_strict(installed, d, opts)
  STDERR.puts "Searching updated packages"  if opts[:verbose]>0
  queue = Set.new
  installed.each do |name,version,buildtime|
    
    # 1) ����Υѥå������� �������ʤ�
    next if HOLDS.include?(name)
    
    found = false
    
    # 2) "#{name}"��obsolete���Ƥ���package������С�����
    sql = "SELECT pkgfile,comparison,version,buildtime FROM obsolete_tbl INNER JOIN pkg_tbl ON owner=id WHERE capability=='#{name}'"
    d.db.execute(sql) do |pkgfile,comparison,version1,buildtime1|
      next if !compare_version(version, comparison, version1)
      if buildtime.to_i != buildtime1 then
        STDERR.puts "#{name} is obsoleted by #{pkgfile}" if opts[:verbose]>1
        queue.add(pkgfile)
        found = true
      end
    end
    next if found
    
    # 3) Ʊ̾����buildtime�ο�����package������С�����
    sql = "SELECT pkgfile,buildtime FROM pkg_tbl WHERE pkgname=='#{name}'"
    d.db.execute(sql) do |pkgfile,ts|
      if ts.to_i != buildtime then
        STDERR.puts "#{name} is updated by #{pkgfile}" if opts[:verbose]>1
        queue.add(pkgfile)
      end
      found = true
    end
    next if found
    
    # 4) "#{name}"��provide���Ƥ���package������С�����
    sql = "SELECT pkgfile,comparison,version,buildtime FROM capability_tbl INNER JOIN pkg_tbl ON owner==id WHERE capability=='#{name}' AND pkgname!='#{name}'"
    d.db.execute(sql) do |pkgfile,comparison,version1,buildtime1|
      next if version1 && compare_version(version1, "<", version)
      STDERR.puts "#{name} is updated by #{pkgfile}" if opts[:verbose]>1
      queue.add(pkgfile)
    found = true
    end
    next if found
    
    # �����ѥå�����̵��
    STDERR.puts "Warning: No package found for #{name}" if opts[:verbose]>1
  end
  
  if queue.size == 0 then
    STDERR.puts "No updated found."
    exit(0)
  end
  
  if opts[:verbose]>1 then
    queue.each do |file|
      STDERR.puts " #{file}" 
    end
  end
  STDERR.puts "#{queue.size} updated packages found"  if opts[:verbose]>0
  
  # strict�⡼��
  # ��ĤǤ⹹������ʤ��ѥå������������upgrade���������Ǥ���
  STDERR.puts "Resolving dependencies" if opts[:verbose]>0
  
  pkgs, msg = select_required_packages(d.db, queue.to_a, opts)
  
  if msg then
    STDERR.puts "#{msg}, abort"
    exit(1)
  end
  
  if pkgs.size > 0  then
    STDERR.puts "Installing #{pkgs.size} packages" if opts[:verbose]>0
    
    cmd="rpm -vU --force #{pkgs.to_a.join(' ')}"
    system(cmd)
    abort("failed to #{cmd}") unless $?.to_i == 0  
  else
    STDERR.puts "already updated" if opts[:verbose]>0
  end
end


def upgrade_permissive(installed, d, opts)
  installed.each do |name,version,buildtime|

    # ����Υѥå������� �������ʤ�
    next if HOLDS.include?(name)

    queue = Set.new
    queue.add(name)
    pkgs, msg = select_required_packages(d.db, queue.to_a, opts)

    if msg then
      STDERR.puts "#{msg}, skip"
      next
    end
    
    if pkgs.size > 0 then
      STDERR.puts "Installing #{pkgs.size} packages" if opts[:verbose]>0
      cmd="rpm -vU --force #{pkgs.to_a.join(' ')}"
      system(cmd)
      STDERR.puts "failed to #{cmd}" unless $?.to_i == 0  
    end
  end
end
