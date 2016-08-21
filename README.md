# pam_ssh_limit_ip

Limit user logins by IP using pam_exec module

# What this is

Basically an idea I had and now a proof of concept. I also like using pam_exec when I don't want to write a custom module in C. Maybe this will give some other people ideas of what to do with the PAM auth subsystem - its very powerful and flexible!

# What this isn't

A perfect or probably a "real" solution  - its more of a deterrent and a pet project I wanted to see if I could do

# Why?

I needed a way to limit people by IPs connecting via SSH. Effectively I wanted to "pin" a user to an IP until they had no more connections from that IP. Once disconnected, they can log in from another IP. A lot of the solutions I found would have required constant changes to support and this didn't scale well enough for me.

In its shortest example: Say you have User A and User B sitting in the same VLAN at your office and you dont want them sharing SSH account "myapp" at the same time. This makes it so they cant, without an additional hop / annoyance to them
 - like User B SSH'ing to User A's desktop and then bouncing off of his machine in to the server in question

# Why PAM?

* SSH allows you to use Match blocks but this was too much of a static configuration for me. I needed something more event driven

* SSH ForceCommand is run after the users environment is loaded, so there are ways around it

* /etc/profile.d is loaded every time a shell is loaded. So maybe could have been leveraged but more hacks to put in to make sure we were an SSH connection

* PAM has an sshd file which I leveraged. I can then guarantee that this check is done in memory/processing and the user is not able to break out of it. Further, its the last step before invoking a TTY to a user

* Had all the information I needed

# Next?

* Make it more self sufficient. Dont rely on w command output and ping command output

# Install

* Copy etc/pam_session.sh to /etc/ and then chmod 755 /etc/pam_session.sh
* Update /etc/pam.d/sshd and place the following line at the bottom of the file

session    required    pam_exec.so seteuid stdout /etc/pam_session.sh
