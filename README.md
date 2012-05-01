Vault
=====

Vault is a simple bucketed encrypted key/value store which emphasizes a 
"least authority" philosophy for information sharing. Access is controlled at
the bucket level and the following sets of capabilities are provided:

* Verify: Can determine a value is authentic, but can't decrypt it
* Read:   Can read values from within the bucket, but cannot write to the bucket
* Write:  Can write new values into the bucket

Vault provides a Sinatra service for writing to and reading from buckets. The
Sinatra service itself has only the verify capability, meaning that if it is
ever compromised, the attacker cannot read the contents of the Vault. Instead,
the Vault merely accepts any new data it can verify.