### Usage
1. Create a .env file in the root of the project with the following content:
```
# Use: mkpasswd -m sha-512
HASH_ROOT_PASS='$passwordhash12345'
```
2. Run **bash build-template.sh** to create the Debian template
3. Run **bash build-vms.sh** and specify the required number of virtuals machines. 

### Notes
- Root login and password auth are allowed.
- Package qemu-guest-agent has been pre-installed. 
- IP VMs: 192.168.0.61-63 (This IPs are assigned from local network range)
- VM parameters: 
    - CPU: 2 cores
    - RAM: 2 GB
    - Disk: 20 Gb
