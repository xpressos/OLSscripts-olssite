#!/bin/bash
##############################################################################
#    Open LiteSpeed is an open source HTTP server.                           #
#    Copyright (C) 2013 - 2018 LiteSpeed Technologies, Inc.                  #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the            #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program. If not, see http://www.gnu.org/licenses/.      #
##############################################################################

###    Author: dxu@litespeedtech.com (David Shue)
###    Modified by Xpressos CDC.


TEMPRANDSTR=
function getRandPassword
{
    dd if=/dev/urandom bs=8 count=1 of=/tmp/randpasswdtmpfile >/dev/null 2>&1
    TEMPRANDSTR=`cat /tmp/randpasswdtmpfile`
    rm /tmp/randpasswdtmpfile
    local DATE=`date`
    TEMPRANDSTR=`echo "$TEMPRANDSTR$RANDOM$DATE" |  md5sum | base64 | head -c 8`
}

#OS Info
OSNAMEVER=UNKNOWN
OSNAME=
OSVER=
OSTYPE=`uname -m`

#Current status
OLSINSTALLED=

#Admin settings
getRandPassword
ADMINPASSWORD=$TEMPRANDSTR
ADMINPORT=7080
EMAIL=

#Webserver settings
SERVER_ROOT=/usr/local/lsws
PUBLIC_HTML=/usr/local/lsws/www/

#Site settings
INSTALLSITE=0
SITEPATH=
SITEPORT=80
SSLSITEPORT=443
SITEDOMAIN=*
FORCEYES=0


#All lsphp versions, keep using two digits to identify a version!!!
#otherwise, need to update the uninstall function which will check the version
LSPHPVERLIST=(54 55 56 70 71 72)

#default version
LSPHPVER=72
USEDEFAULTLSPHP=1

ALLERRORS=0
TEMPPASSWORD=

ACTION=INSTALL
FOLLOWPARAM=

CONFFILE=myssl.conf
CSR=example.csr
KEY=example.key
CERT=example.crt

MYGITHUBURL=https://raw.githubusercontent.com/olsscripts/olssite/master/olssite.sh

function update_centos
{
    yum -y update
}

function echoY
{
    FLAG=$1
    shift
    echo -e "\033[38;5;148m$FLAG\033[39m$@"
}

function echoG
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}

function echoR
{
    FLAG=$1
    shift
    echo -e "\033[38;5;203m$FLAG\033[39m$@"
}

function check_root
{
    local INST_USER=`id -u`
    if [ $INST_USER != 0 ] ; then
        echoR "Sorry, only the root user can install."
        echo 
        exit 1
    fi
}

function check_wget
{
    which wget  >/dev/null 2>&1
    if [ $? != 0 ] ; then
        if [ "x$OSNAME" = "xcentos" ] ; then
            yum -y install wget
        else
            apt-get -y install wget
        fi
    
        which wget  >/dev/null 2>&1
        if [ $? != 0 ] ; then
            echoR "An error occured during wget installation."
            ALLERRORS=1
        fi
    fi
}

function display_license
{
    echoY '**********************************************************************************************'
    echoY '*                    Open LiteSpeed One click site installation, Version 2.0                 *'
    echoY '*                    Copyright (C) 2016 - 2019 LiteSpeed Technologies, Inc.                  *'
    echoY '**********************************************************************************************'
}

function check_os
{
    OSNAMEVER=
    OSNAME=
    OSVER=
   
    
    if [ -f /etc/redhat-release ] ; then
        cat /etc/redhat-release | grep " 6." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=CENTOS6
            OSNAME=centos
            OSVER=6
        else
            cat /etc/redhat-release | grep " 7." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=CENTOS7
                OSNAME=centos
                OSVER=7

            fi
        fi
    elif [ -f /etc/lsb-release ] ; then
        cat /etc/lsb-release | grep "DISTRIB_RELEASE=14." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=UBUNTU14
            OSNAME=ubuntu
            OSVER=trusty
            
        else
            cat /etc/lsb-release | grep "DISTRIB_RELEASE=16." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=UBUNTU16
                OSNAME=ubuntu
                OSVER=xenial
                
                
            else
                cat /etc/lsb-release | grep "DISTRIB_RELEASE=18." >/dev/null
                if [ $? = 0 ] ; then
                    OSNAMEVER=UBUNTU18
                    OSNAME=ubuntu
                    OSVER=bionic
                    
                fi
            fi
        fi
    elif [ -f /etc/debian_version ] ; then
        cat /etc/debian_version | grep "^7." >/dev/null
        if [ $? = 0 ] ; then
            OSNAMEVER=DEBIAN7
            OSNAME=debian
            OSVER=wheezy
            
        else
            cat /etc/debian_version | grep "^8." >/dev/null
            if [ $? = 0 ] ; then
                OSNAMEVER=DEBIAN8
                OSNAME=debian
                OSVER=jessie
                
            else
                cat /etc/debian_version | grep "^9." >/dev/null
                if [ $? = 0 ] ; then
                    OSNAMEVER=DEBIAN9
                    OSNAME=debian
                    OSVER=stretch
                    
                fi
            fi
        fi
    fi

    if [ "x$OSNAMEVER" = "x" ] ; then
        echoR "Sorry, currently one click installation only supports Centos(6,7), Debian(7-9) and Ubuntu(14,16,18)."
        echoR "You can download the source code and build from it."
        echoR "The url of the source code is https://github.com/olsscripts/olssite."
        echo 
        exit 1
    else
        if [ "x$OSNAME" = "xcentos" ] ; then
	    echo
            echoG "Current platform is "  "$OSNAME $OSVER."
        else
            export DEBIAN_FRONTEND=noninteractive
            echoG "Current platform is "  "$OSNAMEVER $OSNAME $OSVER."
        fi
    fi
}


function update_centos_hashlib
{
    if [ "x$OSNAME" = "xcentos" ] ; then
        yum -y install python-hashlib
    fi
}


function install_ols_centos
{
    local action=install
    if [ "x$1" = "xUpdate" ] ; then
        action=update
    elif [ "x$1" = "xReinstall" ] ; then
        action=reinstall
    fi
    
    local JSON=
    if [ "x$LSPHPVER" = "x70" ] || [ "x$LSPHPVER" = "x71" ] || [ "x$LSPHPVER" = "x72" ] ; then
        JSON=lsphp$LSPHPVER-json
    fi
    
    
    yum -y $action epel-release
    rpm -Uvh http://rpms.litespeedtech.com/centos/litespeed-repo-1.1-1.el$OSVER.noarch.rpm
    yum -y $action openlitespeed
    
    #Sometimes it may fail and do a reinstall to fix
    if [ ! -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        yum -y reinstall openlitespeed
    fi
    
    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=install
    fi
    
    yum -y $action lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON
    
    if [ $? != 0 ] ; then
        echoR "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/\$SERVER_ROOT\/fcgi-bin\/lsphp/\$SERVER_ROOT\/fcgi-bin\/lsphpnew/g" "$SERVER_ROOT/conf/httpd_config.conf"
    fi
}

function uninstall_ols_centos
{
    yum -y remove openlitespeed
    if [ $? != 0 ] ; then
        echoR "An error occured while uninstalling OpenLiteSpeed."
        ALLERRORS=1
    fi
    
    #Need to find what is current lsphp version
    yum list installed | grep lsphp | grep process >/dev/null 2>&1
    if [ $? = 0 ] ; then
        local LSPHPSTR=`yum list installed | grep lsphp | grep process`
        LSPHPVER=`echo $LSPHPSTR | awk '{print substr($0,6,2)}'`
        echoY "The installed LSPHP version is $LSPHPVER"
        
        local JSON=
        if [ "x$LSPHPVER" = "x70" ] || [ "x$LSPHPVER" = "x71" ] || [ "x$LSPHPVER" = "x72" ] ; then
            JSON=lsphp$LSPHPVER-json
        fi
        
        yum -y remove lsphp$LSPHPVER lsphp$LSPHPVER-common lsphp$LSPHPVER-gd lsphp$LSPHPVER-process lsphp$LSPHPVER-mbstring lsphp$LSPHPVER-xml lsphp$LSPHPVER-mcrypt lsphp$LSPHPVER-pdo lsphp$LSPHPVER-imap $JSON lsphp*
        if [ $? != 0 ] ; then
            echoR "An error occured while uninstalling lsphp$LSPHPVER"
            ALLERRORS=1
        fi
        
    else
        yum -y remove lsphp*
        echoR "Uninstallation cannot get the currently installed LSPHP version."
        echoY "May not uninstall LSPHP correctly."
        LSPHPVER=
    fi

    rm -rf $SERVER_ROOT/
}

function install_ols_debian
{
    local action=
    if [ "x$1" = "xUpdate" ] ; then
        action="--only-upgrade"
    elif [ "x$1" = "xReinstall" ] ; then
        action="--reinstall"
    fi
    
    
    grep -Fq  "http://rpms.litespeedtech.com/debian/" /etc/apt/sources.list.d/lst_debian_repo.list
    if [ $? != 0 ] ; then
        echo "deb http://rpms.litespeedtech.com/debian/ $OSVER main"  > /etc/apt/sources.list.d/lst_debian_repo.list
    fi
    
    wget -O /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    wget -O /etc/apt/trusted.gpg.d/lst_repo.gpg http://rpms.litespeedtech.com/debian/lst_repo.gpg
    
    apt-get -y update
    apt-get -y install $action openlitespeed
    
    if [ ! -e $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp ] ; then
        action=
    fi
    apt-get -y install $action lsphp$LSPHPVER lsphp$LSPHPVER-imap lsphp$LSPHPVER-curl

    
    if [ "x$LSPHPVER" != "x70" ] && [ "x$LSPHPVER" != "x71" ] && [ "x$LSPHPVER" != "x72" ] ; then
        apt-get -y install $action lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt 
    else
       apt-get -y install $action lsphp$LSPHPVER-common lsphp$LSPHPVER-json
    fi
    
    if [ $? != 0 ] ; then
        echoR "An error occured during OpenLiteSpeed installation."
        ALLERRORS=1
    else
        ln -sf $SERVER_ROOT/lsphp$LSPHPVER/bin/lsphp $SERVER_ROOT/fcgi-bin/lsphpnew
        sed -i -e "s/\$SERVER_ROOT\/fcgi-bin\/lsphp/\$SERVER_ROOT\/fcgi-bin\/lsphpnew/g" "$SERVER_ROOT/conf/httpd_config.conf"
    fi
}


function uninstall_ols_debian
{
    apt-get -y remove openlitespeed
    
    dpkg -l | grep lsphp >/dev/null 2>&1
    if [ $? = 0 ] ; then
        local LSPHPSTR=`dpkg -l | grep lsphp`
        LSPHPVER=`echo $LSPHPSTR | awk '{print substr($2,6,2)}'`
        echoY "The installed LSPHP version is $LSPHPVER"
        
        if [ "x$LSPHPVER" != "x70" ] && [ "x$LSPHPVER" != "x71" ] && [ "x$LSPHPVER" != "x72" ] ; then
            apt-get -y remove lsphp$LSPHPVER-gd lsphp$LSPHPVER-mcrypt
        else
            apt-get -y remove lsphp$LSPHPVER-common
        fi

        apt-get -y remove lsphp$LSPHPVER lsphp$LSPHPVER-imap 'lsphp*'
        if [ $? != 0 ] ; then
            echoR "An error occured while uninstalling OpenLiteSpeed/LSPHP."
            ALLERRORS=1
        fi
    else
        apt-get -y remove lsphp*
        echoR "Uninstallation cannot get the currently installed LSPHP version."
        echoR "May not uninstall LSPHP correctly."
        LSPHPVER=
    fi

    rm -rf $SERVER_ROOT/
}


function install_site
{
    if [ ! -e "$SITEPATH" ] ; then 
        local SITEDIRNAME=`dirname $SITEPATH`
        local SITEBASENAME=`basename $SITEPATH`
        mkdir -p "$SITEDIRNAME"
	    echo
	    echoY "Installing site ..."
	    echo
	    wget -P $SITEPATH https://github.com/olsscripts/olssite/raw/master/sitefiles.tar.gz
	    cd "$SITEPATH"
	    tar -xzf sitefiles.tar.gz
	    rm sitefiles.tar.gz
	    mv $SITEPATH/logs $PUBLIC_HTML/$SITEDOMAIN
	    chown -R nobody:nobody $PUBLIC_HTML/$SITEDOMAIN
	    echoY "[OK] Site Installed."
	    echo
	    echo
	   
    else
        echoY "$SITEPATH exists, it will be used."
    fi
}


function uninstall_result
{
    if [ "x$ALLERRORS" = "x0" ] ; then
        echoG "Uninstallation finished."
    else
        echoY "Uninstallation finished - some error(s) occured. Please check these as you may need to manually fix them."
    fi  
    echo
}


function install_ols
{
    local STATUS=Install
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        OLS_VERSION=$(cat "$SERVER_ROOT"/VERSION)
        wget -O "$SERVER_ROOT"/release.tmp  http://open.litespeedtech.com/packages/release?ver=$OLS_VERSION
        LATEST_VERSION=$(cat "$SERVER_ROOT"/release.tmp)
        rm "$SERVER_ROOT"/release.tmp
        if [ "x$OLS_VERSION" = "x$LATEST_VERSION" ] ; then
            STATUS=Reinstall
            echoY "OpenLiteSpeed is already installed with the latest version, will attempt to reinstall it."
        else
            STATUS=Update
            echoY "OpenLiteSpeed is already installed and newer version is available, will attempt to update it."
        fi
    fi

    if [ "x$OSNAME" = "xcentos" ] ; then
        echo "$STATUS on Centos"
        install_ols_centos $STATUS
    else
        echo "$STATUS on Debian/Ubuntu"
        install_ols_debian $STATUS
    fi
}

function install_ssl
{
        #SSL INSTALL#
	echoY "Installing SSL on Server ..."
	echo
        systemctl stop lsws
        wget -P /usr/bin https://dl.eff.org/certbot-auto
        chmod +x /usr/bin/certbot-auto
        /usr/bin/certbot-auto certonly --standalone -n --preferred-challenges http --agree-tos --email $EMAIL -d $SITEDOMAIN 
        systemctl start lsws
}	
		

function gen_selfsigned_cert
{
    # source outside config file
    if [ -e $CONFFILE ] ; then
        source $CONFFILE 2>/dev/null
        if [ $? != 0 ]; then
            . $CONFFILE
        fi
    fi
    
    # set default value
    if [ "${SSL_COUNTRY}" = "" ] ; then
        SSL_COUNTRY=US
    fi

    if [ "${SSL_STATE}" = "" ] ; then
        SSL_STATE="New Jersey"
    fi

    if [ "${SSL_LOCALITY}" = "" ] ; then
        SSL_LOCALITY=Virtual
    fi

    if [ "${SSL_ORG}" = "" ] ; then
        SSL_ORG=LiteSpeedCommunity
    fi
    
    if [ "${SSL_ORGUNIT}" = "" ] ; then
        SSL_ORGUNIT=Testing
    fi

    if [ "${SSL_HOSTNAME}" = "" ] ; then
        SSL_HOSTNAME=webadmin
    fi

    if [ "${SSL_EMAIL}" = "" ] ; then
        SSL_EMAIL=.
    fi
    

# Create the certificate signing request
    openssl req -new -passin pass:password -passout pass:password -out $CSR <<EOF
${SSL_COUNTRY}
${SSL_STATE}
${SSL_LOCALITY}
${SSL_ORG}
${SSL_ORGUNIT}
${SSL_HOSTNAME}
${SSL_EMAIL}
.
.
EOF
    echo ""

    [ -f ${CSR} ] && openssl req -text -noout -in ${CSR}
    echo ""

# Create the Key
    openssl rsa -in privkey.pem -passin pass:password -passout pass:password -out ${KEY}
# Create the Certificate
    openssl x509 -in ${CSR} -out ${CERT} -req -signkey ${KEY} -days 1000
    
    mv ${KEY}   $SERVER_ROOT/conf/$KEY
    mv ${CERT}  $SERVER_ROOT/conf/$CERT
    chmod 0600 $SERVER_ROOT/conf/$KEY
    chmod 0600 $SERVER_ROOT/conf/$CERT
}


function set_ols_password
{
    #setup password
    ENCRYPT_PASS=`"$SERVER_ROOT/admin/fcgi-bin/admin_php" -q "$SERVER_ROOT/admin/misc/htpasswd.php" $ADMINPASSWORD`
    if [ $? = 0 ] ; then
        echo "admin:$ENCRYPT_PASS" > "$SERVER_ROOT/admin/conf/htpasswd"
        if [ $? = 0 ] ; then
            echoY "[OK] OpenLiteSpeed Installed."
            echoY "OpenLiteSpeed WebAdmin password: $ADMINPASSWORD"
            echoY "Finished updating server configuration."
            echo
        else
            echoY "OpenLiteSpeed WebAdmin password not changed."
        fi
    fi
    
}




function config_ols
{
    if [ -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        sed -i -e "s/adminEmails/adminEmails $EMAIL\n#adminEmails/" "$SERVER_ROOT/conf/httpd_config.conf"
        sed -i -e "s/8088/$SITEPORT/" "$SERVER_ROOT/conf/httpd_config.conf"
        sed -i -e "s/ls_enabled/ls_enabled   1\n#/" "$SERVER_ROOT/conf/httpd_config.conf"
        
        cat >> $SERVER_ROOT/conf/httpd_config.conf <<END 

listener SSL {
address                 *:$SSLSITEPORT
secure                  1
map                     Example *
keyFile                 $SERVER_ROOT/conf/$KEY
certFile                $SERVER_ROOT/conf/$CERT
}

END
        chown -R lsadm:lsadm $SERVER_ROOT/conf/
    else
        echoR "$SERVER_ROOT/conf/httpd_config.conf is missing. It appears that something went wrong during OpenLiteSpeed installation."
        ALLERRORS=1
    fi
}


function config_ols_site
{
    if [ -e "$SERVER_ROOT/conf/httpd_config.conf" ] ; then
        cat $SERVER_ROOT/conf/httpd_config.conf | grep "virtualhost $SITEDOMAIN" >/dev/null
        if [ $? != 0 ] ; then
            sed -i "s/root@localhost/$EMAIL,root@localhost/g" -i.bkp "$SERVER_ROOT/conf/httpd_config.conf"
			sleep 1
			sed -i 's/enableCache         0/enableCache         1/g' "$SERVER_ROOT/conf/httpd_config.conf"
			sleep 1
			sed -i 's/enablePrivateCache  0/enablePrivateCache  1/g' "$SERVER_ROOT/conf/httpd_config.conf"
			sleep 1
			sed -i '/railsEnv                 1/d' /usr/local/lsws/conf/httpd_config.conf
			sleep 1
	        sed -i '/map                      Example */d' -i.backup /usr/local/lsws/conf/httpd_config.conf
			sleep 1
			sed -i '/ignoreRespCacheCtrl 0\b/a \ \   storagepath         cachedata' /usr/local/lsws/conf/httpd_config.conf
	             

            VHOSTCONF=$SERVER_ROOT/conf/vhosts/$SITEDOMAIN/vhconf.conf

            cat >> $SERVER_ROOT/conf/httpd_config.conf <<END 

virtualhost $SITEDOMAIN {
vhRoot                  $SITEPATH
configFile              $VHOSTCONF
allowSymbolLink         1
enableScript            1
restrained              0
setUIDMode              2
}

listener Main {
  map                     $SITEDOMAIN $SITEDOMAIN
  address                 *:$SITEPORT
  secure                  1
  keyFile                 /etc/letsencrypt/live/$SITEDOMAIN/privkey.pem
  certFile                /etc/letsencrypt/live/$SITEDOMAIN/fullchain.pem
  certChain               1
}

listener SSL {
  map                     $SITEDOMAIN $SITEDOMAIN
  address                 *:$SSLSITEPORT
  secure                  1
  keyFile                 /etc/letsencrypt/live/$SITEDOMAIN/privkey.pem
  certFile                /etc/letsencrypt/live/$SITEDOMAIN/fullchain.pem
  certChain               1  
}
 
suspendedVhosts           Example

END
    
            mkdir -p $SERVER_ROOT/conf/vhosts/$SITEDOMAIN/
            cat > $VHOSTCONF <<END 
docRoot                   \$VH_ROOT/
vhDomain                  $SITEDOMAIN
enableGzip                1
errorlog  {
  useServer               1
}
accesslog $SERVER_ROOT/logs/$VH_NAME.access.log {
  useServer               0
  logHeaders              3
  rollingSize             100M
  keepDays                30
  compressArchive         1
}
index  {
  useServer               0
  indexFiles              index.html, index.php
  autoIndex               0
  autoIndexURI            /_autoindex/default.php
}
errorpage 404 {
  url                     /404.html
}
expires  {
  enableExpires           1
}
accessControl  {
  allow                   *
}
rewrite  {
  enable                  0
  logLevel                0
}

END
            chown -R lsadm:lsadm $SERVER_ROOT/conf/
        fi
        
        
    else
        echoR "$SERVER_ROOT/conf/httpd_config.conf is missing. It appears that something went wrong during OpenLiteSpeed installation."
        ALLERRORS=1
    fi
}


function getCurStatus
{
    if [ -e $SERVER_ROOT/bin/openlitespeed ] ; then
        OLSINSTALLED=1
    else
        OLSINSTALLED=0
    fi
}


function changeOlsPassword
{
    LSWS_HOME=$SERVER_ROOT
    ENCRYPT_PASS=`"$LSWS_HOME/admin/fcgi-bin/admin_php" -q "$LSWS_HOME/admin/misc/htpasswd.php" $ADMINPASSWORD`
    echo "$ADMIN_USER:$ENCRYPT_PASS" > "$LSWS_HOME/admin/conf/htpasswd"
    echoY "Finished setting OpenLiteSpeed WebAdmin password to $ADMINPASSWORD."
}


function uninstall
{
    if [ "x$OLSINSTALLED" = "x1" ] ; then
        echoY "Uninstalling ..."
        $SERVER_ROOT/bin/lswsctrl stop
        if [ "x$OSNAME" = "xcentos" ] ; then
            echo "Uninstall on Centos"
            uninstall_ols_centos
        else
            echo "Uninstall on Debian/Ubuntu"
            uninstall_ols_debian
        fi
        echoG Uninstalled.
    else
        echoY "OpenLiteSpeed not installed."
    fi
}

function read_password
{
    if [ "x$1" != "x" ] ; then 
        TEMPPASSWORD=$1
    else
        passwd=
        echoY "Please input password for $2(press enter to get a random one):"
        read passwd
        if [ "x$passwd" = "x" ] ; then
            local RAND=$RANDOM
            local DATE0=`date`
            TEMPPASSWORD=`echo "$RAND0$DATE0" |  md5sum | base64 | head -c 8`
        else
            TEMPPASSWORD=$passwd
        fi
    fi
}


function check_value_follow
{
    FOLLOWPARAM=$1
    local PARAM=$1
    local KEYWORD=$2
    
    #test if first letter is - or not.
    if [ "x$1" = "x-n" ] || [ "x$1" = "x-e" ] || [ "x$1" = "x-E" ] ; then
        FOLLOWPARAM=
    else
        local PARAMCHAR=`echo $1 | awk '{print substr($0,1,1)}'`
        if [ "x$PARAMCHAR" = "x-" ] ; then 
            FOLLOWPARAM=
        fi
    fi

    if [ "x$FOLLOWPARAM" = "x" ] ; then
        if [ "x$KEYWORD" != "x" ] ; then
            echoR "Error: '$PARAM' is not a valid '$KEYWORD', please check and try again."
            usage
            exit 1
        fi
    fi
}


function updatemyself
{
    local CURMD=`md5sum "$0" | cut -d' ' -f1`
    local SERVERMD=`md5sum  <(wget $MYGITHUBURL -O- 2>/dev/null)  | cut -d' ' -f1`
    if [ "x$CURMD" = "x$SERVERMD" ] ; then
        echoG "You already have the latest version installed."
    else
        wget -O "$0" $MYGITHUBURL
        CURMD=`md5sum "$0" | cut -d' ' -f1`
        if [ "x$CURMD" = "x$SERVERMD" ] ; then
            echoG "Updated."
        else
            echoG "Tried to update but seems to be failed."
        fi
    fi
}


function usage
{
    echoY "USAGE:                             " "$0 [options] [options] ..."
    echoY "OPTIONS                            "
    echoG " --adminpassword(-a) [PASSWORD]    " "To set the WebAdmin password for OpenLiteSpeed instead of using a random one."
    echoG "                                   " "If you omit [PASSWORD], olssite will prompt you to provide this password during installation."
	echoG " --adminport LISTENPORT            " "To set the WebAdmin port for OpenLiteSpeed instead of using the default port 7080."
    echoG " --email(-e) EMAIL                 " "To set the administrator email."
    echoG " --lsphp VERSION                   " "To set the LSPHP version, such as 56. We currently support versions '${LSPHPVERLIST[@]}'."
    echoG " --site(-s) SITEDOMAIN             " "To install and setup your site with your chosen domain."
    echoG " --sitepath SITEPATH               " "To specify a location for the new site installation or use an existing site installation."
    echoG " --listenport LISTENPORT           " "To set the HTTP server listener port, default is 80."
    echoG " --ssllistenport LISTENPORT        " "To set the HTTPS server listener port, default is 443."
    echoG " --uninstall                       " "To uninstall OpenLiteSpeed and remove installation directory."
    echoG " --quiet                           " "Set to quiet mode, won't prompt to input anything."
    echoG " --version(-v)                     " "To display version information."
    echoG " --update                          " "To update olssite from github."
    echoG " --help(-h)                        " "To display usage."
    echo
    echoY "EXAMPLES                           "
    echoG "./ols1clk.sh                       " "To install the latest version of OpenLiteSpeed with a random WebAdmin password."
    echoG "./ols1clk.sh --lsphp 72            " "To install the latest version of OpenLiteSpeed with lsphp72."
    echoG "./ols1clk.sh -a 123456 -e a@cc.com " "To install the latest version of OpenLiteSpeed with WebAdmin password  \"123456\" and email a@cc.com."
    echoG "./ols1clk.sh -r 123456 -w          " "To install OpenLiteSpeed with WordPress and MySQL root password \"123456\"."
    echoG "./ols1clk.sh -a 123 -r 1234 --wordpressplus a.com"  ""
    echo  "                                   To install OpenLiteSpeed with a fully configured WordPress installation at \"a.com\" using WebAdmin password \"123\" and MySQL root password \"1234\"."
    echoG "./ols1clk.sh -a 123 -r 1234 --wplang zh_CN --sitetitle mySite --wordpressplus a.com"  ""
    echo  "                                   To install OpenLiteSpeed with a fully configured Chinese (China) language WordPress installation at \"a.com\" using WebAdmin password \"123\",  MySQL root password \"1234\", and WordPress site title \"mySite\"."
    echo
    
}

function kill_apache
{
   if [ "x$SITEPORT" = "x80" ] ; then
      echo
      echo "Stopping any Web Servers that may be using port 80."
      echo
      yum -y remove httpd >/dev/null 2>&1
      killall -9 apache  >/dev/null 2>&1
      killall -9 apache2  >/dev/null 2>&1
      killall -9 httpd    >/dev/null 2>&1
      killall -9 nginx    >/dev/null 2>&1
   fi
}

function uninstall_warn
{
    if [ "x$FORCEYES" != "x1" ] ; then
        echo
        printf "\033[31mAre you sure you want to uninstall? Type 'Y' to continue, otherwise will quit.[y/N]\033[0m "
        read answer
        echo
        
        if [ "x$answer" != "xY" ] ; then
            echoG "Uninstallation aborted!" 
            exit 0
        fi
        echo
    fi
}

function test_page
{
    local URL=$1
    local KEYWORD=$2
    local PAGENAME=$3

    rm -rf tmp.tmp
    wget --no-check-certificate -O tmp.tmp  $URL >/dev/null 2>&1
    grep "$KEYWORD" tmp.tmp  >/dev/null 2>&1
    
    if [ $? != 0 ] ; then
        echoR "Error: $PAGENAME Failed."
    else
        echoG "OK: $PAGENAME Passed."
    fi
    rm tmp.tmp
}


function test_ols_admin
{
    test_page https://localhost:7080/ "LiteSpeed WebAdmin" "Test WebAdmin Page" 
}

function test_ols
{
    test_page http://localhost:$SITEPORT/  Congratulation "Test Example HTTP vhost Page" 
    test_page https://localhost:$SSLSITEPORT/  Congratulation "Test Example HTTPS vhost Page" 
}

function test_site
{ 
    test_page http://$SITEDOMAIN:$SITEPORT/ "Congratulation" "Test HTTP first Page" 
    test_page https://$SITEDOMAIN:$SSLSITEPORT/ "Congratulation" "Test HTTPS first Page" 
}

#####################################################################################
####   Main function here
#####################################################################################
###start here 1###
check_root
update_centos
check_wget
check_os
kill_apache
display_license

while [ "$1" != "" ] ; do
    case $1 in
        -a | --adminpassword )      check_value_follow "$2" ""
                                    if [ "x$FOLLOWPARAM" != "x" ] ; then
                                        shift
                                    fi
                                    ADMINPASSWORD=$FOLLOWPARAM
                                    ;;
									
			 --adminport )          check_value_follow "$2" "Admin port"
                                    shift
                                    ADMINPORT=$FOLLOWPARAM
                                    ;;						

        -e | --email )              check_value_follow "$2" "email address"
                                    shift
                                    EMAIL=$FOLLOWPARAM
                                    ;;
                                    
             --lsphp )              check_value_follow "$2" "LSPHP version"
                                    shift
                                    cnt=${#LSPHPVERLIST[@]}
                                    for (( i = 0 ; i < cnt ; i++ ))
                                    do
                                        if [ "x$1" = "x${LSPHPVERLIST[$i]}" ] ; then
                                            LSPHPVER=$1
                                            USEDEFAULTLSPHP=0
                                        fi
                                    done
                                    ;;          
      
                               							   
        -s | --site )               check_value_follow "$2" "domain"
                                    shift
                                    SITEDOMAIN=$FOLLOWPARAM
		                            INSTALLSITE=1
                                    ;;
                                    
                                    
             --sitepath )           check_value_follow "$2" "Site path"
                                    shift
                                    SITEPATH=$FOLLOWPARAM
                                    INSTALLSITE=1
                                    ;;

                                    
             --listenport )         check_value_follow "$2" "HTTP listen port"
                                    shift
                                    SITEPORT=$FOLLOWPARAM
                                    ;;
             --ssllistenport )      check_value_follow "$2" "HTTPS listen port"
                                    shift
                                    SSLSITEPORT=$FOLLOWPARAM
                                    ;;
                                    

             --uninstall )          ACTION=UNINSTALL
                                    ;;

                                    
             --quiet )              FORCEYES=1
                                    ;;

        -v | --version )            exit 0
                                    ;;                                    

             --update )             updatemyself
                                    exit 0
                                    ;;                                    
        
        -h | --help )               usage
                                    exit 0
                                    ;;

        * )                         usage
                                    exit 0
                                    ;;
    esac
    shift
done



#test if have $SERVER_ROOT , and backup it

if [ "x$ACTION" = "xUNINSTALL" ] ; then
    uninstall_warn
    uninstall
    uninstall_result
    exit 0
fi


if [ "x$OSNAMEVER" = "xUBUNTU18" ] || [ "x$OSNAMEVER" = "xDEBIAN9" ] ; then
    if [ "x$LSPHPVER" = "x54" ] || [ "x$LSPHPVER" = "x55" ] || [ "x$LSPHPVER" = "x56" ] ; then
       echoY "We do not support lsphp$LSPHPVER on $OSNAMEVER, lsphp71 will be used instead."
       LSPHPVER=71
   fi
fi


if [ "x$EMAIL" = "x" ] ; then
    if [ "x$SITEDOMAIN" = "x*" ] ; then
        EMAIL=root@localhost
    else
        EMAIL=root@$SITEDOMAIN
    fi
fi

read_password "$ADMINPASSWORD" "webAdmin password"
ADMINPASSWORD=$TEMPPASSWORD


if [ "x$USEDEFAULTLSPHP" = "x1" ] ; then
    if [ "x$INSTALLSITE" = "x1" ] && [ -e "$SITEPATH" ] ; then
        #For existing site, choose lsphp56 as default
        LSPHPVER=56
    fi
fi


echo
echoR "Starting to install OpenLiteSpeed to $SERVER_ROOT/ with the parameters below,"
echoY "WebAdmin password:        " "$ADMINPASSWORD"
echoY "WebAdmin email:           " "$EMAIL"
echoY "LSPHP version:            " "$LSPHPVER"


SITEINSTALLED=
if [ "x$INSTALLSITE" = "x1" ] ; then
    echoY "Install Site:             " Yes
    echoY "Site HTTP port:           " "$SITEPORT"
    echoY "Site HTTPS port:          " "$SSLSITEPORT"
    echoY "Site domain:              " "$SITEDOMAIN"
  
    if [ -e "$SITEPATH" ] ; then
        echoY "Site location:            " "$SITEPATH (Existing)"
        SITEINSTALLED=1
    else
        echoY "Site location:            " "$SITEPATH (New install)"
        SITEINSTALLED=0
    fi
else
    echoY "Server HTTP port:         " "$SITEPORT"
    echoY "Server HTTPS port:        " "$SSLSITEPORT"
fi

echo

if [ "x$FORCEYES" != "x0" ] ; then
    printf '\033[31mAre these settings correct? Type n to quit, otherwise will continue.[Y/n]\033[0m '
    read answer
    echo

    if [ "x$answer" = "xN" ] || [ "x$answer" = "xn" ] ; then
        echoG "Aborting installation!" 
        exit 0
    fi
    echo 
fi

###start here 2###
getCurStatus
update_centos_hashlib
install_ols
set_ols_password

#write the password file for record and remove the previous file.
echo "WebAdmin username is [admin], password is [$ADMINPASSWORD]." > $SERVER_ROOT/password
 
if [ "x$SITEINSTALLED" != "x1" ] ; then
        install_site
	config_ols_site
	install_ssl
else
    #normal ols installation without a site
    gen_selfsigned_cert
    config_ols
fi


$SERVER_ROOT/bin/lswsctrl stop >/dev/null 2>&1
$SERVER_ROOT/bin/lswsctrl start


chmod 600 "$SERVER_ROOT/password"
echoY "Please be aware that your password was written to file '$SERVER_ROOT/password'." 


echo
echoY "Testing ..."
test_ols_admin
if [ "x$INSTALLSITE" = "x1" ] ; then 
   test_site
else
    test_ols
fi

echo
if [ "x$ALLERRORS" = "x0" ] ; then
    echoG "Congratulations! Installation finished."
else
    echoY "Installation finished. Some errors seem to have occured, please check this as you may need to manually fix them."
fi  

if [ "x$INSTALLSITE" = "x1" ] ; then
    echo "You can now access your site at https://$SITEDOMAIN"
    echo "The OpenLiteSpeed Admin panel can now be accessed at https://$SITEDOMAIN:$ADMINPORT"
	echo "WebAdmin Username:Admin   Password:$ADMINPASSWORD"
fi

echo
echoG 'Thanks for using "OpenLiteSpeed One click installation".'
echoG "Enjoy!"
echo
echo
