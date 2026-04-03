import 'dart:math';

class UsernameGenerator {
  static const List<String> _adjectives = [
    'ninja',
    'silent',
    'cosmic',
    'swift',
    'wild',
    'bright',
    'shadow',
    'iron',
    'neon',
    'lucky',
    'clever',
    'brave',
    'frost',
    'ember',
    'storm',
    'solar',
    'moon',
    'pixel',
    'mystic',
    'rapid',
  ];

  static const List<String> _nouns = [
    'sparks',
    'tiger',
    'falcon',
    'wolf',
    'panda',
    'otter',
    'rocket',
    'comet',
    'dragon',
    'phoenix',
    'cipher',
    'ranger',
    'samurai',
    'knight',
    'atlas',
    'nova',
    'quest',
    'echo',
    'zen',
    'vortex',
  ];

  final Random _rng = Random.secure();

  String generate() {
    final adj = _adjectives[_rng.nextInt(_adjectives.length)];
    final noun = _nouns[_rng.nextInt(_nouns.length)];
    return '$adj$noun';
  }
}

