# podman-for-macos-tutorial
Demonstration of how you can use Podman on your macOS environment

# Description

The core Podman runtime environment only runs on Linux operating systems. Other operating systems can use remote client software to manage containers on a Linux backend. The remote client is nearly identical to the standard Podman program. Certain functions that do not make sense for remote clients have been removed. For example, the --latest switch for container commands is not present.

> More detail: https://www.redhat.com/sysadmin/podman-clients-macos-windows

# Getting started
There is a software called "Podman Machine" to easily setup a VM that you can use as remote Podman server. Podman-machine starts a virtual machine that already streamlines the Podman, Buildah, and skopeo packages. The developers released two VM flavors: an in-memory Tiny Core and a Fedora version.

You have the option of compiling additional driver support for hypervisors like xhyve, but I would recommend VirtualBox as it seems to work more smoothly.

# Lets start

First, we need to install the "podman-machine" binary to our host.
```bash
$ curl -L https://github.com/boot2podman/machine/releases/download/v0.17/podman-machine.darwin-amd64 --output /usr/local/bin/podman-machine
chmod +x /usr/local/bin/podman-machine
```
I followed this guide to quickly setup our VM: https://developers.redhat.com/blog/2020/02/12/podman-for-macos-sort-of/. But, we need to do some stuff additional to it. So, use this blog post to only set up the VM itself.

Lets create our first VM.
```bash
$ podman-machine create --virtualbox-boot2podman-url https://github.com/snowjet/boot2podman-fedora-iso/releases/download/d1bb19f/boot2podman-fedora.iso --virtualbox-memory="4096" remote-podman-server-vm
Running pre-create checks...
Creating machine...
(remote-podman-server-vm) Downloading /Users/batuhan.apaydin/.local/machine/cache/boot2podman.iso from https://github.com/snowjet/boot2podman-fedora-iso/releases/download/d1bb19f/boot2podman-fedora.iso...
(remote-podman-server-vm) 0%....10%....20%....30%....40%....50%....60%....70%....80%....90%....100%
(remote-podman-server-vm) Creating VirtualBox VM...
(remote-podman-server-vm) Creating SSH key...
(remote-podman-server-vm) Starting the VM...
(remote-podman-server-vm) Check network to re-create if needed...
(remote-podman-server-vm) Waiting for an IP...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
Detecting the provisioner...
Provisioning with fedora...
Copying certs to the local machine directory...
Copying certs to the remote machine...
Checking connection to Podman...
Podman is up and running!
To see how to connect your Podman client to Podman server running on this virtual machine, run: podman-machine env remote-podman-server-vm
```

After you set up your VM succesfully, next step is upgrade the VM to update it's podman version in it.
```bash
$ podman-machine upgrade remote-podman-server-vm
Waiting for SSH to be available...
Detecting the provisioner...
Upgrading podman..
```

Then, the last thing that we need to do is enabling the podman.sock on the VM side. To do so, we first ssh to the VM using "ssh" command then typing some commands to enable it.

> Enable the Podman service on the server
Before performing any Podman client commands, you must enable the podman.sock systemd service on the Linux server. In these examples, we run Podman as a normal, unprivileged user (also known as a rootless user). By default, the rootless socket listens at /run/user/${UID}/podman/podman.sock. You enable this socket permanently using the following command:<br>
$ systemctl --user enable podman.socket<br>
You need to enable linger for this user for the socket to work when the user is not logged in.<br>
$ sudo loginctl enable-linger $USER

```bash
$ podman-machine ssh remote-podman-server-vm
Last login: Wed Feb  3 16:20:08 2021 from 10.0.2.2
[tc@remote-podman-server-vm ~]$ systemctl --user enable podman.socket
Created symlink /home/tc/.config/systemd/user/sockets.target.wants/podman.socket -> /usr/lib/systemd/user/podman.socket.
[tc@remote-podman-server-vm ~]$ sudo loginctl enable-linger $USER
[tc@remote-podman-server-vm ~]$ systemctl --user status podman.socket
* podman.socket - Podman API Socket
   Loaded: loaded (/usr/lib/systemd/user/podman.socket; enabled; vendor preset: enabled)
   Active: inactive (dead)
     Docs: man:podman-system-service(1)
   Listen: /run/user/1000/podman/podman.sock (Stream)
[tc@remote-podman-server-vm ~]$ systemctl --user start podman.socket
[tc@remote-podman-server-vm ~]$ systemctl --user status podman.socket
* podman.socket - Podman API Socket
   Loaded: loaded (/usr/lib/systemd/user/podman.socket; enabled; vendor preset: enabled)
   Active: active (listening) since Wed 2021-02-03 16:29:09 EST; 1s ago
     Docs: man:podman-system-service(1)
   Listen: /run/user/1000/podman/podman.sock (Stream)
   CGroup: /user.slice/user-1000.slice/user@1000.service/podman.socket

Feb 03 16:29:09 remote-podman-server-vm systemd[5509]: Listening on Podman API Socket.
```

Now, you are done at the VM side. The next thing that we need is configuring our client to connect the podman.sock that is running on the VM side. It is also straightforward by the way. There is sub-command exists called "system" to do this kind of configuration.
First, we need to look the details of our VM because we are going to use them while configuring our client
```bash
$ podman-machine env remote-podman-server-vm
export PODMAN_USER="root"
export PODMAN_HOST="127.0.0.1"
export PODMAN_PORT="60146"
export PODMAN_IDENTITY_FILE="/Users/batuhan.apaydin/.local/machine/machines/remote-podman-server-vm/id_rsa"
export PODMAN_IGNORE_HOSTS="true"
export PODMAN_MACHINE_NAME="remote-podman-server-vm"
# Run this command to configure your shell:
# eval $(podman-machine env remote-podman-server-vm)
```

Lets configure our client, to do so first install the podman binary to our host with the make use of brew.
```bash
$ brew install podman
$ podman-machine ip remote-podman-server-vm
192.168.99.102
$  podman system connection add fedbox-remote --identity ~/.local/machine/machines/remote-podman-server-vm/id_rsa ssh://root@192.168.99.102:22/run/user/1000/podman/podman.sock
$ podman system connection list
Name            Identity                                                      URI
fedbox-remote*  /Users/batuhan.apaydin/.local/machine/machines/remote-podman-server-vm/id_rsa  ssh://root@192.168.99.102:22/run/user/1000/podman/podman.sock
```

We can use to create and run our image using podman now.
```bash
$ podman image build -t hello-world:v1 .
STEP 1: FROM golang:1.15.7-alpine AS build
Getting image source signatures
Copying blob sha256:6422294da7d35128e72551ecf15f3a4d9577e5cfa516b6d62fe8b841a9470cb3
Copying blob sha256:4c0d98bf9879488e0407f897d9dd4bf758555a78e39675e72b5124ccf12c2580
Copying blob sha256:9e181322f1e7b3ebee5deeef0af7d13619801172e91d2d73dcf79b5d53d82d91
Copying blob sha256:8b36f00a8e74ce31a867744519cc5db8c4aaeb181cffcda1b4d8269b1cc7f336
Copying blob sha256:5e5ebcc3e85238e4fbf5ab2428f9ed61dcede6c59b605d56b2f02fb991c70850
Copying config sha256:54d042506068c9699d4236315fa76ea8789415c1079bcaff35fb3730ea649547
Writing manifest to image destination
Storing signatures
STEP 2: WORKDIR /app
STEP 3: ENV CGO_ENABLED=0     GOOS=linux     GOARCH=amd64
STEP 4: COPY ./ ./
STEP 5: RUN go build -o hello-world
STEP 6: FROM scratch
STEP 7: COPY --from=build /app/hello-world ./
STEP 8: ENTRYPOINT ["./hello-world"]
STEP 9: COMMIT hello-world:v1
Getting image source signatures
Copying blob sha256:39bc0239cca0d6772ddfd0870ed9a7e59e9a34326b95f1676b99d48112a61d36
Copying config sha256:693f668c708e56bb5eb7610187851b20c8ca0560716a5a5d6d5b7c202a9db13f
Writing manifest to image destination
Storing signatures
--> 693f668c708
693f668c708e56bb5eb7610187851b20c8ca0560716a5a5d6d5b7c202a9db13f
$ podman image list
REPOSITORY                     TAG            IMAGE ID      CREATED             SIZE
localhost/hello-world          v1             693f668c708e  About a minute ago  2.03 MB
docker.io/library/golang       1.15.7-alpine  54d042506068  5 days ago          308 MB
docker.io/library/hello-world  latest         bf756fb1ae65  13 months ago       20 kB
```

Lets run the container
```bash
$ podman container run hello-world:v1
Hello World Podman!!
```
# References
* https://itnext.io/podman-and-skopeo-on-macos-1b3b9cf21e60
* https://developers.redhat.com/blog/2020/02/12/podman-for-macos-sort-of/
* https://www.redhat.com/sysadmin/podman-clients-macos-windows
