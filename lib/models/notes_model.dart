class Note {
  final String id;
  final String title;
  final String time;
  final List<String> items;

  Note(
      {
        required this.id, required this.title,
        required this.time, required this.items,
      });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'items': items,
    };
  }

  factory Note.fromFirestore(Map<String, dynamic> firestoreDoc) {
    return Note(
      id: firestoreDoc['id'],
      title: firestoreDoc['title'],
      time: firestoreDoc['time'],
      items: firestoreDoc['items'] != null ? List<String>
          .from(firestoreDoc['items']) : [],
    );
  }

}
