# Olssite
=========


Description
--------

Olssite is a one-click installation script for OpenLiteSpeed with a website running SSL. Using this script,
you can quickly and easily install OpenLiteSpeed with some modified config settings giving you the advantage of not having to further carry out additional tweaks within the OLS Admin panel before your site is fully up and running. 

There is an **-s** parameter that will automatically install your site with an SSL Certificate. 


Running Olssite
--------

Olssite can be run in the following way:
*./olssite.sh [options] [options] …*

When run with no options, olssite will install OpenLiteSpeed with mostly default
settings and values.

####Possible Options:
* **--adminpassword(-a) [PASSWORD]:** To set set the WebAdmin password for OpenLiteSpeed instead of a random one.
  * If you omit **[PASSWORD]**, olssite will prompt you to provide this password during installation.
* **--email(-e) EMAIL:** to set the administrator email.
* **--lsphp VERSION:** to set LSPHP version, such as 56. We currently support versions 54, 55, 56, 70, 71 and 72.
* **--site(-s) SITEDOMAIN:** To install and setup your site with your chosen domain.
* **--sitepath SITEPATH:** to specify the location of your site's web files. 
* **--listenport LISTENPORT:** to set the HTTP server listener port, default is 80.
* **--ssllistenport LISTENPORT:** to set the HTTPS server listener port, default is 443.
* **--uninstall:** to uninstall OpenLiteSpeed and remove the installation directory.
* **--purgeall:** to uninstall OpenLiteSpeed, remove the installation directory, and purge all data in MySQL.
* **--version(-v):** to display version information.
* **--help(-h):** to display usage.

--------
Credit to the original script @ litespeedtech/ols1clk

