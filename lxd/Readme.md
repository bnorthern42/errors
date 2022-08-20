# Recently updated my EndeavorOS
- LXC/LXD 5.4
- Kernel 5.15.60-1-lts


- error: (when creating container 'test')

```shell

lxc test 20220820101212.956 ERROR    conf - ../src/lxc/conf.c:lxc_map_ids:3672 - newuidmap failed to write mapping "newuidmap: uid range [0-1000000000) -> [1000000-1001000000) not allowed": newuidmap 815994 0 1000000 1000000000

``` 

### Fix

- run as root, not sudo (sudo su...)

```shell 
$ touch /etc/subuid
$ touch /etc/subgid

$ usermod --add-subuids 100000-165535 root 
$ usermod --add-subgids 100000-165535 root

```


