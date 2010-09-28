#!/usr/bin/env ruby
require 'stringio'

# This class is used to apply patches generated by IDA
# enhanced with an extra YAML-ized hash of patch directives.
class Patchy
  def initialize(opts={})
    @force = opts[:force]
    @dryrun = opts[:dryrun]
  end

  def read_dif(patch_io)
    patch_io = StringIO.new(patch_io) if patch_io.is_a? String
    @fname = @extra_yaml = @diffs = nil

    # first line is a comment followed by blank line
    comment = patch_io.readline.chomp

    #followed by a blank line
    unless patch_io.readline.chomp.empty?
      raise("format error, expected blank line after comment")
    end

    # next line is the filename to patch according to IDA
    @fname = patch_io.readline.chomp

    # next comes the byte-by-byte diffs from IDA
    @diffs = []
    until patch_io.eof? or (line = patch_io.readline.chomp) == "%%YAML%%"
      if /^([a-z0-9]+): ([a-z0-9]{2}) ([a-z0-9]{2})/i.match(line)
        @diffs << $~[1..3].map{|x| x.hex }
      else
        # ignore
      end
    end

    # if we have an extra YAML section, pull that in as well
    if line == "%%YAML%%"
      @extra_yaml = YAML.load(patch_io.read)
    end
  end

  def patch_from_dif_file(dif, infile=nil, outfile=nil)
    File.open(dif, "r"){|f| patch_from_dif(f)}
  end

  def patch_from_dif(patch_io, infile=nil, outfile=nil)
    read_dif(patch_io)

    infile ||= @fname
    output ||= infile

    puts "Patching file: #{infile}"
    target = File.open(infile, "rb"){|f| f.bytes.to_a }

    # Apply IDA DIF patches
    @diffs.each { |off, orig, newval| patch_byte(target, off, orig, newval) }

    if @extra_yaml
      patch_extra(target, @extra_yaml)
    end

    out_dat = target.pack("C*")
    puts "Writing changes to #{output}: #{out_dat.size} bytes"
    File.open(output, "wb"){|f| f.write out_dat} unless @dryrun
  end

  def patch_byte(target, off, orig, newval)
    if (b=target[off]) == orig or @force
      puts "Patching DIF byte @ 0x%x 0x%0.2x -> 0x%0.2x" % [off, target[off], newval]
      target[off] = newval
    elsif b == newval
      warn "INFO: Skipping byte @0x%0.2x - looks like it is already patched from dif file: %0.2x == %0.2x" % [off, b, newval]
    else
      # ignore patches that don't match the original but flag it
      warn "WARNING: Skipping byte @0x%0.2x - original does not match dif file: %0.2x != %0.2x" % [off, b, orig]
    end
  end

      
  def patch_extra(target, dif_hash)
    dif_hash.each do |key, param|
      unless off=param["offset"]
        raise "no offset specified for #{key}"
      end

      case typ=param["type"]
      when "string"
        if d=param["value"]
          dat = d.dup
          dat << "\x00" if param["zterm"]
          desc = dat.inspect
        else
          raise "string type #{key} must have a value"
        end
      when "number"
        unless fmt = param["format"]
          raise "number directive for #{key} requires a format"
        end

        if v=param["value"]
          dat = [v].pack(fmt)
          desc = v
        elsif tag=param["size_of"] and r=dif_hash[tag.to_s] and v=r["value"]
          dat = [v.size].pack(fmt)
          desc = v.size
        else
          raise "invalid dif directives for #{key}"
        end
      else
        raise "unknown type #{type} for #{key}"
      end

      puts "Patching #{key} @ 0x%x #{typ}: #{target[off,dat.size].pack("C*").inspect} -> #{desc}" % off
      target[off, dat.size] = dat.bytes.to_a
    end

    return target
  end

end

if __FILE__ == $0
  if ARGV.include?("-h") or (patch_dif = ARGV.shift).nil?
    STDERR.puts "Usage: #{File.basename $0} patch.dif [input] [output]"
    STDERR.puts "  * Input file is patched in-place unless output is specified."
    STDERR.puts "  * If no input file is specified, the file is found in patch.dif."
    exit 1
  end

  input = ARGV.shift
  output = ARGV.shift

  patcher = Patchy.new

  patcher.patch_from_dif_file(patch_dif, input, output)

end
