
======================================================================
== What is this?
======================================================================

I'm making this readme and the associated tools available for posterity/historic sake in reference to my talk at ekoparty 2010. There may even be a few useful tools that came out of this like patchy.rb or ida_patcher I may resurrect at some point down the road.

This is a collection of tools that were written in the process of reverse-engineering the jailbreakme.com (star) exploit by comex in the week or so following it's original release. They are all but totally useless now after comex released the source (see github.com/comex/star and github.com/emonti/star).


======================================================================
== What's included?
======================================================================

* origami-1.0.0.gem 
  I bundled up origami as a gem after making a few small fixes to 1.0.0-beta2. I didn't include 'walker' in this so dont worry about having gtk2 installed. You can still use walker against this lib though. You'll need to install this gem in order to use extract_payload, or ls_pdf.

* extract_font_payload:
  Extracts the CFF Font exploit payload from a JailBreakMe PDF. This blob also contains two mach-o object chunks (see split_payload).

* bundle_payload:
  Bundles up a pdf based on the original jailbreak pdf, but with arbitrary data for the CFF Font exploit payload.

* split_payload:
  Extracts the shellcode and 2 Mach-O objects from the font payload. The font payload must already be extracted from the PDF as a binary blob. (see extract_font_payload which is more complete steps from a-z)

* unpack_wad:
  Extracts the compressed contents of the wad.bin file including the jailbreak filesystem tarball. Ensure you have xz and tar in your path for full effect

* repack_wad:
  Repacks the wad file from a directory structure produced by unpack_wad after you have made modifications.

* wadlib.rb
  A class for dealing with the jailbreak wad files. Used by unpack_wad and repack_wad REQUIREMENT! get xz  at http://tukaani.org/xz/ (on OS X, I recommend: "sudo port install xz-devel")

* patchy.rb
  A class for applying IDA *.DIF files to binaries. Supports additional dynamic dif features through an optional extra %%YAML%% section in the DIF file. Usable as a library as well as a standalone script.

* ida_patcher
  A basic IDA *.DIF patcher with no frills.


=== Misc stuff:

* macho_hdr_dump:
  Quick/crappy mach-o info dumper. Uses a combination of several tools, including otool and objdump(cross-toolchain) if you have them. Otherwise just gives you a dump with a few header values.

* ls_pdf: 
  Kinda lame. Lazily dumps all the objects in a pdf using pretty-print on origami's PDF.ls results.

* z_inflate, z_deflate
  Command-line interfaces to the Zlib::Inflate and Zlib::Deflate Compression routines.

=== Also handy:

* class-dump (for all-round useful dumping objc class/mach-o header info)
    http://www.codethecode.com/projects/class-dump/ ("port install class-dump" on OS X)


======================================================================
== Synopsis
======================================================================

Below is a high-level usage summary of how the tools were intended to be used together.

=== For the phase-1 pdf exploit payloads:

1. Extract a payload file from one or more of the jailbreakme pdfs using 
   extract_font_payload (accepts wildcards). you will end up with a directory 
   called dump_*/ for each file you extract.

2. Use split_payload to split the exploit payload into components. This will
   produce *.egg (the CFF font exploit payload), *.macho_1 (embedded 
   jailbreaking program), *.macho_2 (not 100% sure, but i think this is 
   the IOKit exploit to break out of the sandbox)

3. Make modifications as necessary. Spend "some quality" time with IDA or your
   favorite ARM disassembler. If you are going the patching route, ida_patcher and/or 
   patchy.rb are probably helpful.

4. Once ready, re-roll your PDF using bundle_payload. This just takes a pdf filename to
   output followed by one or more files to concatenate in the payload.

5. Profit?

=== For the wad.bin file:

1. Fully unpack the original wad.bin file from jailbreakme.com using unpack_wad -x.

2. Make modifications as necessary. WARNING, some landmines may be present if from the phase-1 PDF exploit payload unless you've patched/modified them out. In other words some things may not be good to delete unless you've done some groundwork.

3. When ready, re-roll your own wad.bin file using repack_wad.



