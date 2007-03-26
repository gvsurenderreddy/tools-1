# --  backup�� --------------------------------------------------------------

def backup_logfile(log_file)
  return  unless File.exist?("#{log_file}")
  mtime = File.mtime("#{log_file}")
  suffix = mtime.strftime('%Y%m%d%H%M%S')
  File.rename("#{log_file}", "#{log_file}.#{suffix}")
  `bzip2 -f -9 '#{log_file}.#{suffix}'` if $LOG_FILE_COMPRESS
end # def backup_logfile(log_file)

def backup_nosources(hTAG, srpm_only, log_file)
  momo_debug_log("backup_nosources #{hTAG['NAME']}")

  topdir = get_topdir(hTAG['NAME'], "..")
  if (hTAG["NOSOURCE"] != nil && !srpm_only) then
    hTAG["NOSOURCE"].split(/[\s,]/).each do |n|
      if n != "" then
        if n == "0" && ! hTAG.key?("SOURCE0")
          s = hTAG["SOURCE"]
        else
          s = hTAG["SOURCE#{n}"]
        end
        s = s.split(/\//)[-1] if s =~ /^(ftp|https?):\/\//
        exec_command("cp -pfv SOURCES/#{s} #{topdir}/SOURCES", log_file)
        File.chmod 0644, "#{topdir}/SOURCES/#{s}"
      end
    end
  end
  if (hTAG.key?("NOPATCH") && !srpm_only) then
    hTAG["NOPATCH"].split(/[\s,]/).each do |n|
      if n != "" then
        if n == "0" && ! hTAG.key?("PATCH0") then
          s = hTAG["PATCH"]
        else
          s = hTAG["PATCH#{n}"]
        end
        s = s.split(/\//)[-1] if s =~ /^(ftp|https?):\/\//
        exec_command("cp -pfv SOURCES/#{s} #{topdir}/SOURCES", log_file)
        File.chmod 0644, "#{topdir}/SOURCES/#{s}"
      end
    end
  end
end

=begin
--- backup_rpms(hTAG, install, log_file)
�ӥ�ɤ��줿RPM�ե�����θŤ��С������Τ�Τ�topdir�ʲ��γƥǥ��쥯��
�꤫��õ����������Τ�topdir�γƥǥ��쥯�ȥ�˥��ԡ����롣�����ǻ���
����Ƥ�����ˤϡ��������ѥå������Υ��󥹥ȡ���⤹�롣
=end
def backup_rpms(hTAG, install, rpmopt, log_file)
  specname = hTAG['NAME']
  topdir = get_topdir(specname, "..")
  if specname and $DEPGRAPH then
    spec = $DEPGRAPH.db.specs[specname]
    spec.lastbuild = Time.now
  end # if specname and $DEPGRAPH then

  if rpmopt =~ /\-ba|\-bs/ then
    # refresh the SRPM file
    Dir.glob("SRPMS/*.rpm").each do |srpm|
      pkg = srpm.split("/")[-1].split("-")[0..-3].join("-")
      Dir.glob("#{topdir}/SRPMS/#{pkg}-*src.rpm") do |s|
        if pkg == s.split("/")[-1].split("-")[0..-3].join("-") then
          File.delete s
        end
      end
      exec_command("cp -pfv #{srpm} #{topdir}/SRPMS", log_file)
      File.chmod 0644, "#{topdir}/SRPMS/#{srpm.split('/')[-1]}"
    end
  end
  if rpmopt =~ /\-ba|\-bb/ then
    installs = ""
    rpms = Dir.glob("RPMS/{#{$ARCHITECTURE},noarch}/*.rpm")
    rpms.each do |rpm|
      if specname and $DEPGRAPH then
        spec = $DEPGRAPH.db.specs[specname]
        begin
          rpmpkg = RPM::Package.open(File.expand_path(rpm))
          spec.packages.each do |pkg|
            next if pkg.name != rpmpkg.name
            pkg.provides = rpmpkg.provides.collect{|rpmprov| rpmprov.to_struct}
            pkg.provides.each do |prov|
              names = if $DEPGRAPH.db.packages[prov.name] then
                        $DEPGRAPH.db.packages[prov.name].collect{|a| a.name}
                      else
                        []
                      end
              if not names.include?(pkg.name) then
                $DEPGRAPH.db.packages[prov.name] = pkg
              end
            end # pkg.provides.each do |prov|
            pkg.requires = rpmpkg.requires.collect{|rpmreq| rpmreq.to_struct}
          end # spec.packages.each do |pkg|
        ensure
          rpmpkg = nil
          GC.start
        end # begin
      end # if specname and $DEPGRAPH then
      # refresh the packages in #{topdir} with the newly built ones
      pkg = rpm.split("/")[-1].split("-")[0..-3].join("-")
      Dir.glob("#{topdir}/{#{$ARCHITECTURE},noarch}/#{pkg}-*.{#{$ARCHITECTURE},noarch}.rpm") do |r|
        if pkg == r.split("/")[-1].split("-")[0..-3].join("-") then
          File.delete r
        end
      end
      current_arch = rpm.split('/')[-2]
      exec_command("cp -pfv #{rpm} #{topdir}/#{current_arch}", log_file)
      File.chmod 0644, "#{topdir}/#{current_arch}/#{rpm.split('/')[-1]}"
      if install then
        installs += "#{rpm} "
      elsif $DEPEND_PACKAGE != "" && pkg =~ /#{$DEPEND_PACKAGE}/
          installs += "#{rpm} "
      end
      if $SCANPACKAGES && rpms.last == rpm then
        exec_command("/usr/sbin/mph-scanpackages #{topdir}/#{$ARCHITECTURE} #{topdir}/noarch", log_file)
      end
    end
    if installs != ""
      exec_command("sudo rpm -Uvh --force #{installs} || sudo rpm -Uvh --nodeps --force #{installs}", log_file)
      until $SYSTEM_PROVIDES.empty?
        $SYSTEM_PROVIDES.pop
      end
      begin
        rpmdb = RPM::DB.open
        rpmdb.each do |pkg|
          pkg.provides.each do |a|
            next if (a.flags & RPM::SENSE_RPMLIB).nonzero?
            $SYSTEM_PROVIDES.push(a.to_struct)
          end
        end # rpmdb.each do |pkg|
      ensure
        rpmdb = nil
        GC.start
      end
    end
  end
end