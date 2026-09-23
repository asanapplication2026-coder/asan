
// Shared content model for the ASAN Terms of Use & Service Policy.
//
// Both `LegalTermsScreen` (read-only) and `LegalTermsAgreementScreen`
// (scroll-to-agree) render this same list, so the copy only lives in one
// place. Update the text here and both screens stay in sync.

class TermsSection {
  final String number; // '' for the intro/welcome block, '1'..'9' otherwise
  final String title;
  final String body;

  const TermsSection({
    required this.number,
    required this.title,
    required this.body,
  });
}

const String kTermsDocumentTitle = 'ASAN Application';
const String kTermsDocumentSubtitle = 'Terms of Use and Service Policy';

const List<TermsSection> kTermsSections = [
  TermsSection(
    number: '',
    title: 'Welcome',
    body:
    'Welcome to ASAN (Automated Headcount and Status Update Application '
        'Notification). ASAN is designed to help the school community '
        'during emergency situations by providing a headcount monitoring '
        'system, student status updates, location information, emergency '
        'map guidance, and emergency communication chat box.\n\n'
        'By using the ASAN Application, users agree to follow the terms '
        'and policies stated below.',
  ),
  TermsSection(
    number: '1',
    title: 'Purpose of the Application',
    body:
    'ASAN is developed to assist authorized school personnel and '
        'students during emergency situations. Its primary purposes are '
        'to:\n\n'
        '• Support organized evacuation procedures\n'
        '• Monitor the number and status of students during emergencies\n'
        '• Provide authorized personnel with updated student status '
        'information\n'
        '• Help identify students who are safe, missing, or in need of '
        'assistance\n'
        '• Provide emergency notifications and communication\n'
        '• Support faster coordination between students and authorized '
        'school personnel\n\n'
        'ASAN is intended to support existing school emergency procedures '
        'and personnel, not replace them.',
  ),
  TermsSection(
    number: '2',
    title: 'Authorized Users',
    body:
    'ASAN is intended exclusively for the students, teachers, and '
        'admin/administrators of Senior High School in Rizal High School.\n\n'
        'ASAN is intended for the following authorized users:\n\n'
        '• Students – May access their account, view and update their '
        'applicable emergency information, communicate through the '
        'in-app chat box, and use available application features.\n'
        '• Teachers/Advisers – May monitor students assigned to them, '
        'view relevant student status and location information, and '
        'communicate with students through the application.\n'
        '• Administrators – Manage to import the authorized student and '
        'teachers accounts, start the emergency drill, and view the '
        'overall headcount dashboard.\n\n'
        'Users must only access information and features permitted by '
        'their assigned role.',
  ),
  TermsSection(
    number: '3',
    title: 'Responsible Use',
    body:
    'Users agree to use ASAN only for its intended school safety '
        'purposes.\n\n'
        'Users must:\n\n'
        '• Provide truthful and accurate status information\n'
        '• Follow instructions provided by authorized school personnel\n'
        '• Update their emergency status when requested\n'
        '• Use the application responsibly during emergencies\n'
        '• Keep their login information confidential\n'
        '• Immediately report suspected errors, security concerns, or '
        'unauthorized access to the appropriate school personnel\n\n'
        'Users must not:\n\n'
        '• Enter false or misleading emergency information\n'
        '• Falsely mark the students status\n'
        '• Intentionally interfere with the headcount or status-'
        'monitoring system\n'
        '• Attempt to access information belonging to another user '
        'without authorization\n\n'
        'Information Accuracy and Liability: ASAN will rely on the '
        'information given that is updated by its authorized personnel. '
        'The ASAN developers and administrators shall not be held '
        'responsible for inaccurate, incomplete, or misleading '
        'information entered or submitted by the user — including '
        'incorrect emergency status or headcount information — that '
        'leads to delay in rescuing or assisting affected students. '
        'Users are responsible for providing truthful and accurate '
        'information.',
  ),
  TermsSection(
    number: '4',
    title: 'Location Information',
    body:
    'ASAN may use location-related information to support '
        'evacuation monitoring and guidance.\n\n'
        'Location information is intended to assist authorized personnel '
        'in determining the general location or status of users during '
        'emergency situations.\n\n'
        'The application\u2019s location-related features may have '
        'limitations depending on device capability, GPS accuracy, '
        'internet connection, and environmental conditions.\n\n'
        'Users should not rely solely on the application\u2019s location '
        'information during an emergency. They must follow instructions '
        'from teachers, school administrators, emergency responders, and '
        'other authorized personnel.',
  ),
  TermsSection(
    number: '5',
    title: 'Emergency Notifications and SMS',
    body:
    'ASAN may provide emergency notifications and, where applicable, '
        'send SMS notifications to designated emergency contacts.\n\n'
        'The delivery of notifications or SMS messages may depend on '
        'factors outside the application\u2019s control, including:\n\n'
        '• Mobile network availability\n'
        '• Internet connectivity\n'
        '• Device settings\n'
        '• GPS availability\n'
        '• Mobile service interruptions\n'
        '• Other technical limitations',
  ),
  TermsSection(
    number: '6',
    title: 'Privacy and Protection of Information',
    body:
    'ASAN may collect information necessary for its emergency-'
        'monitoring functions, such as user identification, emergency '
        'status, and location-related information.\n\n'
        'Information collected through ASAN should only be accessed and '
        'used for legitimate school safety, emergency monitoring, '
        'research, or administrative purposes authorized by the school.\n\n'
        'Authorized personnel should only access information necessary '
        'for their assigned responsibilities.\n\n'
        'Users\u2019 information must not be unnecessarily shared, '
        'copied, published, or disclosed to unauthorized individuals.',
  ),
  TermsSection(
    number: '7',
    title: 'Account and Access Security',
    body:
    'Users are responsible for keeping their account credentials '
        'secure.\n\n'
        'ASAN recognizes and respects the privacy of its users and shall '
        'handle personal information in accordance with Republic Act No. '
        '10173, otherwise known as the Data Privacy Act of 2012, and its '
        'applicable Implementing Rules and Regulations. The Data Privacy '
        'Act protects individuals\u2019 fundamental right to privacy and '
        'regulates the collection and processing of personal '
        'information.\n\n'
        'The collection and processing of this information shall be '
        'limited to legitimate and specified purposes related to the '
        'ASAN research simulation, emergency drill monitoring, and '
        'evaluation of the application\u2019s functionality.',
  ),
  TermsSection(
    number: '8',
    title: 'Intellectual Property',
    body:
    'The ASAN Application, including its design, interface, system '
        'structure, logos, text, and other original materials developed '
        'for the project, belongs to the respective project developers '
        'or authorized institution, subject to applicable school and '
        'research policies.\n\n'
        'Users may not reproduce, modify, distribute, or commercially '
        'use protected ASAN materials without appropriate authorization.',
  ),
  TermsSection(
    number: '9',
    title: 'Limitation of Responsibility',
    body:
    'ASAN is an emergency-support tool and should not be considered '
        'a replacement for teachers, school administrators, security '
        'personnel, emergency responders, evacuation procedures, or '
        'other official safety measures.\n\n'
        'Users should always prioritize instructions from authorized '
        'school personnel and emergency responders.',
  ),
];