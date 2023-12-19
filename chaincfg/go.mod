module github.com/btcsuite/btcd/chaincfg/v2

require (
	github.com/btcsuite/btcd/chainhash/v2 v2.0.0
	github.com/btcsuite/btcd/wire/v2 v2.0.0
	github.com/davecgh/go-spew v1.1.1
)

require (
	golang.org/x/crypto v0.17.0 // indirect
	golang.org/x/sys v0.15.0 // indirect
)

// TODO(guggero): Remove once we have a tagged version of the chainhash package.
replace github.com/btcsuite/btcd/chainhash/v2 => ../chainhash

// TODO(guggero): Remove once we have a tagged version of the wire package.
replace github.com/btcsuite/btcd/wire/v2 => ../wire

go 1.19
