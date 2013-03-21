Keyspace
========
[![Build Status](https://secure.travis-ci.org/livingsocial/keyspace.png?branch=master)](http://travis-ci.org/livingsocial/keyspace)
[![Code Climate](https://codeclimate.com/github/livingsocial/keyspace.png)](https://codeclimate.com/github/livingsocial/keyspace)
[![Coverage Status](https://coveralls.io/repos/livingsocial/keyspace/badge.png?branch=master)](https://coveralls.io/r/livingsocial/keyspace)

End-to-end (i.e. client-side) encryption for key/value stores, using
[RbNaCl][rbnacl] for security and [Moneta][moneta] for persistence.

[rbnacl]: https://github.com/cryptosphere/rbnacl
[moneta]: https://github.com/minad/moneta

About
-----

Keyspace is an encrypted name/value store which emphasizes a "least authority"
philosophy for information sharing. All data is stored as encrypted name/value
pairs, and data can be organized into "vaults" which each have independent
encryption tokens and access control.

Keyspace uses [capability-based security][capabilities] to manage access to vaults.
Each capability takes the form of cryptographic tokens which are unique
to a particular vault. Knowledge of these tokens is necessary and sufficient to
gain access to a particular vault. Such an access scheme is known as
"capabilities as keys" or "cryptographic capabilities". This approach provides
secure sharing of access to vaults.

This means there is no access control system (e.g. RBAC) other than the capability
tokens themselves. Authorization is handled completely by whether or not you have
the necessary cryptographic tokens to carry out a desired action. This
straightforward approach leaves little room for error and reduces the entire attack
surface to vulnerabilities in the cryptographic code or leaked capability tokens.

Keyspace is built on [Moneta][moneta], an abstract API to many kinds of key/value
stores including all ActiveRecord compatible databases, Redis, Riak, Cassandra,
CouchDB, MongoDB, and many others. If there's a key/value store you would like
to persist to, Moneta probably supports it.

Cryptogarphy in Keyspace is handled by [RbNaCl][rbnacl], a Ruby wrapper to the
[Networking and Cryptography][nacl] library by Daniel J. Bernstein.

[capabilities]: http://en.wikipedia.org/wiki/Capability-based_security
[nacl]: http://nacl.cr.yp.to/

Status
------

![DANGER: EXPERIMENTAL](https://raw.github.com/livingsocial/keyspace/master/images/experimental.png)

Keyspace is still experimental and the design is subject to change.

Mailing List
------------

If you're interested in using Keyspace, join the mailing list by sending a
message to:

* [keyspace@librelist.com](mailto:keyspace@librelist.com)

Capabilities
------------

Capabilities are (relatively) short tokens which grant a specific type of
authority within Keyspace. Knowledge of a capability is necessary and
sufficient to gain a particular type of access. Capabilities can also be
"degraded", so that a capability holder can grant others a limited subset
of the authority granted to them by the capability they hold.

A capability token looks like the following:

    ks.write:foobar@d2hotnrmcxsqgibpszqoj6mowovsmmq4ajgy626qavbtk74tsbk5bqjypkhjlmbsqy7266umric6vn7iasaa6ccljqzrr7d35dqrh7i

There are 3 parts to the capability token:

* "ks.write": URI scheme indicating this is a Keyspace (i.e. "ks") writecap
  There are three capability levels (see below)
* "foobar": the name of the vault this writecap provides access to
* "d2hotnrmcxsqgibpsz...": A Base32-encoded string containing the cryptographic
  keys which control access to this vault.

There are three capability levels for each vault:

* **verifycap** (ks.verify): Can determine a value is authentic, but can't decrypt it
* **readcap** (ks.read): Can read values from within the vault, but cannot write to it
* **writecap** (ks.write): Can write new values into the vault

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
encrypted using NaCl's "SecretBox" primitive (i.e. XSalsa20 + Poly1305)
and signed with the Ed25519 digital signature algorithm prior to transmission
to the server, and remains encrypted until accessed by another client with the
read (or verify) capabilities.

Ruby Client
-----------

Keyspace provides a simple Ruby client for storing and retrieving encrypted
data from the server. In this example, a system operator creates a vault,
puts a value inside of it, and then saves the vault to the server:

```ruby
>> vault = Keyspace::Client::Vault.create("myvault")
 => #<Keyspace::Client::Vault ks.write:myvault@d4u5qekdyezqlugxmht...ir2r3nbcd>
>> vault[:foobar] = "baz"
 => "baz"
>> vault.save!
 => true
```

The system administrator can then degrade the capability for this vault to
a readcap prior to disseminating it to a system user:

```ruby
>> vault.capability.degrade(:readcap).to_s
 => "ks.read:myvault@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi"
```

We'll now switch to the perspective of a system user who has been given the
readcap created above. First, they'll set the server URL and create a new
vault object from the readcap. They'll then be able to access values from
this vault by key, but they cannot make changes:

```ruby
>> Keyspace::Client.url = "http://127.0.0.1:4567"
 => "http://127.0.0.1:4567"
>> vault = Keyspace::Client::Vault.new("ks.read:myvault@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi")
 => #<Keyspace::Client::Vault "ks.read:myvault@d4u5qekdyezqlugxmhtuerytyyjp4fqjqsgbqjhfgm5mnw...daokugjdi">
>> vault[:foobar]
 => "baz"
>> vault[:foobar] = "can't touch this"
Keyspace::InvalidCapabilityError: don't have write capability for this vault: myvault
        from /Users/tony/dev/keyspace/lib/keyspace/client/vault.rb:56:in `put'
        from (irb):9
        from /Users/tony/.rvm/rubies/ruby-1.9.3-p194/bin/irb:16:in `<main>'
```

Security Notes
--------------

Keyspace is built on state-of-the-art cryptographic primitives, but
that alone does not make for a secure system. It is yet to be audited
by an expert cryptographer, and for that reason alone should be somewhat
suspect in the eyes of anyone interested in its security.

For that reason alone, Keyspace should be experimental until audited by
cryptographic experts.

Reporting Security Problems
---------------------------

If you have discovered a bug in Keyspace of a sensitive nature, i.e.
one which can compromise the security of Keyspace users, you can
report it securely by sending a GPG encrypted message. Please use
the following key:

https://raw.github.com/livingsocial/keyspace/master/keyspace.gpg

The key fingerprint is (or should be):

`190E 42D6 8327 A515 BFDF AAE0 B210 269D BB2D 8787`

Suggested Reading
-----------------

Keyspace is inspired by the cryptographic capabilities system implemented in
[Tahoe: The Least Authority Filesystem](https://tahoe-lafs.org/~zooko/lafs.pdf).

License
-------

This software is released under the MIT license:

Copyright (C) 2013, LivingSocial, Inc.

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

