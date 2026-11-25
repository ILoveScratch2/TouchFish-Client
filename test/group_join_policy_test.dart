import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/group_join_policy.dart';


void main() {
  group('TfJoinPolicy.resolve', () {
    test('legal var pass by wxh', () {
      for (final policy in TfJoinPolicy.values) {
        expect(
          TfJoinPolicy.resolve(
            policy,
            allowDirectJoin: true,
            requireReview: true,
          ),
          policy,
        );
      }
    });

    test('reverse old server', () {
      expect(
        TfJoinPolicy.resolve(
          null,
          allowDirectJoin: true,
          requireReview: false,
        ),
        TfJoinPolicy.open,
      );
      expect(
        TfJoinPolicy.resolve(
          null,
          allowDirectJoin: true,
          requireReview: true,
        ),
        TfJoinPolicy.approval,
      );
      expect(
        TfJoinPolicy.resolve(
          null,
          allowDirectJoin: false,
          requireReview: false,
        ),
        TfJoinPolicy.invite,
      );
      // 旧默认值
      expect(
        TfJoinPolicy.resolve(
          null,
          allowDirectJoin: false,
          requireReview: true,
        ),
        TfJoinPolicy.adminInvite,
      );
    });

    test('illegal value falls back to old boolean logic', () {
      final resolved = TfJoinPolicy.resolve(
        'everyone',
        allowDirectJoin: true,
        requireReview: false,
      );
      expect(resolved, TfJoinPolicy.open);
      expect(TfJoinPolicy.values, contains(resolved));
    });
  });

  group('TfJoinPolicy semantic behavior', () {
    test('only open / approval allows self join', () {
      expect(TfJoinPolicy.allowsSelfJoin(TfJoinPolicy.open), isTrue);
      expect(TfJoinPolicy.allowsSelfJoin(TfJoinPolicy.approval), isTrue);
      expect(TfJoinPolicy.allowsSelfJoin(TfJoinPolicy.invite), isFalse);
      expect(TfJoinPolicy.allowsSelfJoin(TfJoinPolicy.adminInvite), isFalse);
    });

    test('only approval requires approval', () {
      expect(TfJoinPolicy.needsApproval(TfJoinPolicy.approval), isTrue);
      for (final policy in [
        TfJoinPolicy.open,
        TfJoinPolicy.invite,
        TfJoinPolicy.adminInvite,
      ]) {
        expect(TfJoinPolicy.needsApproval(policy), isFalse);
      }
    });

    test('only admin invite disallows member invite', () {
      expect(TfJoinPolicy.allowsMemberInvite(TfJoinPolicy.adminInvite), isFalse);
      for (final policy in [
        TfJoinPolicy.open,
        TfJoinPolicy.approval,
        TfJoinPolicy.invite,
      ]) {
        expect(TfJoinPolicy.allowsMemberInvite(policy), isTrue);
      }
    });
  });
}
