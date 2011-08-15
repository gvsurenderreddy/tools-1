# -*- coding: utf-8 -*-
# lib/specdb.rb
#
# by Hiromasa YOSHIMOTO <y@momonga-linux.org>

require 'lib/database.rb'

class SpecDB < DBBase
  TABLE_MAJOR_VERSION=3 # increase when the layout breaks compatibility
  TABLE_MINOR_VERSION=2 # increase when we have to rebuild the DB
  TABLE_LAYOUT=<<ENDOFSQL

drop table if exists buildreq_tbl;
create table buildreq_tbl (
       owner integer not null,

       capability text,
       comparison text default null,
       version text default null
);

drop table if exists package_tbl;
create table package_tbl (
       owner integer not null,

       capability text not null,
       comparison text default null,
       version text default null
);

drop table if exists require_tbl;
create table require_tbl (
       owner integer not null,
       package text,

       capability text,
       comparison text default null,
       version text default null
);

drop table if exists provide_tbl;
create table provide_tbl (
       owner integer not null,
       package text,

       capability text,       
       comparison text default null,
       version text default null,

       autogenerated interger default 0
);

drop table if exists conflict_tbl;
create table conflict_tbl (
       owner integer not null,
       package text,

       capability text,       
       comparison text default null,
       version text default null
);

drop table if exists specfile_tbl;
create table specfile_tbl (
       id integer primary key autoincrement,
       name text unique not null,
       lastupdate integer
);

drop table if exists misc_tbl;
create table misc_tbl (
       major_version integer,
       minor_version integer,
       lastupdate integer
);

DROP VIEW IF EXISTS capa_view;
CREATE VIEW capa_view AS SELECT owner,capability,comparison,version FROM provide_tbl UNION ALL SELECT owner,capability,comparison,version FROM package_tbl;

ENDOFSQL

  def open(database, opts = nil)
    open_database(database, 
                  TABLE_LAYOUT,
                  TABLE_MAJOR_VERSION, 
                  TABLE_MINOR_VERSION,  opts)
    
    # for update_list()
    @stmt_select_count_id_from_specfile_tbl =
      @db.prepare('select count(id) from specfile_tbl where name == ? and lastupdate>=?')
    @stmt_insert_or_ignore_into_specfile_tbl =
      @db.prepare('insert or ignore into specfile_tbl (name) values(?)')
    @stmt_select_id_from_specfile_tbl =
      @db.prepare('select id from specfile_tbl where name == ?')
    @stmt_update_specfile_tbl =
      @db.prepare('update specfile_tbl set lastupdate = ? where name == ?')

    @stmt_insert_into_buildreq_tbl =
      @db.prepare('insert into buildreq_tbl (owner,capability,comparison,version) values(?,?,?,?)')
    @stmt_insert_into_package_tbl =
      @db.prepare('insert into package_tbl (owner,capability,comparison,version) values(?,?,?,?)')
    @stmt_insert_into_require_tbl =
      @db.prepare('insert into require_tbl (owner,capability,comparison,version) values(?,?,?,?)')
    @stmt_insert_into_provide_tbl =
      @db.prepare('insert into provide_tbl (owner,capability,comparison,version) values(?,?,?,?)')

    # for delete_cache()
    @stmt_delete_from_buildreq_tbl =
      @db.prepare('delete from buildreq_tbl where owner == ?')
    @stmt_delete_from_package_tbl =
      @db.prepare('delete from package_tbl where owner == ?')
    @stmt_delete_from_require_tbl =
      @db.prepare('delete from require_tbl where owner == ?')
    @stmt_delete_from_provide_tbl =
      @db.prepare('delete from provide_tbl where owner == ?')

    # for delete_list()
    @stmt_delete_from_specfile_tbl =
      @db.prepare('delete from specfile_tbl where id == ?')

  end

  def close
    # for update_list()
    @stmt_select_count_id_from_specfile_tbl.close
    @stmt_insert_or_ignore_into_specfile_tbl.close
    @stmt_select_id_from_specfile_tbl.close
    @stmt_update_specfile_tbl.close

    @stmt_insert_into_buildreq_tbl.close
    @stmt_insert_into_package_tbl.close
    @stmt_insert_into_require_tbl.close
    @stmt_insert_into_provide_tbl.close

    # for delete_cache()
    @stmt_delete_from_buildreq_tbl.close
    @stmt_delete_from_package_tbl.close
    @stmt_delete_from_require_tbl.close
    @stmt_delete_from_provide_tbl.close

    # for delete_list()
    @stmt_delete_from_specfile_tbl.close

    super()
  end

  def check(opts = nil)
    opts = @options if nil==opts
    sql = 'select capability from package_tbl group by capability having count(*) > 1'
    @db.execute(sql) do |cap,|
      STDERR.puts "WARNING: Duplicate entries found; These specfiles below conflict on \"#{cap}\""
      sql = 'select name FROM package_tbl INNER JOIN specfile_tbl ON owner==id WHERE capability=?'
      @db.execute(sql,[cap]) do |name,|
        STDERR.puts " #{name}"
      end
    end
  end

  def delete_list(list, opts = nil)
    opts = @options if nil==opts

    begin
      @db.transaction
      list.each { |name,|
        STDERR.puts "deleting entry for #{name}" if (opts[:verbose]>-1) 
        id = @stmt_select_id_from_specfile_tbl.get_first_value([name]).to_i
        if nil != id then
          delete_cache(id)
          @stmt_delete_from_specfile_tbl.execute!([id])
        end
      }
      @db.commit
    rescue => evar
      STDERR.puts "err #{evar}"
      @db.rollback
    end
  end
  
  def update_list(list, opts = nil)
    opts = @options if nil==opts
    begin
      @db.transaction
      list.each { |sn|
        specname=sn.encode(Encoding::ASCII)
        filename="#{specname}/#{specname}.spec"
        filename.encode!(Encoding::ASCII)

        # We should check timestamps both of directory and specfile so
        # that database will be updated whenever the special files
        # such as SKIP are created or removed.
        timestamp1 = File.mtime(specname).to_i
        timestamp2 = File.mtime(filename).to_i
        timestamp = timestamp1>timestamp2 ? timestamp1 : timestamp2

        if !opts[:force_update] then
          count = @stmt_select_count_id_from_specfile_tbl.get_first_value([specname,timestamp]).to_i
          if  count == 1  then
            STDERR.puts "skip #{specname}" if (opts[:verbose]>0) 
            next
          end
        end

        spec = nil
        begin 
          # RPM::Spec will crash when RPM.readrc() is not called.
          RPM.readrc('/usr/lib/rpm/momonga/rpmrc:./rpmrc:./dot.rpmrc')
          
          spec = RPM::Spec.open(filename)
        rescue => evar
          STDERR.puts "WARNING: #{evar}"
        end
        if spec.nil? then
          STDERR.puts "skip #{filename}" if (opts[:verbose]>-1)
          next
        end
        STDERR.puts "updating entry for #{specname}" if (opts[:verbose]>-1) 
        
        # create spec entry
        @stmt_insert_or_ignore_into_specfile_tbl.execute!([specname])
        id = @stmt_select_id_from_specfile_tbl.get_first_value([specname]).to_i
        # update timestamp
        @stmt_update_specfile_tbl.execute!([timestamp, specname])
        # delete old datas
        delete_cache(id)

#        if File.exist?("#{specname}/OBSOLETE") or
#            File.exist?("#{specname}/.SKIP") or
#            File.exist?("#{specname}/SKIP") then
#          next
#        end

        # create new datas
        spec.buildrequires.each {|cap|
          name, op, ver = cap.conv
          @stmt_insert_into_buildreq_tbl.execute!([id, name, op, ver])
        }      
        
        spec.packages.each {|pkg|
          # add package_tbl entry
          name = pkg.name
          ver  = pkg.version.nil? ? 'NULL' : "#{pkg.version}"
          name.encode!(Encoding::ASCII)
          ver.encode!(Encoding::ASCII)
          @stmt_insert_into_package_tbl.execute!([id, name, '==', ver])
          
          # add require_tbl entry
          pkg.requires.each {|cap|
            name, op, ver = cap.conv
            @stmt_insert_into_require_tbl.execute!([id, name, op, ver])
          }
          
          # add provide_tbl entry	
          pkg.provides.each {|cap|
            name, op, ver = cap.conv
            @stmt_insert_into_provide_tbl.execute!([id, name, op, ver])
          }
        }
        spec = nil
      }

      @db.commit
    rescue => evar
      STDERR.puts "err #{evar}"
      @db.rollback
    end
  end
  
  private  
  def delete_cache(id)
    @stmt_delete_from_buildreq_tbl.execute!([id])
    @stmt_delete_from_package_tbl.execute!([id])
    @stmt_delete_from_require_tbl.execute!([id])
    @stmt_delete_from_provide_tbl.execute!([id])
  end

end  # end of class SpecDB
