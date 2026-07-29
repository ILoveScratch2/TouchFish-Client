class StickerItem {
  final String id;
  final String packId;
  final String slug;
  final String? name;
  final String fileHash;
  final String fileType;
  final int order;
  final int size;
  final int mode;

  const StickerItem({
    required this.id,
    required this.packId,
    required this.slug,
    required this.fileHash,
    required this.fileType,
    this.name,
    this.order = 0,
    this.size = 0,
    this.mode = 0,
  });

  factory StickerItem.fromMap(Map<String, dynamic> json) => StickerItem(
    id: json['id'].toString(),
    packId: (json['pack_id'] ?? '').toString(),
    slug: (json['slug'] ?? '').toString(),
    name: json['name']?.toString(),
    fileHash: (json['file_hash'] ?? '').toString(),
    fileType: (json['file_type'] ?? 'unknown').toString(),
    order: (json['order'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 0,
    mode: (json['mode'] as num?)?.toInt() ?? 0,
  );
}

class StickerPack {
  final String id;
  final int creatorUid;
  final String name;
  final String description;
  final String prefix;
  final String? iconHash;
  final int usageCount;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.id,
    required this.creatorUid,
    required this.name,
    required this.description,
    required this.prefix,
    this.iconHash,
    this.usageCount = 0,
    this.stickers = const [],
  });

  factory StickerPack.fromMap(Map<String, dynamic> json) => StickerPack(
    id: json['id'].toString(),
    creatorUid: (json['creator_uid'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    prefix: (json['prefix'] ?? '').toString(),
    iconHash: json['icon_hash']?.toString(),
    usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
    stickers: (json['stickers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => StickerItem.fromMap(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

class OwnedStickerPack {
  final String packId;
  final int order;
  final StickerPack pack;
  const OwnedStickerPack({required this.packId, required this.order, required this.pack});
  factory OwnedStickerPack.fromMap(Map<String, dynamic> json) => OwnedStickerPack(
    packId: json['pack_id'].toString(),
    order: (json['order'] as num?)?.toInt() ?? 0,
    pack: StickerPack.fromMap(Map<String, dynamic>.from(json['pack'] as Map)),
  );
}
