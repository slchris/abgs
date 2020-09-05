#!/bin/bash

set -x
# clean systems
function cleansys(){
    sudo rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc
    docker rmi $(docker images -q)
    sudo apt-get -y purge \
         azure-cli \
         ghc* \
         zulu* \
         hhvm \
         llvm* \
         firefox \
         google* \
         dotnet* \
         powershell \
         openjdk* \
         mysql* \
         php* 2&> /dev/null
    sudo apt autoremove --purge -y 2&> /dev/null
    [ -f sources.list ] && (
        sudo cp -rf sources.list /etc/apt/sources.list
        sudo rm -rf /etc/apt/sources.list.d/* /var/lib/apt/lists/*
        sudo apt-get clean 2&> /dev/null
    )
    sudo apt-get update 2&> /dev/null
    sudo apt install wget curl rsync xz-utils tar git -y 2&> /dev/null
    sudo apt autoremove --purge -y 2&> /dev/null
    sudo apt-get clean 2&> /dev/null
    sudo timedatectl set-timezone Asia/Shanghai    
}
# download stage3 file
function download(){
    sudo mkdir -pv /mnt/gentoo
    MIRRORS='https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds'
    ZIPFILENAME=`curl -L $MIRRORS/latest-stage3.txt |grep ^[0-9] |awk -F '[/ ]'  '{if (NR==1) {print $2}}'`
    FILENAME=`curl -L $MIRRORS/latest-stage3.txt  2>/dev/null |grep ^[0-9]|awk '{if (NR==1) {print $1}}'`
    FILEURL="$MIRRORS/$FILENAME"
    sudo wget -O /mnt/gentoo/$ZIPFILENAME $FILEURL > /tmp/download.log    
}

function pre-stage3(){
    cd /mnt/gentoo	
    sudo tar xJpf stage3-amd64-*.tar.xz --xattrs-include='*.*' --numeric-owner
    sudo rm -rf *.tar.xz
    cd -
}

function _test(){

    echo "test" >test.log
    tar -jcf test.tar.bz2 test.log

}

function _stage_portage(){
    git clone https://github.com/slchris/stage1
    sudo cp -v stage1/etc/portage/make.conf /mnt/gentoo/etc/portage/make.conf
    sudo mkdir -pv /mnt/gentoo/etc/portage/repos.conf
    sudo cp -v ./stage1/etc/portage/repos.conf/gentoo.conf /mnt/gentoo/etc/portage/repos.conf
    sudo cp -rv ./stage1/etc/portage/package.use/ /mnt/gentoo/etc/portage
    sudo cp -rv ./stage1/etc/portage/env /mnt/gentoo/etc/portage
    sudo cp -rv ./stage1/etc/portage/package.env/ /mnt/gentoo/etc/portage
    sudo cp -v ./stage1/etc/fstab /mnt/gentoo/etc/fstab
    sudo cp -v ./stage1/bootstrap.sh /mnt/gentoo/root/bootstrap.sh
}
function _chroot(){
    sudo cp -v -L /etc/resolv.conf /mnt/gentoo/etc/
    sudo mount -v -t proc none /mnt/gentoo/proc
    sudo mount -v --rbind /sys /mnt/gentoo/sys
    sudo mount -v --rbind /dev /mnt/gentoo/dev
    sudo mount -v --make-rslave /mnt/gentoo/sys
    sudo mount -v --make-rslave /mnt/gentoo/dev
    sudo test -L /dev/shm &&  sudo rm /dev/shm &&  sudo mkdir /dev/shm
    sudo mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm
    sudo chmod 1777 /dev/shm
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;mount -a"    
}

function _bootstrap(){
    sudo chroot /mnt/gentoo /bin/bash -c  "source /etc/profile;mkdir -pv /var/db/repos/gentoo; "
    sudo chroot /mnt/gentoo /bin/bash -c "wget -qO- https://github.com/gentoo-mirror/gentoo/archive/stable.tar.gz | tar zx --directory /var/db/repos/gentoo --strip-component=1"
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;mkdir -pv /var/tmp/notmpfs"
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;echo "Asia/Shanghai" > /etc/timezone"
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;emerge -v --config sys-libs/timezone-data"
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen"
    sudo chroot /mnt/gentoo /bin/bash -c  "source /etc/profile;echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gent"
    sudo chroot /mnt/gentoo /bin/bash -c  "source /etc/profile;locale-gen"
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;eselect locale set  3"	
    sudo chroot /mnt/gentoo /bin/bash -c "source /etc/profile;cd /root; curl -LO https://raw.githubusercontent.com/slchris/stage1/master/script/bootstrap.sh ; bash /root/bootstrap.sh"
    
}


function _clean_stage_file(){
    sudo rm -rf /mnt/gentoo/var/db/repos/gentoo/*
    sudo rm -rf /mnt/gentoo/var/cache/distfiles/*
    sudo rm -rf /mnt/gentoo//var/cache/binpkgs/*
}
function _build_stage_tar(){
    sudo mkdir -pv gentoo out
    cd gentoo 
    sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /mnt/gentoo/* .
    sudo tar -jcf ../out/stage3.tar.bz2 .    
}

function auto(){
    cleansys
    download
    pre-stage3
    _stage_portage    
    _chroot
    _bootstrap
    _clean_stage_file    
    _build_stage_tar
}

$@
