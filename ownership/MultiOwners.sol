pragma solidity ^0.4.23;


import '../openzeppelin-solidity-112/contracts/math/SafeMath.sol';
import "../openzeppelin-solidity-112/contracts/ownership/DelayedClaimable.sol";
import "../openzeppelin-solidity-112/contracts/access/rbac/RBAC.sol";
import "../utils/StringUtils.sol";


/**
 * @title Whitelist
 * @dev The Whitelist contract has a whitelist of addresses, and provides basic authorization control functions.
 * @dev This simplifies the implementation of "user permissions".
 */
contract MultiOwners is DelayedClaimable, RBAC {
  using SafeMath for uint256;
  using StringUtils for string;

  mapping (string => uint256) private authorizations;
  mapping (address => string) private ownerOfSides;
//   mapping (string => mapping (string => bool)) private voteResults;
  mapping (string => uint256) private sideExist;
  mapping (string => mapping (string => address[])) private sideVoters;
  address[] public owners;
  string[] private authTypes;
//   string[] private ownerSides;
  uint256 public multiOwnerSides;
  uint256 ownerSidesLimit = 5;
//   uint256 authRate = 75;
  bool initAdd = true;

  event OwnerAdded(address addr, string side);
  event OwnerRemoved(address addr);
  event InitialFinished();

  string public constant ROLE_MULTIOWNER = "multiOwner";
  string public constant AUTH_ADDOWNER = "addOwner";
  string public constant AUTH_REMOVEOWNER = "removeOwner";
//   string public constant AUTH_SETAUTHRATE = "setAuthRate";

  /**
   * @dev Throws if called by any account that's not multiOwners.
   */
  modifier onlyMultiOwners() {
    checkRole(msg.sender, ROLE_MULTIOWNER);
    _;
  }
  
  /**
   * @dev Throws if not in initializing stage.
   */
  modifier canInitial() {
    require(initAdd);
    _;
  }

  /**
   * @dev the msg.sender will authorize a type of event.
   * @param _authType the event type need to be authorized
   */
  function authorize(string _authType) onlyMultiOwners public {
    string memory side = ownerOfSides[msg.sender];
    address[] storage voters = sideVoters[side][_authType];

    if (voters.length == 0) {
      // if the first time to authorize this type of event
      authorizations[_authType] = authorizations[_authType].add(1);
    //   voteResults[side][_authType] = true;
    }

    // add voters of one side
    uint j = 0;
    for (; j < voters.length; j = j.add(1)) {
      if (voters[j] == msg.sender) {
        break;
      }
    }

    if (j >= voters.length) {
      voters.push(msg.sender);
    }

    // add the authType for clearing auth
    uint i = 0;
    for (; i < authTypes.length; i = i.add(1)) {
      if (authTypes[i].equal(_authType)) {
        break;
      }
    }

    if (i >= authTypes.length) {
      authTypes.push(_authType);
    }
  }

  /**
   * @dev the msg.sender will clear the authorization he has given for the event.
   * @param _authType the event type need to be authorized
   */
  function deAuthorize(string _authType) onlyMultiOwners public {
    string memory side = ownerOfSides[msg.sender];
    address[] storage voters = sideVoters[side][_authType];

    for (uint j = 0; j < voters.length; j = j.add(1)) {
      if (voters[j] == msg.sender) {
        delete voters[j];
        break;
      }
    }

    // if the sender has authorized this type of event, will remove its vote
    if (j < voters.length) {
      for (uint jj = j; jj < voters.length.sub(1); jj = jj.add(1)) {
        voters[jj] = voters[jj.add(1)];
      }

      delete voters[voters.length.sub(1)];
      voters.length = voters.length.sub(1);
      
      // if there is no votes of one side, the authorization need to be decreased
      if (voters.length == 0) {
        authorizations[_authType] = authorizations[_authType].sub(1);
      //   voteResults[side][_authType] = true;
      }

      // if there is no authorization on this type of event, 
      // this event need to be removed from the list 
      if (authorizations[_authType] == 0) {
        for (uint i = 0; i < authTypes.length; i = i.add(1)) {
          if (authTypes[i].equal(_authType)) {
            delete authTypes[i];
            break;
          }
        }
        for (uint ii = i; ii < authTypes.length.sub(1); ii = ii.add(1)) {
          authTypes[ii] = authTypes[ii.add(1)];
        }

        delete authTypes[authTypes.length.sub(1)];
        authTypes.length = authTypes.length.sub(1);
      }
    }
  }

  /**
   * @dev judge if the event has already been authorized.
   * @param _authType the event type need to be authorized
   */
  function hasAuth(string _authType) public view returns (bool) {
    require(multiOwnerSides > 1); // at least 2 sides have authorized
    
    // uint256 rate = authorizations[_authType].mul(100).div(multiOwnerNumber)
    return (authorizations[_authType] == multiOwnerSides);
  }

  /**
   * @dev clear all the authorizations that have been given for a type of event.
   * @param _authType the event type need to be authorized
   */
  function clearAuth(string _authType) internal {
    authorizations[_authType] = 0; // clear authorizations
    for (uint i = 0; i < owners.length; i = i.add(1)) {
      string memory side = ownerOfSides[owners[i]];
      address[] storage voters = sideVoters[side][_authType];
      for (uint j = 0; j < voters.length; j = j.add(1)) {
        delete voters[j]; // clear votes of one side
      }
      voters.length = 0;
    }
    
    // clear this type of event
    for (uint k = 0; k < authTypes.length; k = k.add(1)) {
      if (authTypes[k].equal(_authType)) {
        delete authTypes[k];
        break;
      }
    }
    for (uint kk = k; kk < authTypes.length.sub(1); kk = kk.add(1)) {
      authTypes[kk] = authTypes[kk.add(1)];
    }

    delete authTypes[authTypes.length.sub(1)];
    authTypes.length = authTypes.length.sub(1);
  }

  /**
   * @dev add an address as one of the multiOwners.
   * @param _addr the account address used as a multiOwner
   */
  function addAddress(address _addr, string _side) internal {
    require(multiOwnerSides < ownerSidesLimit);
    require(_addr != address(0));
    require(ownerOfSides[_addr].equal("")); // not allow duplicated adding

    // uint i = 0;
    // for (; i < owners.length; i = i.add(1)) {
    //   if (owners[i] == _addr) {
    //     break;
    //   }
    // }

    // if (i >= owners.length) {
    owners.push(_addr); // for not allowing duplicated adding, so each addr should be new

    addRole(_addr, ROLE_MULTIOWNER);    
    ownerOfSides[_addr] = _side;
    // }

    if (sideExist[_side] == 0) {        
      multiOwnerSides = multiOwnerSides.add(1);
    }

    sideExist[_side] = sideExist[_side].add(1);
  }

  /**
   * @dev add an address to the whitelist
   * @param _addr address will be one of the multiOwner
   * @param _side the side name of the multiOwner
   * @return true if the address was added to the multiOwners list, 
   *         false if the address was already in the multiOwners list
   */
  function initAddressAsMultiOwner(address _addr, string _side)
    onlyOwner
    canInitial
    public
  {
    // require(initAdd);
    addAddress(_addr, _side);

    // initAdd = false;
    emit OwnerAdded(_addr, _side);
  }

  /**
   * @dev Function to stop initial stage.
   */
  function finishInitOwners() onlyOwner canInitial public {
    initAdd = false;
    emit InitialFinished();
  }

  /**
   * @dev add an address to the whitelist
   * @param _addr address
   * @param _side the side name of the multiOwner
   * @return true if the address was added to the multiOwners list, 
   *         false if the address was already in the multiOwners list
   */
  function addAddressAsMultiOwner(address _addr, string _side)
    onlyMultiOwners
    public
  {
    require(hasAuth(AUTH_ADDOWNER));

    addAddress(_addr, _side);
        
    clearAuth(AUTH_ADDOWNER);
    emit OwnerAdded(_addr, _side);
  }

  /**
   * @dev getter to determine if address is in multiOwner list
   */
  function isMultiOwner(address _addr)
    public
    view
    returns (bool)
  {
    return hasRole(_addr, ROLE_MULTIOWNER);
  }

  /**
   * @dev remove an address from the whitelist
   * @param _addr address
   * @return true if the address was removed from the multiOwner list,
   *         false if the address wasn't in the multiOwner list
   */
  function removeAddressFromOwners(address _addr)
    onlyMultiOwners
    public
  {
    require(hasAuth(AUTH_REMOVEOWNER));

    removeRole(_addr, ROLE_MULTIOWNER);   

    // first remove the owner
    uint j = 0;
    for (; j < owners.length; j = j.add(1)) {
      if (owners[j] == _addr) {
        delete owners[j];
        break;
      }
    }
    if (j < owners.length) {
      for (uint jj = j; jj < owners.length.sub(1); jj = jj.add(1)) {
        owners[jj] = owners[jj.add(1)];
      }

      delete owners[owners.length.sub(1)];
      owners.length = owners.length.sub(1);
    }

    string memory side = ownerOfSides[_addr];
    // if (sideExist[side] > 0) {
    sideExist[side] = sideExist[side].sub(1);
    if (sideExist[side] == 0) {
      require(multiOwnerSides > 2); // not allow only left 1 side 
      multiOwnerSides = multiOwnerSides.sub(1); // this side has been removed
    }

    // for every event type, if this owner has voted the event, then need to remove
    for (uint i = 0; i < authTypes.length; ) {
      address[] storage voters = sideVoters[side][authTypes[i]];
      for (uint m = 0; m < voters.length; m = m.add(1)) {
        if (voters[m] == _addr) {
          delete voters[m];
          break;
        }
      }
      if (m < voters.length) {
        for (uint n = m; n < voters.length.sub(1); n = n.add(1)) {
          voters[n] = voters[n.add(1)];
        }
   
        delete voters[voters.length.sub(1)];
        voters.length = voters.length.sub(1);

        // if this side only have this 1 voter, the authorization of this event need to be decreased
        if (voters.length == 0) {
          authorizations[authTypes[i]] = authorizations[authTypes[i]].sub(1);
        }

        // if there is no authorization of this event, the event need to be removed
        if (authorizations[authTypes[i]] == 0) {
          delete authTypes[i];
            
          for (uint kk = i; kk < authTypes.length.sub(1); kk = kk.add(1)) {
            authTypes[kk] = authTypes[kk.add(1)];
          }

          delete authTypes[authTypes.length.sub(1)];
          authTypes.length = authTypes.length.sub(1);
        } else {
          i = i.add(1);
        }
      } else {
        i = i.add(1);
      }       
    }
//   } 

    delete ownerOfSides[_addr];    

    clearAuth(AUTH_REMOVEOWNER);
    emit OwnerRemoved(_addr);
  }

}
