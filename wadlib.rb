require 'zlib'

module WadLib
  def self.check_deps
    ["tar", "xz"].each do |f| 
      `which #{f}`
      unless $?.exitstatus == 0
        raise "Error: you must install xz and tar in your path before using this script"
      end
    end
  end

  def self.z_inflate(string)
    Zlib::Inflate.inflate(string)
  end

  def self.z_deflate(string, *level)
    Zlib::Deflate.deflate(string, *level)
  end

  def self.dump_wad(io, dir, opts={})
    force = opts[:force]
    unless expand=opts[:inflate]
      puts "* WARNING: inflate is disabled. You can enable it with -x"
    end

    magic = io.read(4)
    if magic != "BBBB" and not force
      raise "error: this doesn't look like a wad file"
    end

    total_len = io.read(4).unpack('V').first
    dylib_len = io.read(4).unpack('V').first

    if total_len < dylib_len+12 and not force
      raise "invalid chunk lengths, aborting"
    end

    # extract the first blob, install.dylib.zstream
    dl_chunk = io.read(dylib_len)

    # extract the second blob, fs.tar.xz
    fs_chunk = io.read(total_len - dylib_len - 12)

    if not io.eof? and not force
      raise "woops, unexpected extra data. Aborting"
    end

    Dir.mkdir(dir)

    dl_fname = "#{dir}/install.dylib"
    # the install.dylib blob should be zlib deflated data
    # if so, we'll inflate it 
    if dl_chunk[0,2] == "\x78\x9c"
      if expand
        puts "* Inflating install.dylib chunk"
        dl_chunk = z_inflate(dl_chunk)
      else
        dl_fname << ".zstream"
      end
    else
      puts "* WARN: Expected a deflated blob for install.dylib, but didn't get one"
      dl_fname << ".???"
    end

    puts "* Writing #{dl_chunk.size} bytes to #{dl_fname}"
    File.open(dl_fname, "w"){|f| f.write(dl_chunk) }

    xzpath=`which xz`.chomp
    ret1 = $?
    tarpath=`which xz`.chomp
    ret2 = $?

    fs_fname = "#{dir}/fs.tar"

    if fs_chunk.index("\xFD7zXZ\x00") == 0
      puts "* Detected XZ compressed filesystem"
      fs_fname << ".xz"
    else
      puts "* WARN: Expected XZ compressed filesystem but didn't get one"
      fs_fname << ".???"
    end


    if( expand and fs_fname =~ /\.xz$/ and ret1.exitstatus == 0 and ret1.exitstatus == 0 )
      puts "* Extracting jailbreak filesystem in #{dir}/fs/"
      Dir.mkdir "#{dir}/fs"
      Dir.chdir "#{dir}/fs"

      # save a manifest so we have a reference for permissions and owners
      pipe = IO.popen("xz -cd --force - | tar -ptvf - > ../fs_manifest.txt", "w") do |pipe|
        pipe.write fs_chunk
      end

      # now ... extract the filesystem
      pipe = IO.popen("xz -cd --force - | tar -pxf - ", "w") do |pipe|
        pipe.write fs_chunk
      end
    else
      # user either didn't say -x or we don't have the utilities in our path
      puts "* Writing #{fs_chunk.size} bytes to #{fs_fname}"
      File.open(fs_fname, "w"){|f| f.write(fs_chunk) }
    end
    return true
  end

  def self.pack_wad(dir, outfile)
    origdir = Dir.pwd
    Dir.chdir(dir)

    puts "* Compressing install.dylib"
    if File.exists?("install.dylib")
      dl_data = z_deflate(File.read("install.dylib"))
    elsif File.exists?("install.dylib.zstream")
      dl_data = File.read("install.dylib.zstream")
    else
      raise "!!! Error: No install.dylib found. abort!"
    end


    if File.directory?('fs')
      Dir.chdir("fs")
      puts "* TAR+XZ Compressing filesystem directory 'fs'"
      fs_data = `tar -pcvf - * | xz -cz`

    elsif File.exists?("fs.tar")
      puts "* Found fs.tar for filesystem. Compressing it with XZ"
      fs_data =`xz -cz fs.tar`

    elsif File.exists?("fs.tar.xz")
      puts "* Found fs.tar.xz. Using for as-is for filesystem"
      fs_data = File.read("fs.tar.xz")

    else
      raise "!!! Error: No filesystem found. abort!"

    end

    Dir.chdir origdir

    puts "* Creating wad.bin bundle"
    len = nil
    File.open(outfile, "wb"){|f|
      len=f.write [
        "BBBB", 
        [dl_data.size + fs_data.size + 12, dl_data.size].pack("VV"),
        dl_data,
        fs_data
      ].join
    }
    puts "* Finished: Wrote #{len} bytes to #{outfile}"
  end

end
