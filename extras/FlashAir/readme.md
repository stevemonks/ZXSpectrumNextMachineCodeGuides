## Overview
Contains a sample config file (CONFIG) for setting up a Toshiba Flashair card.

By default, a Toshiba FlashAir card will be configured to appear as a WiFi access point and be read only, which makes it unusable for Next development while in this configuration.

The config file provided here will configure the card to connect to a WiFi access point as a WLAN device and be read/writable via WebDav from a Windows PC (I haven't tested this on a Mac).

## Setup
1. Backup the existing CONFIG file already on the drive to somewhere safe.
2. Replace the relevant entries in the config file supplied here (APPNETWORKKEY, APPSSID) with values correct for the WiFi network you want to attach to.
3. Set the MASTERCODE entry to the MAC address printed on the back of your card.
4. Copy this modified CONFIG file over the CONFIG file already on the card.
5. Cycle power (or pull and replace the card) and it should connect to your WiFi network.

You can check if it's worked by looking at the connected devices in your WiFi router's administration page, if the card is visible it is working.

You WiFi network should have assigned an IP address to the card, for simplicity it's best to set your router up to assign a fixed IP to the card so it's not different every time you reconnect it.

To access the contents of the card from your PC press WIN+R to open the "Run" dialog and enter;

```
\\<IP address assigned by your router>\DavWWWRoot
```

Replacing \<IP address assigned by your router\> with the actual address, so it should look something like this;

```
\\192.168.0.35\DavWWWRoot
```

With this set up, you can easily add a batch file to build one of the samples and copy it to the FlashAir card by setting up a batch file with something like this if you're using zcl.exe;
```
zcl zeus.asm
copy *.snx \\192.168.0.35\DavWWWRoot\machinecodeguides
```

or this if you're using zcltest.exe;

```
zcltest zeus.asm
copy *.nex \\192.168.0.35\DavWWWRoot\machinecodeguides
```

Examples are included in each example folder, although you'll need to modify them to suit your FlasAir cards configuration.