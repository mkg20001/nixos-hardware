{
  stdenv,
  raw_disk_image,
  utillinux,
}:

stdenv.mkDerivation {
  name = "avf_image.tar.gz";

  nativeBuildInputs = [ utillinux ];
  preVM = ''
    cp ${raw_disk_image}/*.img img
    chmod +w img
    diskImage=img
  '';
  memSize = 4096 * 2;

  dontUnpack = true;
  dontBuild = true;
  installPhase = ''
    local root_partition_num=1
    local efi_partition_num=2

    echo ''${build_id} > build_id

    lsblk
    df -h .

    dd if="/dev/vda$root_partition_num" of=root_part
    dd if="/dev/vda$efi_partition_num" of=efi_part

    cp ${./vm_config.json} vm_config.json

    sed -i "s/{root_part_guid}/$(sfdisk --part-uuid /dev/vda $root_partition_num)/g" vm_config.json
    sed -i "s/{efi_part_guid}/$(sfdisk --part-uuid /dev/vda $efi_partition_num)/g" vm_config.json

    contents=(
    build_id
    root_part
    efi_part
    vm_config.json
    )

    # --sparse option isn't supported in apache-commons-compress
    tar czv -f $out -C . "''${contents[@]}"
  '';
}
