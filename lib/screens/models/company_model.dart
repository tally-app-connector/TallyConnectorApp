class Company {
  final String guid;
  final int masterId;
  final int alterId;
  final String name;
  final String? reservedName;
  final String startingFrom;
  final String endingAt;
  final String? booksFrom;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? pincode;
  final String? state;
  final String? country;
  final String? pan;
  final String? gsttin;
  final String? currencyName;
  final String? createdAt;
  final String? updatedAt;

  const Company({
    required this.guid,
    required this.masterId,
    required this.alterId,
    required this.name,
    this.reservedName,
    required this.startingFrom,
    required this.endingAt,
    this.booksFrom,
    this.email,
    this.phoneNumber,
    this.address,
    this.city,
    this.pincode,
    this.state,
    this.country,
    this.pan,
    this.gsttin,
    this.currencyName,
    this.createdAt,
    this.updatedAt,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      guid: map['company_guid'] ?? '',
      masterId: map['master_id'] ?? 0,
      alterId: map['alter_id'] ?? 0,
      name: map['company_name'] ?? '',
      reservedName: map['reserved_name'],
      startingFrom: map['starting_from'] ?? '',
      endingAt: map['ending_at'] ?? '',
      booksFrom: map['books_from'],
      email: map['email'],
      phoneNumber: map['phone_number'],
      address: map['address'],
      city: map['city'],
      pincode: map['pincode'],
      state: map['state'],
      country: map['country'],
      pan: map['pan'],
      gsttin: map['gsttin'],
      currencyName: map['currency_name'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
