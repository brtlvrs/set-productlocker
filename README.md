# set-productLocker

Script to set productlocker information on vSphere hosts sharing the same datastore.
This script is based on the script of [vTagion](https://www.brianjgraf.com/2015/11/05/automate-vmware-tools-shared-product-locker-configuration/) some small 'taste' changes are made.

## LICENSE

This script is released under the MIT license. See the License file for more details

| | |
|---|---|
| Version | 0.0.1|
| branch | master|

## CHANGE LOG

|build|branch |  Change |
|---|---|---|
|0.0| Master| Initial release|

## How to use

1. Download script
1. start script

The script assumes that the vSphere hosts are resolvable by DNS. Plink.exe is used to make modification to the symbolic link to the vmWare tools. When plink accesses the vSphere host the first time it will give an error because the thumbprint is new. You can safely run the script a second time.

## Dependencies

- Plink.exe
- PowerShell 3.0
- PowerCLI > 5.x