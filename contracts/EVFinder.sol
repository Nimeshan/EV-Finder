// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EVFinder
 * @dev Smart contract for EV Finder app: auth, bookings, escrow payments, refunds, rewards.
 * Security: ReentrancyGuard on payment/refund paths; no intermediaries for charging payments.
 */
contract EVFinder {
    // Reentrancy guard
    uint256 private _locked = 0;
    modifier nonReentrant() {
        require(_locked == 0, "ReentrancyGuard: reentrant call");
        _locked = 1;
        _;
        _locked = 0;
    }

    // User structure
    struct User {
        address walletAddress;
        string name;
        uint256 registrationTimestamp;
        bool isRegistered;
    }

    // Mapping from wallet address to User
    mapping(address => User) public users;
    
    // Mapping to check if address is registered
    mapping(address => bool) public registeredUsers;
    
    // Array of all registered user addresses
    address[] public userAddresses;
    
    // Transaction structure
    struct Transaction {
        uint256 id;
        address userAddress;
        string stationName;
        uint256 timestamp;
        uint256 energy; // in kWh (stored as uint256, scaled by 1000 to preserve decimals)
        uint256 amount; // in USD cents (stored as uint256 to avoid decimals)
        bool isCredit;
        string txHash; // Blockchain transaction hash
    }
    
    // Mapping from user address to array of transaction IDs
    mapping(address => uint256[]) public userTransactions;
    
    // Mapping from transaction ID to Transaction
    mapping(uint256 => Transaction) public transactions;
    
    // Total transaction counter
    uint256 public transactionCounter;
    
    // Events
    event UserRegistered(address indexed user, string name, uint256 timestamp);
    event UserUpdated(address indexed user, string newName);
    event TransactionRecorded(
        uint256 indexed transactionId,
        address indexed userAddress,
        string stationName,
        uint256 timestamp,
        uint256 energy,
        uint256 amount,
        bool isCredit,
        string txHash
    );
    
    // Owner of the contract; default recipient for non-P2P charging payments
    address public owner;
    /// @dev Default address to receive escrowed payments when station is not P2P (e.g. platform wallet)
    address public defaultPaymentReceiver;

    constructor() {
        owner = msg.sender;
        defaultPaymentReceiver = msg.sender;
    }

    /// @dev Set the main wallet that receives non-P2P payments (only owner)
    function setDefaultPaymentReceiver(address _receiver) external {
        require(msg.sender == owner, "Not owner");
        require(_receiver != address(0), "Invalid address");
        defaultPaymentReceiver = _receiver;
    }

    /// @dev Allow contract to receive ETH for escrow
    receive() external payable {}
    
    /**
     * @dev Register a new user
     * @param _name User's name
     */
    function registerUser(string memory _name) public {
        require(!registeredUsers[msg.sender], "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        users[msg.sender] = User({
            walletAddress: msg.sender,
            name: _name,
            registrationTimestamp: block.timestamp,
            isRegistered: true
        });
        
        registeredUsers[msg.sender] = true;
        userAddresses.push(msg.sender);
        
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Update user name
     * @param _name New name
     */
    function updateUserName(string memory _name) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        users[msg.sender].name = _name;
        
        emit UserUpdated(msg.sender, _name);
    }
    
    /**
     * @dev Get user information
     * @param _address User's wallet address
     * @return User struct
     */
    function getUser(address _address) public view returns (User memory) {
        return users[_address];
    }
    
    /**
     * @dev Check if user is registered
     * @param _address User's wallet address
     * @return bool
     */
    function isUserRegistered(address _address) public view returns (bool) {
        return registeredUsers[_address];
    }
    
    /**
     * @dev Get total number of registered users
     * @return uint256
     */
    function getTotalUsers() public view returns (uint256) {
        return userAddresses.length;
    }
    
    /**
     * @dev Record a transaction for a user
     * @param _stationName Name of the charging station
     * @param _energy Energy in kWh (multiply by 1000 before passing, e.g., 15.1 kWh = 15100)
     * @param _amount Amount in USD cents (multiply by 100 before passing, e.g., $12.11 = 1211)
     * @param _isCredit True if credit, false if debit
     * @param _txHash Blockchain transaction hash
     */
    function recordTransaction(
        string memory _stationName,
        uint256 _energy,
        uint256 _amount,
        bool _isCredit,
        string memory _txHash
    ) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(bytes(_stationName).length > 0, "Station name cannot be empty");
        require(bytes(_txHash).length > 0, "Transaction hash cannot be empty");
        
        transactionCounter++;
        
        Transaction memory newTransaction = Transaction({
            id: transactionCounter,
            userAddress: msg.sender,
            stationName: _stationName,
            timestamp: block.timestamp,
            energy: _energy,
            amount: _amount,
            isCredit: _isCredit,
            txHash: _txHash
        });
        
        transactions[transactionCounter] = newTransaction;
        userTransactions[msg.sender].push(transactionCounter);
        
        emit TransactionRecorded(
            transactionCounter,
            msg.sender,
            _stationName,
            block.timestamp,
            _energy,
            _amount,
            _isCredit,
            _txHash
        );
    }
    
    /**
     * @dev Get transaction by ID
     * @param _transactionId Transaction ID
     * @return Transaction struct
     */
    function getTransaction(uint256 _transactionId) public view returns (Transaction memory) {
        require(_transactionId > 0 && _transactionId <= transactionCounter, "Transaction does not exist");
        return transactions[_transactionId];
    }
    
    /**
     * @dev Get all transaction IDs for a user
     * @param _userAddress User's wallet address
     * @return uint256[] Array of transaction IDs
     */
    function getUserTransactionIds(address _userAddress) public view returns (uint256[] memory) {
        return userTransactions[_userAddress];
    }
    
    /**
     * @dev Get transaction count for a user
     * @param _userAddress User's wallet address
     * @return uint256 Number of transactions
     */
    function getUserTransactionCount(address _userAddress) public view returns (uint256) {
        return userTransactions[_userAddress].length;
    }

    /**
     * @dev Get multiple transactions by IDs
     * @param _transactionIds Array of transaction IDs
     * @return Transaction[] Array of Transaction structs
     */
    function getTransactions(uint256[] memory _transactionIds) public view returns (Transaction[] memory) {
        Transaction[] memory result = new Transaction[](_transactionIds.length);
        for (uint256 i = 0; i < _transactionIds.length; i++) {
            require(_transactionIds[i] > 0 && _transactionIds[i] <= transactionCounter, "Transaction does not exist");
            result[i] = transactions[_transactionIds[i]];
        }
        return result;
    }

    // ==================== BOOKING SYSTEM ====================

    enum BookingStatus { Pending, Confirmed, Cancelled, Completed }

    struct Booking {
        uint256 id;
        address userAddress;
        string stationId;
        string connectorType;
        uint256 startTime;
        uint256 endTime;
        uint256 energyKwh; // scaled by 1000
        uint256 amountUsd; // in cents
        BookingStatus status;
        string txHash;
        uint256 amountPaidWei;   // ETH held in escrow (0 until payBooking)
        address beneficiary;    // receives payment on complete (station owner or defaultPaymentReceiver)
    }

    // Booking storage
    mapping(uint256 => Booking) public bookings;
    mapping(address => uint256[]) public userBookings;
    mapping(string => uint256[]) public stationBookings;
    uint256 public bookingCounter;

    // Incentive: reward points (e.g. for completing sessions, providing charging, green energy)
    mapping(address => uint256) public rewardPoints;

    // Booking events
    event BookingCreated(
        uint256 indexed bookingId,
        address indexed userAddress,
        string stationId,
        uint256 startTime,
        uint256 endTime
    );
    event BookingCancelled(uint256 indexed bookingId, address indexed userAddress);
    event BookingCompleted(uint256 indexed bookingId, string txHash);
    event PaymentEscrowed(uint256 indexed bookingId, address indexed user, uint256 amountWei, address beneficiary);
    event PaymentReleased(uint256 indexed bookingId, address indexed beneficiary, uint256 amountWei);
    event RefundIssued(uint256 indexed bookingId, address indexed user, uint256 amountWei);

    /**
     * @dev Create a new booking with time conflict checking. Tariff (amountUsd) is set by app; contract stores it for record.
     * @return bookingId The new booking id (bookingCounter).
     */
    function createBooking(
        string memory _stationId,
        string memory _connectorType,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _energyKwh,
        uint256 _amountUsd
    ) public returns (uint256) {
        require(registeredUsers[msg.sender], "User not registered");
        require(_endTime > _startTime, "End time must be after start time");
        require(bytes(_stationId).length > 0, "Station ID required");

        // Check for time conflicts (prevents double booking)
        uint256[] storage stationBookingIds = stationBookings[_stationId];
        for (uint256 i = 0; i < stationBookingIds.length; i++) {
            Booking storage existing = bookings[stationBookingIds[i]];
            if (existing.status == BookingStatus.Pending || existing.status == BookingStatus.Confirmed) {
                require(
                    _startTime >= existing.endTime || _endTime <= existing.startTime,
                    "Time conflict with existing booking"
                );
            }
        }

        bookingCounter++;

        bookings[bookingCounter] = Booking({
            id: bookingCounter,
            userAddress: msg.sender,
            stationId: _stationId,
            connectorType: _connectorType,
            startTime: _startTime,
            endTime: _endTime,
            energyKwh: _energyKwh,
            amountUsd: _amountUsd,
            status: BookingStatus.Pending,
            txHash: "",
            amountPaidWei: 0,
            beneficiary: address(0)
        });

        userBookings[msg.sender].push(bookingCounter);
        stationBookings[_stationId].push(bookingCounter);

        emit BookingCreated(bookingCounter, msg.sender, _stationId, _startTime, _endTime);
        return bookingCounter;
    }

    /**
     * @dev Pay for a booking: send ETH to contract (escrow). Only booking owner; beneficiary receives on complete.
     */
    function payBooking(uint256 _bookingId, address _beneficiary) external payable nonReentrant {
        require(_bookingId > 0 && _bookingId <= bookingCounter, "Booking does not exist");
        Booking storage booking = bookings[_bookingId];
        require(booking.userAddress == msg.sender, "Not booking owner");
        require(booking.status == BookingStatus.Pending || booking.status == BookingStatus.Confirmed, "Invalid status");
        require(booking.amountPaidWei == 0, "Already paid");
        require(msg.value > 0, "Amount must be positive");
        require(_beneficiary != address(0), "Invalid beneficiary");

        booking.amountPaidWei = msg.value;
        booking.beneficiary = _beneficiary;
        emit PaymentEscrowed(_bookingId, msg.sender, msg.value, _beneficiary);
    }

    /**
     * @dev Complete a booking: release escrowed payment to beneficiary and award reward points.
     */
    function completeBooking(uint256 _bookingId, string memory _txHash) public nonReentrant {
        require(_bookingId > 0 && _bookingId <= bookingCounter, "Booking does not exist");
        Booking storage booking = bookings[_bookingId];
        require(booking.userAddress == msg.sender, "Not booking owner");
        require(
            booking.status == BookingStatus.Pending || booking.status == BookingStatus.Confirmed,
            "Booking cannot be completed"
        );

        booking.status = BookingStatus.Completed;
        booking.txHash = _txHash;

        uint256 amount = booking.amountPaidWei;
        address beneficiary = booking.beneficiary;
        if (amount > 0 && beneficiary != address(0)) {
            booking.amountPaidWei = 0;
            (bool ok,) = payable(beneficiary).call{value: amount}("");
            require(ok, "Transfer failed");
            emit PaymentReleased(_bookingId, beneficiary, amount);
        }

        // Incentive: reward points for completing a charging session (user + station provider)
        _addRewardPoints(booking.userAddress, 10);
        if (beneficiary != address(0)) _addRewardPoints(beneficiary, 5);

        emit BookingCompleted(_bookingId, _txHash);
    }

    /**
     * @dev Cancel a booking. If user already paid (escrow), refund in full.
     */
    function cancelBooking(uint256 _bookingId) public nonReentrant {
        require(_bookingId > 0 && _bookingId <= bookingCounter, "Booking does not exist");
        Booking storage booking = bookings[_bookingId];
        require(booking.userAddress == msg.sender, "Not booking owner");
        require(
            booking.status == BookingStatus.Pending || booking.status == BookingStatus.Confirmed,
            "Booking cannot be cancelled"
        );

        uint256 refundAmount = booking.amountPaidWei;
        booking.amountPaidWei = 0;
        booking.beneficiary = address(0);
        booking.status = BookingStatus.Cancelled;

        if (refundAmount > 0) {
            (bool ok,) = payable(msg.sender).call{value: refundAmount}("");
            require(ok, "Refund transfer failed");
            emit RefundIssued(_bookingId, msg.sender, refundAmount);
        }
        emit BookingCancelled(_bookingId, msg.sender);
    }

    /// @dev Returns current booking counter (latest booking id after createBooking).
    function getBookingCounter() external view returns (uint256) {
        return bookingCounter;
    }

    /**
     * @dev Get booking by ID
     */
    function getBooking(uint256 _bookingId) public view returns (Booking memory) {
        require(_bookingId > 0 && _bookingId <= bookingCounter, "Booking does not exist");
        return bookings[_bookingId];
    }

    /**
     * @dev Get all booking IDs for a user
     */
    function getUserBookingIds(address _userAddress) public view returns (uint256[] memory) {
        return userBookings[_userAddress];
    }

    /**
     * @dev Get active bookings for a station (for conflict checking)
     */
    function getStationActiveBookings(string memory _stationId) public view returns (Booking[] memory) {
        uint256[] storage ids = stationBookings[_stationId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            if (bookings[ids[i]].status == BookingStatus.Pending || bookings[ids[i]].status == BookingStatus.Confirmed) {
                activeCount++;
            }
        }

        Booking[] memory result = new Booking[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            if (bookings[ids[i]].status == BookingStatus.Pending || bookings[ids[i]].status == BookingStatus.Confirmed) {
                result[index] = bookings[ids[i]];
                index++;
            }
        }
        return result;
    }

    function _addRewardPoints(address _user, uint256 _points) internal {
        if (_user != address(0)) rewardPoints[_user] += _points;
    }

    /// @dev Get reward points for an address (incentive for charging sessions, P2P hosting, etc.)
    function getRewardPoints(address _user) external view returns (uint256) {
        return rewardPoints[_user];
    }

    // ==================== P2P CHARGING STATION REGISTRY ====================

    struct P2PStation {
        uint256 id;
        address owner;
        string name;
        string locationAddress;
        int256 latitude;       // scaled by 1e6 (e.g., 6927100 = 6.9271)
        int256 longitude;      // scaled by 1e6
        string connectorType;
        uint256 powerKw;       // in watts (7000 = 7kW)
        uint256 pricePerKwh;   // in USD cents (25 = $0.25)
        bool isGreenEnergy;
        bool isActive;
        uint256 createdAt;
    }

    mapping(uint256 => P2PStation) public p2pStations;
    mapping(address => uint256[]) public ownerStations;
    uint256[] public allStationIds;
    uint256 public stationCounter;

    event StationRegistered(uint256 indexed stationId, address indexed owner, string name);
    event StationUpdated(uint256 indexed stationId, address indexed owner);
    event StationDeactivated(uint256 indexed stationId, address indexed owner);

    /**
     * @dev Register a new P2P charging station
     */
    function registerStation(
        string memory _name,
        string memory _locationAddress,
        int256 _latitude,
        int256 _longitude,
        string memory _connectorType,
        uint256 _powerKw,
        uint256 _pricePerKwh,
        bool _isGreenEnergy
    ) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_locationAddress).length > 0, "Address cannot be empty");

        stationCounter++;

        p2pStations[stationCounter] = P2PStation({
            id: stationCounter,
            owner: msg.sender,
            name: _name,
            locationAddress: _locationAddress,
            latitude: _latitude,
            longitude: _longitude,
            connectorType: _connectorType,
            powerKw: _powerKw,
            pricePerKwh: _pricePerKwh,
            isGreenEnergy: _isGreenEnergy,
            isActive: true,
            createdAt: block.timestamp
        });

        ownerStations[msg.sender].push(stationCounter);
        allStationIds.push(stationCounter);

        if (_isGreenEnergy) _addRewardPoints(msg.sender, 5); // Incentive for renewable energy
        emit StationRegistered(stationCounter, msg.sender, _name);
    }

    /**
     * @dev Update a P2P station's price and active status
     */
    function updateStation(uint256 _stationId, uint256 _pricePerKwh, bool _isActive) public {
        require(_stationId > 0 && _stationId <= stationCounter, "Station does not exist");
        require(p2pStations[_stationId].owner == msg.sender, "Not station owner");

        p2pStations[_stationId].pricePerKwh = _pricePerKwh;
        p2pStations[_stationId].isActive = _isActive;

        emit StationUpdated(_stationId, msg.sender);
    }

    /**
     * @dev Deactivate a P2P station
     */
    function deactivateStation(uint256 _stationId) public {
        require(_stationId > 0 && _stationId <= stationCounter, "Station does not exist");
        require(p2pStations[_stationId].owner == msg.sender, "Not station owner");

        p2pStations[_stationId].isActive = false;

        emit StationDeactivated(_stationId, msg.sender);
    }

    /**
     * @dev Get a P2P station by ID
     */
    function getStation(uint256 _stationId) public view returns (P2PStation memory) {
        require(_stationId > 0 && _stationId <= stationCounter, "Station does not exist");
        return p2pStations[_stationId];
    }

    /**
     * @dev Get all active P2P stations
     */
    function getAllActiveStations() public view returns (P2PStation[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allStationIds.length; i++) {
            if (p2pStations[allStationIds[i]].isActive) {
                activeCount++;
            }
        }

        P2PStation[] memory result = new P2PStation[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allStationIds.length; i++) {
            if (p2pStations[allStationIds[i]].isActive) {
                result[index] = p2pStations[allStationIds[i]];
                index++;
            }
        }
        return result;
    }

    /**
     * @dev Get all station IDs owned by an address
     */
    function getOwnerStations(address _owner) public view returns (uint256[] memory) {
        return ownerStations[_owner];
    }

    // ==================== ENERGY TRADING ====================

    struct EnergyListing {
        uint256 id;
        address seller;
        uint256 energyKwh;     // scaled by 1000
        uint256 pricePerKwh;   // USD cents
        uint256 totalPrice;    // USD cents
        bool isActive;
        bool isSold;
        address buyer;
        string txHash;
        uint256 createdAt;
    }

    mapping(uint256 => EnergyListing) public energyListings;
    mapping(address => uint256[]) public sellerListings;
    uint256[] public allListingIds;
    uint256 public listingCounter;

    // Energy credit balances (in Wh for precision)
    mapping(address => uint256) public energyCredits;

    event EnergyListed(uint256 indexed listingId, address indexed seller, uint256 energyKwh, uint256 pricePerKwh);
    event EnergyPurchased(uint256 indexed listingId, address indexed buyer, address indexed seller, string txHash);
    event EnergyCancelled(uint256 indexed listingId, address indexed seller);
    event CreditsAdded(address indexed user, uint256 amount);

    /**
     * @dev Add energy credits (simulates solar energy production for demo)
     */
    function addEnergyCredits(uint256 _amount) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(_amount > 0, "Amount must be positive");

        energyCredits[msg.sender] += _amount;

        emit CreditsAdded(msg.sender, _amount);
    }

    /**
     * @dev Get energy credit balance for an address
     */
    function getEnergyCredits(address _user) public view returns (uint256) {
        return energyCredits[_user];
    }

    /**
     * @dev List energy for sale (escrows credits from seller)
     */
    function listEnergy(uint256 _energyKwh, uint256 _pricePerKwh) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(_energyKwh > 0, "Energy must be positive");
        require(_pricePerKwh > 0, "Price must be positive");
        require(energyCredits[msg.sender] >= _energyKwh, "Insufficient energy credits");

        // Escrow: deduct from seller's balance
        energyCredits[msg.sender] -= _energyKwh;

        listingCounter++;

        uint256 totalPrice = (_energyKwh * _pricePerKwh) / 1000; // divide by 1000 because energyKwh is scaled

        energyListings[listingCounter] = EnergyListing({
            id: listingCounter,
            seller: msg.sender,
            energyKwh: _energyKwh,
            pricePerKwh: _pricePerKwh,
            totalPrice: totalPrice,
            isActive: true,
            isSold: false,
            buyer: address(0),
            txHash: "",
            createdAt: block.timestamp
        });

        sellerListings[msg.sender].push(listingCounter);
        allListingIds.push(listingCounter);

        emit EnergyListed(listingCounter, msg.sender, _energyKwh, _pricePerKwh);
    }

    /**
     * @dev Purchase an energy listing
     */
    function purchaseEnergy(uint256 _listingId, string memory _txHash) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(_listingId > 0 && _listingId <= listingCounter, "Listing does not exist");

        EnergyListing storage listing = energyListings[_listingId];
        require(listing.isActive && !listing.isSold, "Listing not available");
        require(listing.seller != msg.sender, "Cannot buy own listing");

        listing.isSold = true;
        listing.isActive = false;
        listing.buyer = msg.sender;
        listing.txHash = _txHash;

        // Transfer escrowed credits to buyer
        energyCredits[msg.sender] += listing.energyKwh;

        emit EnergyPurchased(_listingId, msg.sender, listing.seller, _txHash);
    }

    /**
     * @dev Cancel an energy listing (returns escrowed credits to seller)
     */
    function cancelEnergyListing(uint256 _listingId) public {
        require(_listingId > 0 && _listingId <= listingCounter, "Listing does not exist");

        EnergyListing storage listing = energyListings[_listingId];
        require(listing.seller == msg.sender, "Not listing owner");
        require(listing.isActive && !listing.isSold, "Listing not cancellable");

        listing.isActive = false;

        // Return escrowed credits
        energyCredits[msg.sender] += listing.energyKwh;

        emit EnergyCancelled(_listingId, msg.sender);
    }

    /**
     * @dev Get all active energy listings
     */
    function getActiveListings() public view returns (EnergyListing[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allListingIds.length; i++) {
            if (energyListings[allListingIds[i]].isActive && !energyListings[allListingIds[i]].isSold) {
                activeCount++;
            }
        }

        EnergyListing[] memory result = new EnergyListing[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allListingIds.length; i++) {
            if (energyListings[allListingIds[i]].isActive && !energyListings[allListingIds[i]].isSold) {
                result[index] = energyListings[allListingIds[i]];
                index++;
            }
        }
        return result;
    }

    /**
     * @dev Get all listing IDs for a seller
     */
    function getSellerListings(address _seller) public view returns (uint256[] memory) {
        return sellerListings[_seller];
    }

    // ==================== REPUTATION / REVIEWS ====================

    struct Review {
        uint256 id;
        address reviewer;
        uint256 stationId;    // P2P station ID
        uint256 bookingId;    // must have completed booking
        uint8 rating;         // 1-5
        string comment;
        uint256 timestamp;
    }

    mapping(uint256 => Review) public reviews;
    mapping(uint256 => uint256[]) public stationReviews;   // stationId => reviewIds
    mapping(address => uint256[]) public userReviews;
    mapping(uint256 => bool) public bookingReviewed;       // bookingId => reviewed
    uint256 public reviewCounter;

    // Aggregated ratings
    mapping(uint256 => uint256) public stationTotalRating;
    mapping(uint256 => uint256) public stationReviewCount;

    event ReviewSubmitted(uint256 indexed reviewId, uint256 indexed stationId, address indexed reviewer, uint8 rating);

    /**
     * @dev Submit a review for a P2P station after a completed booking
     */
    function submitReview(
        uint256 _stationId,
        uint256 _bookingId,
        uint8 _rating,
        string memory _comment
    ) public {
        require(registeredUsers[msg.sender], "User not registered");
        require(_stationId > 0 && _stationId <= stationCounter, "Station does not exist");
        require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");
        require(!bookingReviewed[_bookingId], "Booking already reviewed");

        // Verify booking exists and is completed
        require(_bookingId > 0 && _bookingId <= bookingCounter, "Booking does not exist");
        Booking storage booking = bookings[_bookingId];
        require(booking.userAddress == msg.sender, "Not booking owner");
        require(booking.status == BookingStatus.Completed, "Booking not completed");

        reviewCounter++;
        bookingReviewed[_bookingId] = true;

        reviews[reviewCounter] = Review({
            id: reviewCounter,
            reviewer: msg.sender,
            stationId: _stationId,
            bookingId: _bookingId,
            rating: _rating,
            comment: _comment,
            timestamp: block.timestamp
        });

        stationReviews[_stationId].push(reviewCounter);
        userReviews[msg.sender].push(reviewCounter);

        // Update aggregated ratings
        stationTotalRating[_stationId] += _rating;
        stationReviewCount[_stationId]++;

        emit ReviewSubmitted(reviewCounter, _stationId, msg.sender, _rating);
    }

    /**
     * @dev Get all reviews for a station
     */
    function getStationReviews(uint256 _stationId) public view returns (Review[] memory) {
        uint256[] storage ids = stationReviews[_stationId];
        Review[] memory result = new Review[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = reviews[ids[i]];
        }
        return result;
    }

    /**
     * @dev Get station average rating
     */
    function getStationAverageRating(uint256 _stationId) public view returns (uint256 totalRating, uint256 count) {
        return (stationTotalRating[_stationId], stationReviewCount[_stationId]);
    }
}

