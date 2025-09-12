// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct GreenAction {
        uint256 id;
        address user;
        string actionType;
        uint256 carbonCredits;
        string proofHash; // IPFS hash of proof document/image
        uint256 timestamp;
        bool verified;
        address verifier;
    }
    
    struct User {
        uint256 totalCarbonCredits;
        uint256 totalActionsSubmitted;
        uint256 totalActionsVerified;
        uint256 carbonFootprint;
        bool isRegistered;
    }
    
    struct ActionCategory {
        string name;
        uint256 baseCredits;
        bool isActive;
    }
    
    address public admin;
    uint256 public totalGreenActions;
    uint256 public totalCarbonCreditsIssued;
    uint256 public totalUsersRegistered;
    
    mapping(uint256 => GreenAction) public greenActions;
    mapping(address => User) public users;
    mapping(address => bool) public verifiers;
    mapping(string => ActionCategory) public actionCategories;
    mapping(address => uint256[]) public userActions;
    
    event UserRegistered(address indexed user);
    event GreenActionSubmitted(uint256 indexed actionId, address indexed user, string actionType);
    event ActionVerified(uint256 indexed actionId, address indexed verifier, uint256 creditsAwarded);
    event CarbonCreditsTransferred(address indexed from, address indexed to, uint256 amount);
    event CarbonFootprintUpdated(address indexed user, uint256 newFootprint);
    event VerifierAdded(address indexed verifier);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyVerifier() {
        require(verifiers[msg.sender] || msg.sender == admin, "Only verifiers can perform this action");
        _;
    }
    
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    modifier validActionId(uint256 _actionId) {
        require(_actionId > 0 && _actionId <= totalGreenActions, "Invalid action ID");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        
        // Initialize common green action categories
        actionCategories["SOLAR_PANEL_INSTALL"] = ActionCategory("Solar Panel Installation", 1000, true);
        actionCategories["TREE_PLANTING"] = ActionCategory("Tree Planting", 50, true);
        actionCategories["EV_USAGE"] = ActionCategory("Electric Vehicle Usage", 100, true);
        actionCategories["RENEWABLE_ENERGY"] = ActionCategory("Renewable Energy Adoption", 200, true);
        actionCategories["WASTE_REDUCTION"] = ActionCategory("Waste Reduction Initiative", 75, true);
        actionCategories["CARBON_NEUTRAL_TRANSPORT"] = ActionCategory("Carbon Neutral Transportation", 150, true);
    }
    
    /**
     * @dev Core Function 1: Submit proof of green action for verification
     * @param _actionType Type of green action performed
     * @param _proofHash IPFS hash of proof document/image
     * @param _additionalCredits Additional credits claimed (subject to verification)
     */
    function submitGreenAction(
        string memory _actionType,
        string memory _proofHash,
        uint256 _additionalCredits
    ) public onlyRegisteredUser {
        require(bytes(_actionType).length > 0, "Action type cannot be empty");
        require(bytes(_proofHash).length > 0, "Proof hash cannot be empty");
        require(actionCategories[_actionType].isActive, "Action type not supported");
        
        totalGreenActions++;
        
        uint256 baseCredits = actionCategories[_actionType].baseCredits;
        uint256 totalCredits = baseCredits + _additionalCredits;
        
        greenActions[totalGreenActions] = GreenAction({
            id: totalGreenActions,
            user: msg.sender,
            actionType: _actionType,
            carbonCredits: totalCredits,
            proofHash: _proofHash,
            timestamp: block.timestamp,
            verified: false,
            verifier: address(0)
        });
        
        userActions[msg.sender].push(totalGreenActions);
        users[msg.sender].totalActionsSubmitted++;
        
        emit GreenActionSubmitted(totalGreenActions, msg.sender, _actionType);
    }
    
    /**
     * @dev Core Function 2: Verify green action and award carbon credits
     * @param _actionId ID of the action to verify
     * @param _approvedCredits Final approved carbon credits (can be adjusted by verifier)
     */
    function verifyGreenAction(
        uint256 _actionId,
        uint256 _approvedCredits
    ) public onlyVerifier validActionId(_actionId) {
        GreenAction storage action = greenActions[_actionId];
        require(!action.verified, "Action already verified");
        require(_approvedCredits > 0, "Approved credits must be greater than 0");
        
        action.verified = true;
        action.verifier = msg.sender;
        action.carbonCredits = _approvedCredits;
        
        users[action.user].totalCarbonCredits += _approvedCredits;
        users[action.user].totalActionsVerified++;
        totalCarbonCreditsIssued += _approvedCredits;
        
        emit ActionVerified(_actionId, msg.sender, _approvedCredits);
    }
    
    /**
     * @dev Core Function 3: Offset carbon footprint using earned credits
     * @param _creditsToUse Amount of carbon credits to use for offsetting
     */
    function offsetCarbonFootprint(uint256 _creditsToUse) public onlyRegisteredUser {
        require(_creditsToUse > 0, "Credits to use must be greater than 0");
        require(users[msg.sender].totalCarbonCredits >= _creditsToUse, "Insufficient carbon credits");
        
        users[msg.sender].totalCarbonCredits -= _creditsToUse;
        
        // Reduce carbon footprint (1 credit = 1 kg CO2 offset)
        if (users[msg.sender].carbonFootprint >= _creditsToUse) {
            users[msg.sender].carbonFootprint -= _creditsToUse;
        } else {
            users[msg.sender].carbonFootprint = 0;
        }
        
        emit CarbonFootprintUpdated(msg.sender, users[msg.sender].carbonFootprint);
    }
    
    // Additional utility functions
    
    function registerUser(uint256 _initialCarbonFootprint) public {
        require(!users[msg.sender].isRegistered, "User already registered");
        
        users[msg.sender] = User({
            totalCarbonCredits: 0,
            totalActionsSubmitted: 0,
            totalActionsVerified: 0,
            carbonFootprint: _initialCarbonFootprint,
            isRegistered: true
        });
        
        totalUsersRegistered++;
        emit UserRegistered(msg.sender);
    }
    
    function addVerifier(address _verifier) public onlyAdmin {
        require(_verifier != address(0), "Invalid verifier address");
        require(!verifiers[_verifier], "Address is already a verifier");
        
        verifiers[_verifier] = true;
        emit VerifierAdded(_verifier);
    }
    
    function removeVerifier(address _verifier) public onlyAdmin {
        require(verifiers[_verifier], "Address is not a verifier");
        verifiers[_verifier] = false;
    }
    
    function addActionCategory(
        string memory _categoryKey,
        string memory _name,
        uint256 _baseCredits
    ) public onlyAdmin {
        require(bytes(_categoryKey).length > 0, "Category key cannot be empty");
        require(_baseCredits > 0, "Base credits must be greater than 0");
        
        actionCategories[_categoryKey] = ActionCategory(_name, _baseCredits, true);
    }
    
    function transferCarbonCredits(address _to, uint256 _amount) public onlyRegisteredUser {
        require(_to != address(0), "Invalid recipient address");
        require(users[_to].isRegistered, "Recipient must be registered");
        require(users[msg.sender].totalCarbonCredits >= _amount, "Insufficient carbon credits");
        require(_amount > 0, "Amount must be greater than 0");
        
        users[msg.sender].totalCarbonCredits -= _amount;
        users[_to].totalCarbonCredits += _amount;
        
        emit CarbonCreditsTransferred(msg.sender, _to, _amount);
    }
    
    function updateCarbonFootprint(uint256 _newFootprint) public onlyRegisteredUser {
        users[msg.sender].carbonFootprint = _newFootprint;
        emit CarbonFootprintUpdated(msg.sender, _newFootprint);
    }
    
    function getUserActions(address _user) public view returns (uint256[] memory) {
        return userActions[_user];
    }
    
    function getActionDetails(uint256 _actionId) public view validActionId(_actionId) returns (
        address user,
        string memory actionType,
        uint256 carbonCredits,
        string memory proofHash,
        uint256 timestamp,
        bool verified,
        address verifier
    ) {
        GreenAction memory action = greenActions[_actionId];
        return (
            action.user,
            action.actionType,
            action.carbonCredits,
            action.proofHash,
            action.timestamp,
            action.verified,
            action.verifier
        );
    }
    
    function getUserStats(address _user) public view returns (
        uint256 totalCredits,
        uint256 actionsSubmitted,
        uint256 actionsVerified,
        uint256 carbonFootprint,
        bool isRegistered
    ) {
        User memory user = users[_user];
        return (
            user.totalCarbonCredits,
            user.totalActionsSubmitted,
            user.totalActionsVerified,
            user.carbonFootprint,
            user.isRegistered
        );
    }
    
    function getContractStats() public view returns (
        uint256 totalActions,
        uint256 totalCredits,
        uint256 totalUsers
    ) {
        return (totalGreenActions, totalCarbonCreditsIssued, totalUsersRegistered);
    }
}
