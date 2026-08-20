import 'package:equatable/equatable.dart';

/// Authenticated user as exposed by the auth domain.
///
/// Wraps just the fields the UI cares about so providers do not leak
/// the Supabase SDK type across feature boundaries.
class AuthUser extends Equatable {
  final String id;
  final String? email;
  final String? displayName;

  /// Whether this is a Supabase anonymous user that has not yet linked a
  /// real identity. Anonymous users get the free tier on a single device,
  /// and purchasing requires a permanent (non-anonymous) account.
  ///
  /// 雲端同步**不**在此限：journey 與 trip 對匿名帳號一樣會同步（見
  /// syncSessionProvider）。差別在匿名 id 綁在裝置的 session 上，重裝就換一
  /// 個 id、舊資料拿不回來；升級成正式帳號（linkIdentity 會保留同一個 id）
  /// 才真的能跨裝置。
  final bool isAnonymous;

  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  @override
  List<Object?> get props => [id, email, displayName, isAnonymous];
}
