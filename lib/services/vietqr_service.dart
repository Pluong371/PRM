class VietQrService {
  static String buildQrImageUrl({
    required String bankBin,
    required String accountNumber,
    required String accountName,
    required int amount,
    required String addInfo,
  }) {
    final encodedName = Uri.encodeComponent(accountName);
    final encodedInfo = Uri.encodeComponent(addInfo);

    return 'https://img.vietqr.io/image/$bankBin-$accountNumber-compact2.png?amount=$amount&addInfo=$encodedInfo&accountName=$encodedName';
  }
}
