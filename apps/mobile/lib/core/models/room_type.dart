enum RoomType {
  livingRoom('LIVING_ROOM', 'Salon'),
  bedroom('BEDROOM', 'Yatak Odası'),
  kitchen('KITCHEN', 'Mutfak'),
  bathroom('BATHROOM', 'Banyo'),
  diningRoom('DINING_ROOM', 'Yemek Odası'),
  office('OFFICE', 'Ofis'),
  hallway('HALLWAY', 'Koridor'),
  balcony('BALCONY', 'Balkon'),
  garage('GARAGE', 'Garaj'),
  laundry('LAUNDRY', 'Çamaşırhane'),
  closet('CLOSET', 'Dolap'),
  other('OTHER', 'Diğer');

  const RoomType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static RoomType fromApi(String value) =>
      RoomType.values.firstWhere(
        (e) => e.apiValue == value,
        orElse: () => RoomType.other,
      );
}
