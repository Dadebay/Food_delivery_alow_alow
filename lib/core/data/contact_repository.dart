import '../network/api_client.dart';

class ContactInfo {
  const ContactInfo({
    required this.name,
    required this.phone,
    this.telegram,
    this.email,
    this.privacyLink,
    this.userAgreementLink,
  });
  final String name;
  final String phone;
  final String? telegram;
  final String? email;
  final String? privacyLink;
  final String? userAgreementLink;
  factory ContactInfo.fromJson(Map<String, dynamic> json) => ContactInfo(
    name: json['displayName'] as String,
    phone: json['phone'] as String,
    telegram: json['telegram'] as String?,
    email: json['email'] as String?,
    privacyLink: json['privacyLink'] as String?,
    userAgreementLink: json['userAgreementLink'] as String?,
  );
}

class ContactRepository {
  ContactRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  Future<ContactInfo> get() async => ContactInfo.fromJson(
    (await _api.get(ApiPaths.contacts)).data as Map<String, dynamic>,
  );
}
