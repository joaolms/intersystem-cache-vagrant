# intersystem-cache-vagrant
[![Codeac](https://static.codeac.io/badges/2-283513991.svg "Codeac")](https://app.codeac.io/github/joaolms/intersystems-cache-vagrant)

This script sets up an InterSystems Caché Database server

## How to
### Start
```sh
vagrant up
```

### SSH Access
```sh
vagrant ssh
```

### Stop
```sh
vagrant halt
```

> You will need to start Caché instance when the VM is turned on again
```sh
vagrant up
vagrant ssh
ccontrol start cache
exit
```

### Destroy
```sh
vagrant destroy -f
```

### Access

**Admin Portal:** http://192.168.56.110:57772/csp/sys/UtilHome.csp<br>
**Super Server Port:** 56772<br>
**Username:** superuser<br>
**Password:** superuser123<br>
