// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.7.0 <0.8.20;

interface IVerifier {
  function verifyProof(
    uint256[2] memory _pA,
    uint256[2][2] memory _pB,
    uint256[2] memory _pC,
    uint256[7] memory _pubSignals
  ) external view returns (bool);
}

contract Test {

    IVerifier zkVerifier;

    constructor(address _verifier) {
        zkVerifier = IVerifier(_verifier);
    }

    address payable owner = payable(0x79d78e89419839Ff45EED419B41E5c6b04F839c0); // just a random ganache address atm

    event ListingCreated(bytes ipfsCid, string fileType, uint priceInEth, uint royaltyPercentage, bytes4 fileCategory, uint howManyDKeysForSale);
    event PaymentReceived(bytes indexed ipfsCidIndexed, bytes ipfsCid, uint[2] bobDecryptingPubKey, address bobEthAddress, uint bobBidAmount, bool bobCanFillThisBid);
    event ReencryptedKeyProvided(string fileType, bytes ipfsCid, uint indexed bobDecryptingPubKey, uint[4] dKey, uint bobDecryptingPubKeyX);
    event BobsCanNowSellKeys(bytes indexed ipfsCidIndexed, bytes ipfsCid);
    event BidReclaimed(bytes indexed ipfsCid, uint bobDecryptingPubKeyX);

    mapping (bytes => Listing) public allListings;
    mapping (bytes => bool) public existingListings;

    struct Listing {
        string fileType;
        uint howManyDKeysForSale;
        uint howManyDKeysSold;
        uint priceInEth; 
        uint royaltyPercentage; // should be uint8
        uint poseidonHashedSecretKey; 
        address payable aliceEthAddress;
        mapping (uint => bool) bobsThatHavePaid; // using x-value of bob's decrypting public key only (can't map a uint[2]) -- this should(?) be secure... other option is concatenate, then do the mapping....
        mapping (uint => uint) bobsByBidAmounts;
        mapping (uint => bool) bobsThatHaveBeenProvidedDKeys;
        mapping (uint => uint) bobsByEthAddress;
        bool bobsCanSellTheirDkeys;
    } 
    
    function aliceCreatesListing(string memory _fileType, bytes memory _ipfsCid, uint _howManyDKeysForSale, uint _priceInEth, uint _royaltyPercentage, uint _poseidonHashedSecretKey, bytes4 _fileCategory) public {
        require(existingListings[_ipfsCid] == false); 
        require(_royaltyPercentage < 100 && _royaltyPercentage > 0, "royalty amount must be greater than 0% and less than 100%");
        Listing storage newListing = allListings[_ipfsCid];
        newListing.howManyDKeysForSale = _howManyDKeysForSale;
        newListing.howManyDKeysSold = 0;
        newListing.priceInEth = _priceInEth;
        newListing.royaltyPercentage = _royaltyPercentage;
        newListing.fileType = _fileType;
        newListing.poseidonHashedSecretKey = _poseidonHashedSecretKey;
        newListing.aliceEthAddress = payable(msg.sender);
        existingListings[_ipfsCid] = true;
        emit ListingCreated(_ipfsCid, _fileType, _priceInEth, _royaltyPercentage, _fileCategory, _howManyDKeysForSale);
    }

    function bobSendsPaymentToListing(bytes memory _ipfsCid, uint[2] memory _bobDecryptingPubKey) public payable {
        require(existingListings[_ipfsCid] == true, "listing does not exist");
        Listing storage thisListing = allListings[_ipfsCid];
        require (msg.value > thisListing.priceInEth, "bids must be > alice's specified amount");
        require(allListings[_ipfsCid].bobsThatHavePaid[_bobDecryptingPubKey[0]] == false);
        require(allListings[_ipfsCid].bobsByEthAddress[uint256(uint160(address(msg.sender)))] == 0, "only 1 bid per address"); // do we want this? this currently makes it so that an eth address can only ever own 1 dkey per listing -- could change this by removing the address from the mapping in aliceSendsDKey()
        allListings[_ipfsCid].bobsThatHavePaid[_bobDecryptingPubKey[0]] = true;
        emit PaymentReceived(_ipfsCid, _ipfsCid, _bobDecryptingPubKey, msg.sender, msg.value, allListings[_ipfsCid].bobsCanSellTheirDkeys);
        allListings[_ipfsCid].bobsByBidAmounts[_bobDecryptingPubKey[0]] = msg.value;
        allListings[_ipfsCid].bobsByEthAddress[uint256(uint160(address(msg.sender)))] = _bobDecryptingPubKey[0];
    }
    
    function aliceSendsDKey(bytes memory _ipfsCid, uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[7] calldata _pubSignals) public {
        // limits alice to only selling as many dkeys as she originally specified in the Listing
        require(allListings[_ipfsCid].bobsCanSellTheirDkeys == false);

        // save bob's address + dkey to variables (likely that dKey doesn't need to be temporarily saved to memory...)
        uint[2] memory bobDecryptingPubKey;
        bobDecryptingPubKey[0] = _pubSignals[5];
        bobDecryptingPubKey[1] = _pubSignals[6];
        
        uint[4] memory dKey;
        dKey[0] = _pubSignals[0];
        dKey[1] = _pubSignals[1];
        dKey[2] = _pubSignals[2];
        dKey[3] = _pubSignals[3];

        // require poseidon hashed secret key in _pubSignals matches the Listing -- this should also serve to confirm if the listing exists (in case alice's frontend has called with incorrect _ipfsCid)
        require(_pubSignals[4] == allListings[_ipfsCid].poseidonHashedSecretKey);
        
        // ensure that this bob has not yet been provided a dkey ...... can this be exploited by alice creating a proof for bob's valid x value (_pubSignals[5]) but using a made up y value? (i dont think so -- should only be one valid y coord for a given x coord, and the proof circuit has a check that the point is on curve)
        require(allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKey[0]] == true && allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] == false, "this bob has not paid, or was already provided a dkey");

        // verify proof
        bool result = zkVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        require(result == true);

        // emit event so that Bob can listen for when the dkey is posted on-chain
        emit ReencryptedKeyProvided(allListings[_ipfsCid].fileType, _ipfsCid, bobDecryptingPubKey[0], dKey, bobDecryptingPubKey[0]);
        
        // send 99% of bob's bid amount to alice, and send remainder to "owner" contract. is there going to be a small error (+/- some wei) in what the transfer amounts should be as a result of the division?
        uint256 bidAmount = allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKey[0]];
        uint256 aliceTransferAmount = bidAmount * 99 / 100;
        uint256 ownerTransferAmount = bidAmount * 1 / 100;
        allListings[_ipfsCid].aliceEthAddress.transfer(aliceTransferAmount); 
        owner.transfer(ownerTransferAmount);

        // show that this bob has been provided a dkey (to prevent alice sending the same dkey repeatedly to drain the smart contract & also show that this bob owns a dkey)
        allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] = true;

        // increment how many keys sold by 1
        allListings[_ipfsCid].howManyDKeysSold += 1;

        // check to see if enough dkeys have been sold by alice that bobs can now sell dkeys, and update bool accordingly. also firing an event for bob's front end to know that he is now able to sell his dkey.
        if (allListings[_ipfsCid].howManyDKeysForSale - allListings[_ipfsCid].howManyDKeysSold == 0) {
            allListings[_ipfsCid].bobsCanSellTheirDkeys = true;
            emit BobsCanNowSellKeys(_ipfsCid, _ipfsCid);
        }
    }
    
    // whole lotta "bob" getting thrown around here... this is 1 bob responding with a dkey to another bob's bid...
    function bobSendsDKey(bytes memory _ipfsCid, uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[7] calldata _pubSignals) public {
        require(allListings[_ipfsCid].bobsCanSellTheirDkeys == true, "alice has not yet sold the req'd # of dkeys in order for bobs to sell");

        uint[2] memory bobDecryptingPubKey;
        bobDecryptingPubKey[0] = _pubSignals[5];
        bobDecryptingPubKey[1] = _pubSignals[6];
        
        uint[4] memory dKey;
        dKey[0] = _pubSignals[0];
        dKey[1] = _pubSignals[1];
        dKey[2] = _pubSignals[2];
        dKey[3] = _pubSignals[3];

        require(_pubSignals[4] == allListings[_ipfsCid].poseidonHashedSecretKey, "poseidon hash of the key does not match");
        
        require(allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKey[0]] == true && allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] == false, "this bob has not paid, or was already provided a dkey");

        bool result = zkVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        require(result == true, "verification of zk proof failed");

        emit ReencryptedKeyProvided(allListings[_ipfsCid].fileType, _ipfsCid, bobDecryptingPubKey[0], dKey, bobDecryptingPubKey[0]);
        
        uint256 bidAmount = allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKey[0]];
        uint256 royaltyAmount = allListings[_ipfsCid].royaltyPercentage;
        uint256 aliceTransferAmount = bidAmount * royaltyAmount / 100;
        uint256 bobTransferAmount = bidAmount * (99 - royaltyAmount) / 100;
        uint256 ownerTransferAmount = bidAmount / 100;
        
        allListings[_ipfsCid].aliceEthAddress.transfer(aliceTransferAmount); 
        payable(msg.sender).transfer(bobTransferAmount); 
        owner.transfer(ownerTransferAmount);

        allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKey[0]] = true;

        // not needed, but leaving this cuz how many times a key changes hands could still be interesting... maybe for a "listing leaderboard"?
        allListings[_ipfsCid].howManyDKeysSold += 1;
    }

    function bobReclaimsBid(bytes memory _ipfsCid) public {
        uint256 bobDecryptingPubKeyX = allListings[_ipfsCid].bobsByEthAddress[uint256(uint160(address(msg.sender)))];
        uint256 returnAmount = allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKeyX];
        require(allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKeyX]);
        require(!allListings[_ipfsCid].bobsThatHaveBeenProvidedDKeys[bobDecryptingPubKeyX], "this address has already been provided a DKEY");
        
        allListings[_ipfsCid].bobsThatHavePaid[bobDecryptingPubKeyX] = false;

        delete allListings[_ipfsCid].bobsByBidAmounts[bobDecryptingPubKeyX];
        delete allListings[_ipfsCid].bobsByEthAddress[uint256(uint160(address(msg.sender)))];

        payable(msg.sender).transfer(returnAmount);

        emit BidReclaimed(_ipfsCid, bobDecryptingPubKeyX); // emit this event so alice can filter out reclaimed bids -- or make a view function where alice can see what bobs have made bids..?
    }
}

// TODO: create "DKEY" ERC20 token. "owner" contract should allow token holders to claim a share of the fees proportionate to their share of the token supply.