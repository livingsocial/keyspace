Keyspace
========
[![Build Status](https://secure.travis-ci.org/livingsocial/keyspace.png?branch=master)](http://travis-ci.org/livingsocial/keyspace)

Keyspace is an encrypted key/value store which emphasizes a "least authority"
philosophy for information sharing. All data is stored as encrypted key/value
pairs, and data can be organized into "vaults" which each have independent
encryption tokens and access control.

Keyspace uses the capability access control model to manage access to vaults.
Each capability takes the form of cryptographic tokens which are unique to a
particular vault. Knowledge of these tokens is necessary and sufficient to
gain access to a particular vault. Such an access scheme is known as
"capabilities as keys" or "cryptographic capabilities". This approach provides
secure sharing of access to vaults.

Capabilities
------------

A capability token looks like the following:

    foobar:rw@d2hotnrmcxsqgibpszqoj6mowovsmmq4ajgy626qavbtk74tsbk5bqjypkhjlmbsqy7266umric6vn7iasaa6ccljqzrr7d35dqrh7i

There are 3 parts to the capability token:

* "foobar": the name of the vault this capability controls access to
* "rw": this indicates this capability has read-write access, which makes
  this capability a "writecap". There are three capability levels (see below)
* "d2hotnrmcxsqgibpsz...": A Base32-encoded string containing the cryptographic
  keys which control access to this vault.

There are three capability levels for each vault:

* verifycap (v): Can determine a value is authentic, but can't decrypt it
* readcap (r):   Can read values from within the vault, but cannot write to it
* writecap (rw): Can write new values into the vault

Each set of capabilities builds upon the last: users with the read capability
can also verify, and users with the write capability can also read. Users who
have access to a vault can delegate access to other users simply by sharing
their capability token. Users can also degrade capabilities, i.e. they can
produce read-verify tokens from a write-read-verify token, and verify only
tokens from a read-verify token (or write-read-verify token).

Data Flow
---------

![Data Flow Diagram](https://raw.github.com/livingsocial/keyspace/master/dataflow.png)

Keyspace provides a separation between the powers of system administrators
to alter the system configuration, system users who want to consume and verify
the authenticity of configuration data, and the server, which is a dumb
datastore which will save any values it can verify.

Server
------

Keyspace provides a Sinatra service for writing to and reading from vaults. The
Sinatra service itself has only the verify capability, meaning that if it is
ever compromised, the attacker cannot read the contents of the Keyspace.
Furthermore, they cannot alter the system configuration, because they will be
unable to sign new values without the writecap.

All encryption of plaintext happens client-side via a command line tool which
runs on a computer under the control of a trusted administrator. Data is
encrypted using AES256 CBC mode prior to transmission to the server, and
remains encrypted until accessed by another user with the read (or verify)
capabilities.

Ruby Client
-----------

Keyspace provides a simple Ruby client for storing and retrieving encrypted
data from the server. In this example, a system operator creates a vault,
puts a value inside of it, and then saves the vault to the server:

    >> vault = Keyspace::Client::Vault.create("myvault")
     => #<Keyspace::Client::Vault myvault:rw@d4u5qekdyezqlugxmht...ir2r3nbcd>
    >> vault[:foobar] = "baz"
     => "baz"
    >> vault.save!
     => true

The system administrator can then degrade the capability for this vault to
a readcap prior to disseminating it to a system user:

    >> vault.capability.degrade(:readcap).to_s
     => "myvault:r@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi"

We'll now switch to the perspective of a system user who has been given the
readcap created above. First, they'll set the server URL and create a new
vault object from the readcap. They'll then be able to access values from
this vault by key, but they cannot make changes:

    >> Keyspace::Client.url = "http://127.0.0.1:4567"
     => "http://127.0.0.1:4567"
    >> vault = Keyspace::Client::Vault.new("myvault:r@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi")
     => #<Keyspace::Client::Vault "myvault:r@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi">
    >> vault[:foobar]
     => "baz"
    >> vault[:foobar] = "can't touch this"
    Keyspace::InvalidCapabilityError: don't have write capability for this vault: myvault
            from /Users/tony/dev/keyspace/lib/keyspace/client/vault.rb:56:in `put'
            from (irb):9
            from /Users/tony/.rvm/rubies/ruby-1.9.3-p194/bin/irb:16:in `<main>'


Suggested Reading
-----------------

Keyspace is inspired by the cryptographic capabilities system implemented in
[Tahoe: The Least Authority Filesystem](https://tahoe-lafs.org/~zooko/lafs.pdf).

License
-------

This software is released under the MIT license:

Copyright (C) 2012, LivingSocial, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

