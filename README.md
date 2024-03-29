# fdb
 Find Bad Disk<br>
 fdb.pl is a script perl. It will help you to find disk with high latency for read or write on a DDN disk bay.<br>
 Example :<br>
 <pre>
$ ./fbd.pl

         Script name             : fbd - Find Bad Disk
        Version                 : 2.5
        Description             : This script will report you an output like a "show pd * counters" for mechanical disks on DDN SFA products.

      Options:

        --help  | -h            Print this help.

        --sfa_ips | -i          This option is a mandatory option that allow you to specify the IP Addresses of your controller.

                                Example :

                                fbd.pl -i 10.0.0.2

        --activity | -a         This option allows you to select if you want read or write delay values. Due to the current SFA OS
                                architecture, you can't just have both. The default is read, for write use "-a write"

        --tmp | -t              This option is the time in seconds while you are gathering informations. Default is 60 seconds.

        --user | -u             User to use to login your controllers. Default is "user".

        --password | -p         Password to use to login your controllers. Default is "user".
		
		--ssd | -s              show stats for mechanical disk AND SSD ( only mechanical disk by default ).


        Contact : Quentin Bouyer ( quentin.bouyer@eviden.com )

 </pre>
 <pre>
$ ./fbd.pl -t 10 -i "10.3.10.4"
IP Address(es) of your controller(s) : 10.3.10.4
Try to connect without password
Try to connect with password
Connected on the SFA controler
Now waiting for 10 seconds ...
Virtual Disk 0 Delay - Raid 6 (Pool : 0 - Name : mgs )


PD(Idx)         AVG(us)         4ms     8ms     16ms    32ms    64ms    128ms   256ms   512ms   1024ms  4096ms  +4096ms
40              266             12      0       0       0       0       0       0       0       0       0       0
3               9070            0       0       1       0       0       0       0       0       0       0       0
15              11410           0       0       1       0       0       0       0       0       0       0       0
13              940             12      0       1       0       0       0       0       0       0       0       0
31              9100            0       0       1       0       0       0       0       0       0       0       0
26              9106            0       0       1       0       0       0       0       0       0       0       0
42              9077            0       0       1       0       0       0       0       0       0       0       0

Virtual Disk 1 Delay - Raid 6 (Pool : 0 - Name : home_mdt0000_s0 )

PD(Idx)         AVG(us)         4ms     8ms     16ms    32ms    64ms    128ms   256ms   512ms   1024ms  4096ms  +4096ms
40              266             12      0       0       0       0       0       0       0       0       0       0
3               9070            0       0       1       0       0       0       0       0       0       0       0
15              11410           0       0       1       0       0       0       0       0       0       0       0
13              940             12      0       1       0       0       0       0       0       0       0       0
31              9100            0       0       1       0       0       0       0       0       0       0       0
26              9106            0       0       1       0       0       0       0       0       0       0       0
42              9077            0       0       1       0       0       0       0       0       0       0       0

Virtual Disk 2 Delay - Raid 6 (Pool : 1 - Name : home_ost0000 )

PD(Idx)         AVG(us)         4ms     8ms     16ms    32ms    64ms    128ms   256ms   512ms   1024ms  4096ms  +4096ms
47              13618           0       0       9       0       0       0       0       0       0       0       0
25              11403           3       1       9       2       0       0       0       0       0       0       0
37              14231           0       0       12      1       0       0       0       0       0       0       0
27              13709           1       0       10      2       0       0       0       0       0       0       0
35              14120           0       0       12      1       0       0       0       0       0       0       0
11              29089           0       0       10      3       20      0       0       0       0       0       0
48              14526           0       0       9       2       0       0       0       0       0       0       0
...
</pre>

 
