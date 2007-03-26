=begin
--- chk_requires
TAG BuildPreReq, BuildRequires �Ԥ˵��Ҥ���Ƥ���ѥ�
������������Ф��Υѥå����������󥹥ȡ��뤵��Ƥ���
���ɤ���Ƚ�Ǥ���ɬ�פʤ�Х��󥹥ȡ��뤹�롣
rpm -ivh ����ط��塢sudo �� password ̵���Ǽ¹Բ�ǽ
�Ǥ������
=end
def chk_requires(hTAG, name_stack, blacklist, log_file)
  momo_debug_log("chk_requires #{hTAG['NAME']}")

  req = Array.new
  if hTAG.key?("BUILDPREREQ") then
    req = hTAG["BUILDPREREQ"].split(/[\s,]/)
  end
  if hTAG.key?("BUILDREQUIRES") then
    hTAG["BUILDREQUIRES"].split(/[\s,]/).each {|r| req.push r}
  end

  return MOMO_SUCCESS if req.empty?

  req.delete ""
  while r = req.shift do
    # ľ�ܥե�����̾�����ꤵ��Ƥ���
    # �ѥå�����̾����ꤹ�٤�
    next  if r =~ /\//

    # ���󥹥ȡ���Ѥξ�� ir = <epoch>:<ver>-<rel>
    ir = `rpm -q --queryformat '%{EPOCH}:%{VERSION}-%{RELEASE}' #{r} 2>/dev/null`.split(':')
    r = r.split(/\-/)[0..-2].join("-") if r =~ /\-devel/

    if ir.length != 2 then
      rc = build_and_install(r, "-Uvh", name_stack, blacklist, log_file) 
      case rc
      when MOMO_LOOP, MOMO_FAILURE
        return rc
      end
      # �С���������򥹥��åפ���
      if req[0] =~ /[<>=]/ then
        req.shift
        req.shift
      end
      next
    else
      pkg = r
      r = req.shift
      if r =~ /[<>=]/ then
        nr = req.shift.split(':')
        if nr.length == 1 then
          nr.unshift '(none)'
        end
        if nr[1] !~ /-/ then
          ir[1] = ir[1].split('-')[0]
        end
        ver = nil
        if ir[0] == '(none)' then
          if nr[0] == '(none)' then
            ver = `#{$RPMVERCMP} #{ir[1]} #{nr[1]}`.chop
          else
            ver = '<'
          end
        else
          if nr[0] == '(none)' then
            ver = '>'
          else
            case ir[0].to_i <=> nr[0].to_i
            when -1
              ver = '<'
            when 0
              ver = `#{$RPMVERCMP} #{ir[1]} #{nr[1]}`.chop
            when 1
              ver = '>'
            end
          end
        end

        case r
        when ">"
          case ver
          when "<"
            rc = build_and_install(pkg, "-Uvh", name_stack, blacklist, log_file) 
            case rc 
            when MOMO_LOOP, MOMO_FAILURE
              return rc
            end
          else
            next
          end
        when "="
          case ver
          when "="
            next
          else
            rc = build_and_install(pkg, "-Uvh", name_stack, blacklist, log_file) 
            case rc 
            when MOMO_LOOP, MOMO_FAILURE
              return rc
            end
          end
        when ">="
          case ver
          when "<"
            rc = build_and_install(pkg, "-Uvh", name_stack, blacklist, log_file) 
            case rc 
            when MOMO_LOOP, MOMO_FAILURE
              return rc
            end
          else
            next
          end
        end
      else
        req.unshift r
      end
    end
  end
  return MOMO_SUCCESS
end

=begin
--- chk_requires_strict(pkg_name)
TAG BuildPreReq, BuildRequires �Ԥ˵��Ҥ���Ƥ���ѥ�
������������Ф��Υѥå����������󥹥ȡ��뤵��Ƥ���
���ɤ���Ƚ�Ǥ���ɬ�פʤ�Х��󥹥ȡ��뤹�롣
rpm -ivh ����ط��塢sudo �� password ̵���Ǽ¹Բ�ǽ
�Ǥ������

spec �ե�����Υǡ����١����򻲾Ȥ��롣
=end
def chk_requires_strict(hTAG, name_stack, blacklist, log_file)
  momo_debug_log("chk_requires_strict #{hTAG['NAME']}")
  result = MOMO_UNDEFINED

  name = hTAG['NAME']
  brs = $DEPGRAPH.db.specs[name].buildRequires
  if brs.nil? then
    result = MOMO_SUCCESS
    return
  end

  brs.each do |req|
    puts "#{name} needs #{req} installed to build:" if $VERBOSEOUT

    flag = false
    if $SYSTEM_PROVIDES.has_name?(req.name) then
      provs = $SYSTEM_PROVIDES.select{|a| a.name == req.name}

      provs.each do |prov|
        if $VERBOSEOUT then
          print "    checking whether #{prov} is sufficient ..."
          STDOUT.flush
        end
        flag = resolved?(req, prov)
        break if flag
      end

      if flag then
        puts " YES" if $VERBOSEOUT
        next
      else
        puts " NO" if $VERBOSEOUT
      end
    else
      puts "    not installed" if $VERBOSEOUT
    end

    next unless $DEPGRAPH.db.packages[req.name]
    $DEPGRAPH.db.packages[req.name].each do |a|
      spec = $DEPGRAPH.db.specs[a.spec]
      rc = build_and_install(req.name, '-Uvh', name_stack, blacklist, log_file, spec.name)
      case rc 
      when MOMO_LOOP, MOMO_FAILURE
        result = rc
        return
      end
    end
  end # brs.each do |req|

  result = MOMO_SUCCESS
ensure
  momo_assert { MOMO_UNDEFINED != result}
  return result
end # def chk_requires_strict


def check_group(hTAG)
  hTAG['GROUP'].split(/,\s*/).each do |g|
    if GROUPS.rindex(g) == nil then
      if !$SCRIPT then
        print "\n#{RED}!! No such group (#{g}) !!\n"
        print "!! Please see /usr/share/doc/rpm-x.x.x/GROUPS !!#{NOCOLOR}\n"
      else
        print "\n!! No such group (#{g}) !!\n"
        print "!! Please see /usr/share/doc/rpm-x.x.x/GROUPS !!\n"
      end
    end
  end
end

#
#
#
#
def build_and_install(pkg, rpmflg, name_stack, blacklist, log_file, specname=nil)  
  momo_debug_log("build_and_install pkg:#{pkg} rpkflg:#{rpmflg} specname:#{specname}")

  result = MOMO_UNDEFINED

  momo_assert{ pkg!="" }

  ## !!FIXME!!  
  if (pkg =~ /^kernel\-/ &&
        pkg !~ /^kernel-(common|pcmcia-cs|doc|utils)/ ) then
    ## !!FIXME!!
    result = MOMO_SUCCESS
    return 
  end

  if specname then
    if $SYSTEM_PROVIDES.has_name?(pkg) then
      provs = $SYSTEM_PROVIDES.select{|a| a.name == pkg}
      req = SpecDB::DependencyData.new(pkg,
                                       $DEPGRAPH.db.specs[specname||pkg].packages[0].version,
                                       '==')
      flag = false
      provs.each do |prov|
        flag = resolved?(req, prov)
        break if flag
      end      
      if flag then
        result = MOMO_SUCCESS
        return 
      end
    end
  else # specname.nil?
    `rpm -q --whatprovides --queryformat "%{name}\\n" #{pkg}`
    if $?.to_i == 0 then
      result = MOMO_FAILURE
      return
    end
  end # specname.nil?

  if !File.directory?(specname||pkg) then
    `grep -i ^provides: */*.spec | grep #{specname||pkg}`.each_line do |l|
      prov = l.split(/\//)[0]
      if File.exist?("#{prov}/#{prov}.spec") and
          Dir.glob("#{prov}/TO.*") == [] and
          !File.exist?("#{prov}/OBSOLETE") and
          !File.exist?("#{prov}/SKIP") and
          !File.exist?("#{prov}/.SKIP") then
        pkg = prov
        break
      end
    end
  end
  
  #    if `grep -i '^BuildArch:.*noarch' #{specname||pkg}/#{specname||pkg}.spec` != ""
  #      return
  #    end
  if !$NONFREE && File.exist?("#{specname||pkg}/TO.Nonfree")
    result = MOMO_FAILURE
    return
  end
  
  # �����ѥå�������ӥ�ɤ���
  #
  result = buildme(specname||pkg, name_stack, blacklist) 
  case result 
  when MOMO_SUCCESS, MOMO_SKIP
    result = MOMO_UNDEFINED
  else
    return 
  end

  pkgs = []
  if specname and $DEPGRAPH then
    spec = $DEPGRAPH.db.specs[specname]
    pkg2 = spec.packages.select{|a| a.name == pkg}[0]
    if pkg2 then
      pkg2.requires.each do |req|
        if not $SYSTEM_PROVIDES.has_name?(req.name) then
          if $DEPGRAPH.db.packages[req.name] then
            $DEPGRAPH.db.packages[req.name].each do |a|
              result = build_and_install(a.spec, rpmflg, 
                                         name_stack, blacklist, log_file)
              case result 
              when MOMO_LOOP, MOMO_FAILURE 
                return
              else
                result = MOMO_UNDEFINED
              end              
            end
          end
        end
      end
      pkg = pkg2.name
    end
  end


  topdir = get_topdir(pkg)

  pkgs = Dir.glob("#{topdir}/#{$ARCHITECTURE}/#{pkg}-*.rpm")
  pkgs += Dir.glob("#{topdir}/noarch/#{pkg}-*.rpm")

  if /-devel/ =~ pkg then
    mainpkg = pkg.sub( /-devel/, '' )
    pkgs += Dir.glob("#{topdir}/#{$ARCHITECTURE}/#{mainpkg}-*.rpm")
    pkgs += Dir.glob("#{topdir}/noarch/#{mainpkg}-*.rpm")
  end

  if not pkgs.empty? then
    pkgs.uniq!
    cmd="rpm #{rpmflg} --force --test #{pkgs.join(' ')}"
    ret = exec_command("#{cmd}", log_file)
    if 0 != ret then
      result = MOMO_FAILURE
      return
    end
    cmd="rpm #{rpmflg} --force #{pkgs.join(' ')}"
    ret = exec_command("sudo #{cmd}", log_file)
    if 0 != ret then
      result = MOMO_FAILURE
      return
    end

    if not $CANNOTSTRICT then
      pkgs.each do |a|
        begin
          rpmpkg = RPM::Package.open(a)
          rpmpkg.provides.each do |prov|
            if not $SYSTEM_PROVIDES.has_name?(prov.name) then
              $SYSTEM_PROVIDES.push(prov)
            end
          end
        ensure
          rpmpkg = nil
          GC.start
        end
      end
    end
  end

  if !$VERBOSEOUT then
    name = specname||pkg
    print "#{name} "
    print "-" * [51 - name.length, 1].max, "> "
  end
  
  ## SUCCESS!!
  result = MOMO_SUCCESS

ensure
  momo_assert { MOMO_UNDEFINED != result }
  momo_debug_log("build_and_install returns #{result}")
  return result
end
