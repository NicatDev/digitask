import 'package:intl/intl.dart';

/// Server vaxtı zona ilə gəlir (UTC "Z" və ya "+04:00"). `DateTime.parse` onu UTC kimi
/// saxlayır — göstərməzdən əvvəl mütləq telefonun yerli vaxtına çevrilməlidir.
DateTime parseServerTime(Object value) => DateTime.parse(value.toString()).toLocal();

DateTime? tryParseServerTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

final RegExp _isoWithZone =
    RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$');

/// Xam dəyər vaxt zonalı ISO mətnidirsə yerli vaxtla formatlanır, əks halda olduğu kimi qalır.
String displayServerValue(Object? value, {String pattern = 'dd.MM.yyyy HH:mm'}) {
  final text = value?.toString() ?? '';
  if (!_isoWithZone.hasMatch(text)) return text;
  final parsed = tryParseServerTime(text);
  return parsed == null ? text : DateFormat(pattern).format(parsed);
}
