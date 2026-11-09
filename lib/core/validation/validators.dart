/// Pure validation helpers shared by services and forms.
///
/// Keeping these free of Firebase types makes them unit-testable.
class Validators {
  Validators._();

  static const int momentMaxLength = 500;
  static const int messageMaxLength = 1000;
  static const int captionMaxLength = 500;
  static const int moodNoteMaxLength = 300;

  static const List<String> allowedMoods = [
    'Happy',
    'Love',
    'Sad',
    'Tired',
    'Stressed',
    'Excited',
    'Missing You',
    'Calm',
    'Annoyed',
    'Need Attention',
  ];

  static final RegExp _emailPattern = RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$');
  static final RegExp _pairingCodePattern = RegExp(r'^[A-Z0-9]{6}$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Display name is required.';
    if (name.length < 2) return 'Must be at least 2 characters.';
    return null;
  }

  static String? username(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Username is required.';
    if (!_usernamePattern.hasMatch(username)) {
      return 'Use 3-20 letters, numbers, dots, or underscores.';
    }
    return null;
  }

  /// Normalises a pairing code and validates its shape.
  ///
  /// Returns `null` when the code is not valid.
  static String? normalizePairingCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    if (!_pairingCodePattern.hasMatch(code)) return null;
    return code;
  }

  static String? momentText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Moment cannot be empty.';
    if (text.length > momentMaxLength) {
      return 'Moment must be $momentMaxLength characters or less.';
    }
    return null;
  }

  static String? messageText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Message cannot be empty.';
    if (text.length > messageMaxLength) {
      return 'Message must be $messageMaxLength characters or less.';
    }
    return null;
  }

  static String? caption(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > captionMaxLength) {
      return 'Caption must be $captionMaxLength characters or less.';
    }
    return null;
  }

  static String? moodNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > moodNoteMaxLength) {
      return 'Mood note must be $moodNoteMaxLength characters or less.';
    }
    return null;
  }

  static String? mood(String? value) {
    if (value == null || !allowedMoods.contains(value)) {
      return 'Choose a valid mood.';
    }
    return null;
  }
}
