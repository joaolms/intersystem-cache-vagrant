#!/usr/bin/env bash
#
#       Linux and Database Configuration

# Source function library to use the echo_success and echo_failure functions.
. /etc/init.d/functions

SHIFTPHRASEMOD="### Custom ###"
CACHEUSER="cacheusr"
CACHEGROUP=${CACHEUSER}
PS1='PS1="[\[\033[1;31m\]\u\[\033[0m\]]@[\[\033[1;32m\]\H\[\033[0m\]]:[\W]\\$ "'
RENDERSERVERMEMSIZE="2048m"

DOSPACESHIFTPKG="https://shiftpkg.nyc3.digitaloceanspaces.com"

# Functions

changePS1() {
    # Check PS1 variable
    if [[ $(grep -Es ^PS1 /etc/skel/.bashrc) ]]; then
        echo -e "PS1 variable already defined"
    else
        echo -e "Including PS1 variable in /etc/skel/.bashrc file"
        echo ${SHIFTPHRASEMOD} >> /etc/skel/.bashrc
        echo $PS1 >> /etc/skel/.bashrc
    fi
}

changeLimitsconf() {
    sysctlNoFile="/etc/security/limits.d/${CACHEUSER}-nofile.conf"
    if [ -f ${sysctlNoFile} ]; then
        echo -e "Kernel parameter nofile already defined"
    else
        echo -e "Setting kernel parameter nofile to 10240 at ${CACHEUSER} user spaces"
        echo ${CACHEUSER} soft nofile 10240 > ${sysctlNoFile}
        echo ${CACHEUSER} hard nofile 10240 >> ${sysctlNoFile}
    fi

    sysctlNproc="/etc/security/limits.d/${CACHEUSER}-nproc.conf"
    if [ -f ${sysctlNproc} ]; then
        echo -e "Kernel parameter nproc already defined"
    else
        echo -e "Setting kernel parameter nproc to unlimited at ${CACHEUSER} user spaces"
        echo ${CACHEUSER} soft nproc unlimited >> ${sysctlNproc}
        echo ${CACHEUSER} hard nproc unlimited >> ${sysctlNproc}
    fi
}

changeProfileFile() {
    [ -z "${HISTTIMEFORMAT}" ] && \
        if [[ $(grep -s HISTTIMEFORMAT /etc/profile) ]]; then
            echo -e "Environment variable HISTTIMEFORMAT is defined"
        else
            echo -e "Setting the HISTTIMEFORMAT variable in /etc/profile"
            echo 'export HISTTIMEFORMAT="%F %T "' >> /etc/profile
        fi \
    || echo "Environment variable HISTTIMEFORMAT already defined"
}

sendEmailPkgInstall() {
    echo -e "SSL Packages"
    yum install -y -q \
        perl-Net-SSLeay \
        perl-IO-Socket-SSL \
        perl-Crypt-SSLeay \
        openssl \
        pyOpenSSL \
        gnutls-utils &> /dev/null
}

downloadCache() {
    cd /inst
    CACHEFILENAME="cache-2018.1.4.505.1-lnxrhx64.tar.gz"
    md5OK="80e292316d5866961c04dafd3eaef6e7"

    if [ -f ${CACHEFILENAME} ]; then
        echo -e "MD5SUM on ${CACHEFILENAME}"
        md5CachePkg=$(md5sum ${CACHEFILENAME} | cut -d" " -f1)
        while [[ ${md5OK} != ${md5CachePkg} ]]; do
            echo -e "Cache Package is corrupted. Downloading it again"
            rm -f {CACHEFILENAME}
            curl -fsL -o ${CACHEFILENAME} ${DOSPACESHIFTPKG}/intersystems/${CACHEFILENAME}
        done
        echo "File ${CACHEFILENAME} already locally"
    else
        echo -e "Cache Download"
        cd /inst/
        curl -fsL -o ${CACHEFILENAME} ${DOSPACESHIFTPKG}/intersystems/${CACHEFILENAME}
        md5CachePkg=$(md5sum ${CACHEFILENAME} | cut -d" " -f1)
        while [[ ${md5OK} != ${md5CachePkg} ]]; do
            echo -e "Cache Package is corrupted. Downloading it again"
            rm -f {CACHEFILENAME}
            curl -fsL -o ${CACHEFILENAME} ${DOSPACESHIFTPKG}/intersystems/${CACHEFILENAME}
        done
    fi
    echo -e "Descompactando Cache"
    mkdir -p /inst/cache/
    tar xzf ${CACHEFILENAME} -C /inst/cache/ &> /dev/null
}

extrasPackages() {
    yum install -y -q\
        vim \
        unzip \
        xz \
        tmux \
        nfs-utils &> /dev/null
}

cacheInstall() {
    which ccontrol &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Cache instance already Installed"
    else
        echo -e "Installing InterSystems Cache"
        export RENDERSERVERMEMSIZE=${RENDERSERVERMEMSIZE}
        yum -y -q install krb5-libs krb5-devel
        downloadCache
        cd /inst/cache/${CACHEFILENAME%.tar.gz}
        ISC_PACKAGE_INSTANCENAME="CACHE" \
        ISC_PACKAGE_INSTALLDIR="/binario" \
        ISC_PACKAGE_UNICODE="Y" \
        ISC_PACKAGE_INITIAL_SECURITY="Locked Down" \
        ISC_PACKAGE_CACHEUSER="cacheusr" \
        ISC_PACKAGE_CACHEGROUP="cacheusr" \
        ISC_PACKAGE_MGRUSER="cacheusr" \
        ISC_PACKAGE_MGRGROUP="cacheusr" \
        ISC_PACKAGE_USER_PASSWORD='superuser123' \
        ISC_PACKAGE_CSPSYSTEM_PASSWORD='S3nh@T3mp02' \
        ISC_PACKAGE_CSP_CONFIGURE="N" \
        ISC_PACKAGE_STARTCACHE="Y" \
        ISC_INSTALLER_PARAMETERS="SuperServerPort=56772,WebServerPort=57772,UsersFile=/inst/cacheusers.xml,InstanceSystemMode=DEVELOPMENT"\
        ISC_INSTALLER_MANIFEST="/inst/CacheDefault.xml" \
        ./cinstall_silent && \
        cd /inst
    fi
}

createUsers() {
    echo -e "Adding group ${CACHEGROUP}"
    [[ $(grep -s ${CACHEGROUP} /etc/group) ]] || groupadd ${CACHEGROUP} &> /dev/null

    if ( id ${CACHEUSER} &> /dev/null ); then
        echo -e "User ${CACHEUSER} already exists"
    else
        echo -e "Adding user ${CACHEUSER}"
        useradd -m -d /home/${CACHEUSER}/ -s /bin/bash -g ${CACHEGROUP} ${CACHEUSER} &> /dev/null
    fi
}

timezoneConfig() {
    timedatectl set-timezone America/Sao_Paulo
}

sshSecurity() {
    echo -e "Deny SSH access to ${CACHEUSER} user"
    SSHDENIEDUSERS1=$(grep -Es ^DenyUsers /etc/ssh/sshd_config)
    
    # If DenyUsers directive is undefined, then define directive with ${CACHEUSER} user
    [ -z "${SSHDENIEDUSERS1}" ] && echo "DenyUsers ${CACHEUSER}" >> /etc/ssh/sshd_config && return 0

    # If DenyUsers directive is defined, verify if ${CACHEUSER} is within directive
    [ ! -z "${SSHDENIEDUSERS1}" ] && SSHDENIEDUSERS2=$(echo "${SSHDENIEDUSERS1}" | grep "${CACHEUSER}")
    [ -z "${SSHDENIEDUSERS2}" ] && AddOnDenyUsers=true || AddOnDenyUsers=false
    
    # Then, if ${CACHEUSER} not within directive, then add ${CACHEUSER} in the DenyUsers directive
    if [ ${AddOnDenyUsers} == true ]; then
        cp --force /etc/ssh/sshd_config /etc/ssh/sshd_config_bkp_$$
        sed -i "s/${SSHDENIEDUSERS1}/#${SSHDENIEDUSERS1}/g" /etc/ssh/sshd_config &> /dev/null
        echo ${SSHDENIEDUSERS1},${CACHEUSER} >> /etc/ssh/sshd_config
    fi
}

securityOff() {
    echo -e "Turn off SELINUX"
    setenforce 0 &> /dev/null
    sed -i 's/=enforcing/=disabled/g' /etc/selinux/config &> /dev/null

    echo -e "Turn off IPTABLES service"
    systemctl stop firewalld.service
    systemctl disable firewalld.service
}

sysctlConf() {
    echo -e 'Set vm.swappiness parameter to 10%'
    cp /etc/sysctl.conf /etc/sysctl.conf.bkp &> /dev/null
    [[ $(grep -E ^vm.swappiness /etc/sysctl.conf) ]] || echo 'vm.swappiness = 10' >> /etc/sysctl.conf 
    sysctl -p &> /dev/null

    # Verificar quantidade de memoria fisica e arredondar o valor considerando as opcoes no bloca CASE abaixo
    PHYMEMORY=$(free -g | grep 'Mem:' | tr -s '[:space:]' ' ' | cut -d " " -f2)

    # Aplicar as configuracoes do Huge Pages ao arquivo SYSCTL.CONF

    hugePagesConf() {
        sysctlFile="/etc/sysctl.conf"
        pshmmaxValue=$1
        pnrHugePagesValue=$2
        cp -fp ${sysctlFile} ${sysctlFile}.$$-bkp

        # kernel.shmmax
        if [[ $(grep -E ^kernel.shmmax=${pshmmaxValue}$ ${sysctlFile}) ]]; then
            echo -e "Shared Memory Max is correct"
        elif [[ $(grep -E ^kernel.shmmax ${sysctlFile}) ]]; then
            echo -e "Switching kernel.shmmax value from$(grep -E ^kernel.shmmax ${sysctlFile} | cut -d"=" -f2) to $(echo ${pshmmaxValue})"
            sed -E -i 's~^kernel.shmmax~#kernel.shmmax~g' ${sysctlFile}
            echo "kernel.shmmax=${pshmmaxValue}" >> ${sysctlFile}
        else
            echo -e "Setting kernel.shmmax parameter"
            echo "kernel.shmmax=${pshmmaxValue}" >> ${sysctlFile}
        fi
        sysctl -p > /dev/null

        # vm.nr_hugepages
        if [[ $(grep -E ^vm.nr_hugepages=${pnrHugePagesValue}$ ${sysctlFile}) ]]; then
            echo -e "Huge Pages value is correct"
        elif [[ $(grep -E ^vm.nr_hugepages ${sysctlFile}) ]]; then
            echo -e "Switching1' vm.nr_hugepages value from$(grep -E ^vm.nr_hugepages ${sysctlFile} | cut -d"=" -f2) to $(echo ${pnrHugePagesValue})"
            sed -E -i 's~^vm.nr_hugepages~#vm.nr_hugepages~g' ${sysctlFile}
            echo "vm.nr_hugepages=${pnrHugePagesValue}" >> ${sysctlFile}
        else
            echo -e "Setting vm.nr_hugepages parameter"
            echo "vm.nr_hugepages=${pnrHugePagesValue}" >> ${sysctlFile}
        fi
    }

    case $PHYMEMORY in
        [0-6])
            echo 'There is not enought memory to use Huge Page'
            ;;
        7|8|9|10)
            # Considerando 8GB
            shmmaxValue=6012954214
            nrHugePagesValue=2600
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        1[1-4])
            # Considerando 12GB
            shmmaxValue=9019431321
            nrHugePagesValue=4000
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        1[5-9] | 2[0-9])
            # Considerando 16GB
            shmmaxValue=12025908428
            nrHugePagesValue=5420
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        [3-4][0-9])
            # Considerando 32GB
            shmmaxValue=27487790694
            nrHugePagesValue=10650
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        [5-9][0-9])
            # Considerando 64GB
            shmmaxValue=53799121715
            nrHugePagesValue=22528
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        1[0-6][0-9])
            # Considerando 128GB
            shmmaxValue=107911849575
            vm.nr_hugepages=34040
            hugePagesConf ${shmmaxValue} ${nrHugePagesValue}
            ;;
        *)
            echo "Este servidor tem bastante memoria, ajustar manualmente o melhor valor de Huge Pages"
            ;;
    esac
}

fontExtra() {
    if [ ! -f "/usr/share/fonts/extra/arial.ttf" ]; then
        echo -e "Fonts extras: "
        mkdir /usr/share/fonts/extra/ &> /dev/null
        cd /usr/share/fonts/extra/ &> /dev/null
        curl -fsL -o extra.zip ${DOSPACESHIFTPKG}/requirements/extra.zip &> /dev/null
        unzip /usr/share/fonts/extra/extra.zip &> /dev/null
        fc-cache -f -v &> /dev/null
        cd /inst/
    else
        echo_success
    fi
}

fopInstall() {
    if [ ! -f "/usr/local/fop-2.4/fop/fop" ]; then
        cd /inst/pacotes/
        [[ $(grep -E RENDERSERVERMEMSIZE /etc/profile) ]] || echo export RENDERSERVERMEMSIZE=${RENDERSERVERMEMSIZE} >> /etc/profile
        echo -e "FOP Downlaod"
        curl -fsL -o fop-2.4-bin.tar.gz ${DOSPACESHIFTPKG}/requirements/fop-2.4-bin.tar.gz
        echo -e "Installing FOP"
        tar xzf fop-2.4-bin.tar.gz -C /usr/local
        chmod +x /usr/local/fop-2.4/fop/fop
        cd /inst/
    else
        echo -e "FOP already installed"
    fi
}

javaInstall() {
    if [ -f /usr/local/java/jre1.8.0_251/bin/java ]; then
        echo -e "Java already installed"
    else
        cd /inst/pacotes/
        mkdir /usr/local/java
        echo -e "Java Download"
        curl -fsL -o jre-8u251-linux-x64.tar.gz ${DOSPACESHIFTPKG}/requirements/jre-8u251-linux-x64.tar.gz
        tar xzf /inst/pacotes/jre-8u251-linux-x64.tar.gz -C /usr/local/java

        echo "" >> /etc/profile
        echo 'export JAVA_HOME="/usr/local/java/jre1.8.0_251"' >> /etc/profile
        echo 'export PATH="${PATH}:${JAVA_HOME}/bin"' >> /etc/profile
        echo 'export CLASSPATH="${JAVA_HOME}/lib"' >> /etc/profile
        echo 'export MANPATH="${JAVA_HOME}/man"' >> /etc/profile

        source /etc/profile
        cd /inst/
    fi
}

directoryPermission() {
    echo -e "Directory permission"
    chown ${CACHEUSER}:${CACHEGROUP} /journal* &> /dev/null
    chmod 775 /journal* &> /dev/null

    chown ${CACHEUSER}:${CACHEGROUP} /cache* &> /dev/null
    chmod 775 /cache* &> /dev/null

    chown ${CACHEUSER}:${CACHEGROUP} /ensemble* &> /dev/null
    chmod 775 /ensemble* &> /dev/null

    chown ${CACHEUSER}:${CACHEGROUP} /backup/ &> /dev/null
    chmod 775 /backup/ &> /dev/null

    chown ${CACHEUSER}:${CACHEGROUP} /dados/ &> /dev/null
    chmod 775 /dados/ &> /dev/null

    chown ${CACHEUSER}:${CACHEGROUP} /binario/ &> /dev/null
    chmod 775 /binario/ &> /dev/null

}

hostsConf() {
    echo -e "Setting /etc/hosts"
    [[ $(grep $(hostname) /etc/hosts) ]] || echo -e  $(hostname -I) ' \t ' $(hostname) >> /etc/hosts
}

instDirectory() {
    echo -e "Creating /inst directory"
    mkdir /inst/  &> /dev/null
    chmod 775 /inst/ &> /dev/null
    mkdir -p /inst/cache/ &> /dev/null
    mkdir -p /inst/pacotes/ &> /dev/null
    mkdir -p /inst/kit/ &> /dev/null
    chown -R ${CACHEUSER}: /inst/ &> /dev/null
}

qpdfInstall() {
    if ( !(qpdf &> /dev/null ) ); then
        echo -e "QPDF Download"
        yum groupinstall -y -q "Development tools"
        yum install -y -q zlib zlib-devel libjpeg-turbo-devel
        curl -fsL -o /inst/pacotes/qpdf-9.1.1.tar.gz ${DOSPACESHIFTPKG}/requirements/qpdf-9.1.1.tar.gz
        tar xzf /inst/pacotes/qpdf-9.1.1.tar.gz -C /opt/
        cd /opt/qpdf-9.1.1
        echo -e "QPDF ./configure"
        ./configure &> /dev/null
        echo -e "QPDF make"
        make &> /dev/null
        echo -e "QPDF make install"
        make install &> /dev/null
    else
        echo -e "QPDF already install"
    fi
}

wkhtmltopdfInstall() {
    yum install -y -q fontconfig libX11 libXext libXrender xorg-x11-fonts-Type1 xorg-x11-fonts-75dpi
    rpm -Uvh ${DOSPACESHIFTPKG}/requirements/wkhtmltox-0.12.5-1.centos7.x86_64.rpm
}

xpdftoolsInstall() {
    if [[ $(rpm -qa | grep poppler) ]]; then
        echo -e "Poppler packager (pdftotext and pdftohtml) already installed"
    else
        echo -e "Installing package poppler-utils (pdftotext and pdftohtml)"
        yum -y -q install poppler-utils poppler-data &> /dev/null
    fi
}

# Default configuration for Linux
linuxDefault() {
    hostsConf
    # extrasPackages
    # - changePS1
    # changeProfileFile
    # createUsers
    # - sshSecurity
    # timezoneConfig
    # securityOff
}

dbServer() {
    # linuxDefault
    # instDirectory
    # changeLimitsconf
    # xpdftoolsInstall
    # sysctlConf # vm.nrhugepage ok / shmmax não configurado
    # fontExtra
    # directoryPermission
    # sendEmailPkgInstall
    # javaInstall
    # fopInstall
    # qpdfInstall
    # wkhtmltopdfInstall
    cacheInstall
}


# End of Functions

dbServer
