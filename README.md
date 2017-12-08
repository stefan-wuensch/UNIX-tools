# UNIX-tools

Various useful UNIX scripts and tools, for Mac and Linux.


## chrome-extension-search.sh

In order to locate Chrome Extensions from only their ID, this generates a Google search URL from each Extension ID found in your Chrome Extensions folder.

Why is this useful? One day all my Chrome Extensions disappeared. _Poof!_ Gone.

The only thing I had was a backup which showed the IDs such as `edacconmaakjimmfgnblocblbcdcpbko`. Not useful if you want to figure out what it is to re-install it! This script at least makes it quick to search Google for that ID, and it very likely will get you a Chrome Store result.

__Optional__: Supply an argument of an alternate directory to search.

(This can be very useful if you are trying to look at a Time Machine backup and figure out which extensions you had at a certain date in the past.)

__Output__: Basic HTML you can use to track down an Extension.

__Example output__:
```
<html>
<a href="https://www.google.com/search?q=fhgenkpocbhhddlgkjnfghpjanffonno">https://www.google.com/search?q=fhgenkpocbhhddlgkjnfghpjanffonno</a> <br>
<a href="https://www.google.com/search?q=jlmadbnpnnolpaljadgakjilggigioaj">https://www.google.com/search?q=jlmadbnpnnolpaljadgakjilggigioaj</a> <br>
</html>
```



## netrc-osxkeychain.sh

I thought this might be interesting / useful... I do lots of stuff with "curl" (REST API calls for example) against password-protected resources. It's been annoying me for a long time that there was no way to leverage the Mac OS Keychain to store authentication credentials that could then be used with curl... so I wrote one.

The reasons why this is useful (I think):
- passwords can be encrypted at rest instead of plaintext $HOME/.netrc file (yes I use FileVault but I HATE having to have passwords in plaintext files anyway!)
- password doesn't have to be given to curl on the command-line as an argument which could be locally snooped via 'ps'  (yes I'm the only user of my Mac but I want to prevent any possible malware from picking it up)
- managing secrets in one place - the Keychain - is easier and better than trying to remember multiple locations

I got this idea from the "osxkeychain" credential.helper that git has on Macs. This extends Keychain-stored secrets to curl as well.

Usage example:

```$ curl --netrc-file <( netrc-osxkeychain.sh "Some Keychain Item" ) https://some-server.domain.tld/blah/```




## vpn-connect.sh

This allows you to quickly connect the Cisco AnyConnect VPN from the Mac command-line (Terminal app).

This script streamlines the connecting to a Cisco VPN. If you use the Cisco AnyConnect VPN client on a Mac,
you don't have to suffer with the GUI app any longer. (I say "suffer" because I'm a UNIX geek and the more
time I can keep my hands on the keyboard and off the mouse the better!) Also I got tired of typing my password
each time I connect, when I knew there was a secure way to store my password already on my Mac.

This reads your VPN login credentials from the *<a href="https://support.apple.com/kb/PH20093">Mac OS Keychain</a>*,
where they can be stored securely! Using the Keychain for credentials storage was actually the reason for
writing this script. If you don't mind typing your username & password etc. each time, you can simply run
`/opt/cisco/anyconnect/bin/vpn` but that's actually more time-consuming than the Mac UI app!

In this script you can customize the two key variables that set defaults for:
- the name of the Keychain Item which contains your VPN login credentials
- the name of the VPN target device

Once you customize those two variables (or simply give those two parameters as command-line arguments) then
you can connect to the VPN with a single CLI command.

Yay!!! Time saved from doing repetitive tasks is more time to do cool things!!
