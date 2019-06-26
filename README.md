# Eurosmart Drive
#### IOS Application : Access and Upload your Files/Folders in your Synology NAS with 2FA Authentication (FIDO) 

Developed for [Eurosmart](https://www.eurosmart.com/)

## Use (for Developers)
To use this application with your **Synology NAS** you simply have to change the **IP**, **PORT** and the **HTTPTYPE** in this file: [Network.swift](/fido-eurosmart/Network/Network.swift)

Please make sure that the following requirements are fulfilled: 
                                
- File Station must be running on your DS  

- The shared folders must be accessible by your user with read and write permissions
           
- In order to use this app outside of your LAN, you must open the necessary ports in your router (see DS manual for details - port forwarding) and either resolve your own domain name with your DS or use a DDNS provider (like Synology).
                                                     
- This application does not support Synology's Quick Connect which is only available for Synology's own mobile apps.
 
- It is strongly recommended to switch on https for secure server communication. In case you receive an error message with https enabled, please log in to your DS with admin permissions and create a self-signed-certificate (control panel / security / certificate).
    * Export the certificates and keys. Store the certificates (root and server certificates, both have the file extension .crt) in a secure location separately from the key files!
    * Send these .crt files to yourself by email (do not send the keys!). In the mail app on your iPhone tap on the crt files and                follow the steps to install them on your iPhone.

The Synology File Station API [Documentation](https://global.download.synology.com/download/Document/DeveloperGuide/Synology_File_Station_API_Guide.pdf)

## Releases
You can download all the [Releases](https://github.com/Felix83000/Eurosmart-SynologyNas-FileStation/releases). 

## Report an Issues
You can also report a bug [here](https://github.com/Felix83000/Eurosmart-SynologyNas-FileStation/issues) to help me improve this application.

Please use this template: [Bug-Report Template](/.github/ISSUE_TEMPLATE/bug_report.md)

## Notes
### Our Synology NAS Current Version:
-  **Model Name** : DS1517+
-  **DSM Version** : DSM 6.2.2-24922

