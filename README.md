## About

what is the DKEY protocol?
- a DKEY is a Decryption KEY that an ALICE creates for a paying BOB, that allows access to a specified ENCRYPTED FILE.
- ALICE sells DKEYs by first encrypting a file, then creating a LISTING:
    - a LISTING is where all the necessary data for ALICEs & BOBs to transact is stored and updated 
    - a LISTING exists on the blockchain, and is referenced by the IPFS HASH of the ENCRYPTED FILE
    - in a LISTING, ALICE specifies:
        - how many DKEYs will be for sale
        - a DKEY's sale price
        - what royalty (%) she will receive on all future sales of the DKEY
    - each LISTING tracks:
        - ALICE's blockchain address
        - which BOBs have made bids
        - the value of a given BOB's bid
        - how many DKEYs have been sold
        - which BOBs own DKEYs
- BOB will visit a LISTING (after getting the IPFS HASH from ALICE) and be prompted to make a payment. The SMART CONTRACT will hold the payment. *If* ALICE responds to the payment with a valid DKEY (ie: encrypted for the paying BOB’s public key), *then* the funds will be transferred to ALICE. The SMART CONTRACT uses a zkSNARK to validate the key was properly encrypted. 
- once ALICE has sold her specified amount of DKEYs, BOBs will be able to sell their DKEYs on to CHARLIEs, then CHARLIEs on to DAVEs, etc… all the while, ALICE’s specified royalty amount will be given to her with each sale of a key.
- with each DKEY sale, a small transaction fee (1%) will also be levied against the purchaser — these fees will be accumulated and distributed to $DKEY token holders.

what’s in the development pipeline?
- frontend:
    - a dashboard page, where:
        - LISTING leaderboard shows popular LISTINGs
        - BOBs can search for LISTINGs by category, file type, etc
        - ALICEs can post LISTING info, thumbnails, artwork, etc
        - BOBs can leave reviews/ratings
    - js improvements (error checking, efficiency, etc)
    - ALICE and BOB pages to both be static pages on ipfs
- protocol:
    - gas optimizations
        - byte packing, don’t need to save variables to memory in functions, other things I've missed...
    - auditing
        - smart contracts
        - cryptography (confirm zk circuit & el gamal are implemented correctly)
        - front end (finalize production frontend)
    - scale/improve UX
        - use a subgraph (or Infura API?) to query event data
        - give option to use local IPFS node *or* an API for uploading/pinning/retrieval
    - $DKEY ERC20 token + fee distribution mechanism
        - create token contract
            - accumulated fees to be issued to token holders
            - governance
                - token holders can vote on proposals (protocol changes, “official” frontends, etc)
                - a portion of the accumulated fees to go to further protocol development

## Usage

** This repo should be used as a demo only. Use the steps below to set up a local blockchain and see the smart contract & zkSNARKs work. N.B.: none of the smart contracts or proof circuits have been audited at this time. **

...

Download the repo (click on the green "<> Code" button above, then "Download ZIP"). 

Open up terminal (Mac) or cmd (Windows) and navigate to the unzipped folder, ex:
```bash
$ cd downloads
$ cd dkey-main
```

If you don't have them, download Ganache (https://trufflesuite.com/ganache/) and Node (https://nodejs.org/en/download).
- Open Ganache and set up a new Workspace with:
    - NETWORK ID: 5777
    - PORT: 8080
    - under "TRUFFLE PROJECTS", link to the truffle-config.js file

Use truffle to deploy contracts:
```bash
$ npm install -g truffle
$ truffle migrate
```

From the terminal, grab the contract address that 'Test' is deployed to.

*This web app currently requires Agregore Web Browser's built-in IPFS compatibility (download it here https://github.com/AgregoreWeb/agregore-browser/releases/latest). You will have to download and install MetaMask's Chromium extension on Agregore (https://agregore.mauve.moe/docs/extensions). I found it was easiest to install the extension on Brave browser first (https://metamask.io/download/), then navigate to where Brave extensions are stored -- on Mac:
    - open a Finder window
    - press `Command + Shift + G`
    - type `~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions`
Once you've found the MetaMask extension folder, drag and drop it into the Agregore extensions folder.

Now, serve ALICE's website:
```bash
$ npm install -g http-server
$ cd dist-alice
$ http-server
```

Then, open up another terminal and serve BOB's website:
```bash
$ cd ..
$ cd dist-bob
$ http-server
```

Open up Agregore Browser and open 2 windows. Go to http://localhost:8081/ for ALICE's page, and http://localhost:8082/ for BOB's page (or whatever 'http-server' gives -- this assumes Ganache is already running on 8080).

In the MetaMask browser extension: 
- set up a new network by going to Settings > Networks > Add a network > Add a network manually (set it to match Ganache's RPC URL: HTTP://127.0.0.1:8080).
- create two new Metamask Accounts (one for ALICE and one for BOB): 
    - grab the private keys for each of the top two addresses under the "ACCOUNTS" tab in the Ganache Workspace (click on the key icon on the right, copy the private key)
    - click on the Account drop down, then "+ Add account or hardware wallet", then "Import Account", and paste in the private key
- manually connect MetaMask to the website (if it doesn't do so automatically):
    - click the three dots at the top right > "Connected sites" > "Manually connect to current site"

Now you should be ready to go!

First, you'll have to run the 'setup' command and input the 'Test' smart contract address.
(Do the same when you get to Bob's page)

And the rest should be easy enough to follow! 

...

Big thanks to:
- https://github.com/meixler/web-browser-based-file-encryption-decryption/blob/ec55f1fa9c8c02d8a8048777f67ca77021b9a207/web-browser-based-file-encryption-decryption.html#L255
- https://github.com/Shigoto-dev19/ec-elgamal-circom
- https://agregore.mauve.moe/
- circom/snarkjs

(for all the packages/pieces of code I've borrowed).

Get in touch if you're interested in collaborating!

-noad