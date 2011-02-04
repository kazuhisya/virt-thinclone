#!/usr/bin/ruby
require 'libvirt'
require 'optparse'
require 'rexml/document'
#require 'guestfs'

# Virt-ThinProvisioning
# clone VM and setting NewVM's Network device
#
# Copyright (c) 2011 Kazuhisa Hara (https://github.com/kazuhisya)
#
# Released under an GPLv2+
#
# Usage: virt-thinpro [options]
#     -o, --original <name>            Original Domain Name: Necessary
#     -n, --new <name>                 New Domain Name: Necessary
#     -i, --ip <ip>                    New Domain IP: Necessary
#     -m, --mask <netmask>             New Domain NetMask: Default 255.255.255.0
#     -g, --gate <gateway>             New Domain DefaultGateway: Default 192.168.0.1
#     -p, --partition <partition>      Dom root Partition Name: Default /dev/mapper/VolGroup-lv_root
#     -s, --snap <snapshot>            New Dom Fast Snapshot Name: Default provisioning_default

### Default Config
qemu_img = "/usr/bin/qemu-img"
virt_clone = "/usr/bin/virt-clone"
guestfish = "/usr/bin/guestfish"
tmp = "/tmp/virt-thinpro"

guest_mask = "255.255.255.0"
guest_gate = "192.168.0.1"
guest_root_part = "/dev/mapper/VolGroup-lv_root"
snap_name = "provisioning_default"
###


OPTIONS = {
}

ARGV.options do |opts|
  opts.on("-o", "--original <name>", "Original Domain Name: Necessary") {|org_dom|
    OPTIONS[:org_dom] = org_dom
  }

  opts.on("-n", "--new <name>", "New Domain Name: Necessary") {|new_dom|
    OPTIONS[:new_dom] = new_dom
  }

  opts.on("-i", "--ip <ip>", "New Domain IP: Necessary") {|new_dom_ip|
    OPTIONS[:new_dom_ip] = new_dom_ip
  }

  opts.on("-m", "--mask <netmask>", "New Domain NetMask: Default #{guest_mask}") {|new_dom_mask|
    OPTIONS[:new_dom_mask] = new_dom_mask
    unless OPTIONS[:new_dom_mask].nil?
      guest_mask = OPTIONS[:new_dom_mask]
    end
  }

  opts.on("-g", "--gate <gateway>", "New Domain DefaultGateway: Default #{guest_gate}") {|new_dom_gate|
    OPTIONS[:new_dom_gate] = new_dom_gate
    unless OPTIONS[:new_dom_gate].nil?
      guest_gate = OPTIONS[:new_dom_gate]
    end
  }

  opts.on("-p", "--partition <partition>", "Dom root Partition Name: Default #{guest_root_part}") {|new_dom_part|
    OPTIONS[:new_dom_part] = new_dom_part
    unless OPTIONS[:new_dom_part].nil?
      guest_root_part = OPTIONS[:new_dom_part]
    end
  }

  opts.on("-s", "--snap <snapshot>", "New Dom Fast Snapshot Name: Default #{snap_name}") {|new_dom_snap|
    OPTIONS[:new_dom_snap] = new_dom_snap
    unless OPTIONS[:new_dom_snap].nil?
      snap_name = OPTIONS[:new_dom_snap]
    end
  }

  opts.parse!
end


if OPTIONS[:org_dom] and OPTIONS[:new_dom] and OPTIONS[:new_dom_ip] then
  begin

    # create tmp dir
    unless File.exists?(tmp)
      Dir::mkdir(tmp)
    end

    # connect libvirt
    conn = Libvirt::open("qemu:///system")

    # lookup org vm
    org_vm = conn.lookup_domain_by_name(OPTIONS[:org_dom])

    # org dump xml
    org_source = org_vm.xml_desc

    # search org disk path and type
    org_doc = REXML::Document.new org_source 
    org_disk_path = org_doc.elements["/domain/devices/disk[@device='disk']/source"].attributes["file"]
    org_disk_type = org_doc.elements["/domain/devices/disk[@device='disk']/driver"].attributes["type"]

    # make new disk file path
    new_disk_path = File::dirname(org_disk_path) + "/" + OPTIONS[:new_dom] + ".img"
    new_disk_type = org_disk_type
    create_disk_cmd = "#{qemu_img} create -b #{org_disk_path} -f #{org_disk_type} #{new_disk_path}"

    # create new disk
    #p create_disk_cmd
    create_new_disk = system(create_disk_cmd)

    # do virt-clone
    clone_cmd = "#{virt_clone} -o #{OPTIONS[:org_dom]} -n #{OPTIONS[:new_dom]} -f #{new_disk_path} --preserve-data"
    #p clone_cmd
    do_virt_clone = system(clone_cmd)

    # lookup new vm
    new_vm = conn.lookup_domain_by_name(OPTIONS[:new_dom])

    # new dump xml
    new_source = new_vm.xml_desc

    # search new disk path and type
    new_doc = REXML::Document.new new_source
    new_mac = new_doc.elements["/domain/devices/interface/mac"].attributes["address"]
    new_uuid = new_doc.elements["/domain/uuid"].text

    # make new ifcfg-eth0 file
    if_file_path = "#{tmp}/#{OPTIONS[:new_dom]}_ifcfg-eth0.txt"

    if_file = File.open(if_file_path,'w')
    if_file.puts 'DEVICE="eth0"'
    if_file.puts "HWADDR=\"#{new_mac}\""
    if_file.puts 'ONBOOT="yes"'
    if_file.puts 'BOOTPROTO="static"'
    if_file.puts "IPADDR=\"#{OPTIONS[:new_dom_ip]}\""
    if_file.puts "NETMASK=\"#{guest_mask}\""
    if_file.puts "GATEWAY=\"#{guest_gate}\""
    if_file.close
    #p if_file

    # make new udev file
    udev_file_path = "#{tmp}/#{OPTIONS[:new_dom]}_70-presistent-net.rules.txt"

    udev_file = File.open(udev_file_path,'w')
    udev_file.puts "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"#{new_mac}\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth0\""
    udev_file.close
    #p udev_file


    # edit guest file system
    edit_new_disk_cmd = "#{guestfish} add #{new_disk_path} : run : mount #{guest_root_part} / : \
      upload #{if_file_path} /etc/sysconfig/network-scripts/ifcfg-eth0 : \
      upload #{udev_file_path} /etc/udev/rules.d/70-presistent-net.rules : \
      sync : umount-all : quit "

    #p edit_new_disk_cmd
    edit_new_disk = system(edit_new_disk_cmd)

    ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
    ### if you use ruby-libguestfs (not works yet!) //start
    #g = Guestfs::Guestfs.new()
    #g.add_drive_opts(new_disk,:readonly => 0, :format => new_disk_type)
    #g.run()
    #g.mount_options("", guest_root_part, "/")
    #g.upload(if_file_path, "/etc/sysconfig/network-scripts/ifcfg-eth0")
    #g.upload(udev_file_path, "/etc/udev/rules.d/70-presistent-net.rules")
    #g.sync()
    #g.close()
    ### end //
    ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###


    # create new vm snapshot
    snap_doc = REXML::Document.new
    snap_xml = snap_doc.add_element("domainsnapshot")
    snap_xml.add_element("name").add_text "#{snap_name}"
    snap_xml.add_element("state").add_text "shutoff"
    snap_xml.add_element("domain").add_element("uuid").add_text "#{new_uuid}"
    #p snap_doc.to_s

    create_snapshot = new_vm.snapshot_create_xml(snap_doc.to_s)


  rescue => ex
    abort("Error #{ex.message}")
  else
    puts  "Success: #{OPTIONS[:new_dom]}"
  ensure
    unless conn.nil?
      conn.close
    end
  end
else
  abort("Help: virt-thinpro.rb -h")
end

