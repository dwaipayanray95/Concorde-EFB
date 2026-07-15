class ChecklistItem {
  final String id;
  final String item;
  final String status;
  final String? note;

  const ChecklistItem({
    required this.id,
    required this.item,
    required this.status,
    this.note,
  });
}
