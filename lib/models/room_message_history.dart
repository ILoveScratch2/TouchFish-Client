import 'dart:collection';
import 'message_model.dart';

/// Fixed-length snapshot. The owner may append beyond its end; editing the
/// published prefix first detaches the backing list.
class RoomMessageSnapshot extends UnmodifiableListView<ChatMessage> {
  final List<ChatMessage> _source;
  final bool hasDuplicateMids;
  final int failedCount;
  final List<ChatMessage> mediaMessages;
  final Map<int, int> _firstIndexByMid;
  final List<int> _outgoingSequenced;
  final bool _sequencesSorted;

  RoomMessageSnapshot._(
    this._source,
    this.hasDuplicateMids,
    this.failedCount,
    this.mediaMessages,
    this._firstIndexByMid,
    this._outgoingSequenced,
    this._sequencesSorted,
  ) : super(_source.getRange(0, _source.length));

  bool extendsSnapshot(RoomMessageSnapshot previous) =>
      identical(_source, previous._source) && length >= previous.length;

  int peerReadMarker(int peerReadSeq) {
    if (!_sequencesSorted) {
      for (final index in _outgoingSequenced.reversed) {
        if (this[index].roomSeq! <= peerReadSeq) return index;
      }
      return -1;
    }
    var low = 0;
    var high = _outgoingSequenced.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (this[_outgoingSequenced[mid]].roomSeq! <= peerReadSeq) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low == 0 ? -1 : _outgoingSequenced[low - 1];
  }

  int groupReadMarker(Map<int, int> counts) {
    var latest = -1;
    for (final receipt in counts.entries) {
      final index = _firstIndexByMid[receipt.key];
      if (receipt.value <= 0 ||
          index == null ||
          index <= latest ||
          index >= length) {
        continue;
      }
      final m = this[index];
      if (m.isMe && !m.isDeleted) latest = index;
    }
    return latest;
  }
}

/// The live CDS list remains mutable for existing callers. Append-only writes
/// preserve every published prefix. A rare edit, prepend or trim starts a new
/// backing list and rebuilds its indexes on the next lookup or publication.
class RoomMessageHistory extends ListBase<ChatMessage> {
  List<ChatMessage> _items;
  RoomMessageSnapshot? _published;
  var _byMid = <int, int>{};
  List<int> _outgoingSequenced = [];
  var _sequencesSorted = true;
  final _byLocalKey = <String, int>{};
  List<ChatMessage> _media = [];
  List<ChatMessage>? _publishedMedia;
  int _indexed = 0;
  bool _duplicates = false;
  int _failed = 0;

  RoomMessageHistory([Iterable<ChatMessage> items = const []])
    : _items = List.of(items, growable: true);

  @override
  int get length => _items.length;

  @override
  set length(int value) {
    if (value == length) return;
    _beforeEdit();
    _items.length = value;
  }

  @override
  ChatMessage operator [](int index) => _items[index];

  @override
  void operator []=(int index, ChatMessage value) {
    if (identical(_items[index], value)) return;
    _beforeEdit();
    _items[index] = value;
  }

  @override
  void add(ChatMessage element) => _items.add(element);

  @override
  void addAll(Iterable<ChatMessage> iterable) =>
      _items.addAll(identical(iterable, this) ? _items : iterable);

  @override
  void insert(int index, ChatMessage element) {
    if (index != length) _beforeEdit();
    _items.insert(index, element);
  }

  @override
  void removeRange(int start, int end) {
    if (start != end) _beforeEdit();
    _items.removeRange(start, end);
  }

  void _beforeEdit() {
    if (_published == null && _indexed == 0) return;
    if (_published != null) _items = List.of(_items);
    _published = null;
    // Old snapshots still consult these append-only indexes.
    _byMid = {};
    _outgoingSequenced = [];
    _sequencesSorted = true;
    _byLocalKey.clear();
    _media = [];
    _publishedMedia = null;
    _indexed = 0;
    _duplicates = false;
    _failed = 0;
  }

  static String localKey(ChatMessage message) => message.localIdentityKey;

  void _indexNewItems() {
    for (; _indexed < length; _indexed++) {
      final message = _items[_indexed];
      final mid = message.mid;
      if (mid != null && _byMid.putIfAbsent(mid, () => _indexed) != _indexed) {
        _duplicates = true;
      }
      _byLocalKey.putIfAbsent(localKey(message), () => _indexed);
      final seq = message.roomSeq;
      if (mid != null && seq != null && message.isMe && !message.isDeleted) {
        if (_outgoingSequenced.isNotEmpty &&
            seq < _items[_outgoingSequenced.last].roomSeq!) {
          _sequencesSorted = false;
        }
        _outgoingSequenced.add(_indexed);
      }
      if (message.status == MessageStatus.failed && message.clientMid != null) {
        _failed++;
      }
      if (message.media != null) _media.add(message);
    }
  }

  int? indexOfMessage(ChatMessage message) {
    _indexNewItems();
    final mid = _byMid[message.mid];
    final local = _byLocalKey[localKey(message)];
    if (mid == null || (local != null && local < mid)) return local;
    return mid;
  }

  RoomMessageSnapshot get snapshot {
    final previous = _published;
    if (previous != null && previous.length == length) return previous;
    _indexNewItems();
    if (_publishedMedia?.length != _media.length) {
      _publishedMedia = UnmodifiableListView(_media.getRange(0, _media.length));
    }
    return _published = RoomMessageSnapshot._(
      _items,
      _duplicates,
      _failed,
      _publishedMedia!,
      _byMid,
      UnmodifiableListView(
        _outgoingSequenced.getRange(0, _outgoingSequenced.length),
      ),
      _sequencesSorted,
    );
  }
}
