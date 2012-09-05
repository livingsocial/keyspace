Keyspace
========

Vault is an encrypted key/value store which emphasizes a "least authority"
philosophy for information sharing. All data is stored as encrypted key/value
pairs, and data can be organized into "buckets" (ala Amazon S3) which each
have independent encryption tokens and access control.

Vault uses the capability access control model to manage access to buckets.
Each capability takes the form of cryptographic tokens which are unique to a
particular bucket. Knowledge of these tokens is necessary and sufficient to
gain access to a particular bucket. Such an access scheme is known as
"capabilities as keys" or "cryptographic capabilities". This approach provides
secure sharing of access to buckets.

Capabilities
------------

A capability token looks like the following:

    foobar:rw@d2hotnrmcxsqgibpszqoj6mowovsmmq4ajgy626qavbtk74tsbk5bqjypkhjlmbsqy7266umric6vn7iasaa6ccljqzrr7d35dqrh7i

There are 3 parts to the capability token:

* "foobar": the name of the bucket this capability controls access to
* "rw": this indicates this capability has read-write access, which makes
  this capability a "writecap". There are three capability levels (see below)
* "d2hotnrmcxsqgibpsz...": A Base32-encoded string containing the cryptographic
  keys which control access to this bucket.

There are three capability levels for each bucket:

* verifycap (v): Can determine a value is authentic, but can't decrypt it
* readcap (r):   Can read values from within the bucket, but cannot write to it
* writecap (rw): Can write new values into the bucket

Each set of capabilities builds upon the last: users with the read capability
can also verify, and users with the write capability can also read. Users who
have access to a bucket can delegate access to other users simply by sharing
their capability token. Users can also degrade capabilities, i.e. they can
produce read-verify tokens from a write-read-verify token, and verify only
tokens from a read-verify token (or write-read-verify token).

Server
------

Vault provides a Sinatra service for writing to and reading from buckets. The
Sinatra service itself has only the verify capability, meaning that if it is
ever compromised, the attacker cannot read the contents of the Vault.
Furthermore, they cannot alter the system configuration, because they will be
unable to sign new values without the writecap.

All encryption of plaintext happens client-side via a command line tool which
runs on a computer under the control of a trusted administrator. Data is
encrypted using AES256 CBC mode prior to transmission to the server, and
remains encrypted until accessed by another user with the read (or verify)
capabilities.

Suggested Reading
-----------------

Vault is inspired by the cryptographic capabilities system implemented in
[Tahoe: The Least Authority Filesystem](https://tahoe-lafs.org/~zooko/lafs.pdf).
